import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/types.dart';
import '../utils/logger.dart';

const _agentStepFn = 'agent_step';

class GeminiProvider implements AiProvider {
  final String _apiKey;
  final String modelName;

  GeminiProvider({
    String? apiKey,
    this.modelName = 'gemini-2.5-flash',
  }) : _apiKey = apiKey ?? '' {
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('[flutter_agentic_ai] You must provide an "apiKey" to AiAgent.');
    }
  }

  @override
  Future<ProviderResult> generateContent({
    required String systemPrompt,
    required String userMessage,
    required List<ToolDefinition> tools,
    required List<AgentStep> history,
    String? screenshotBase64,
  }) async {
    Logger.info('Sending request to Gemini. Model: $modelName, Tools: ${tools.length}${screenshotBase64 != null ? " with screenshot" : ""}');

    final contentParts = <Part>[];
    
    // 1. Build chat history — mirrors RN format:
    // <agent_history>
    // <step_N>
    // Previous Goal Eval: ...
    // Memory: ...
    // Plan: ...
    // Action: tool_name
    // Action Result: tool output
    // </step_N>
    // </agent_history>
    if (history.isNotEmpty) {
      final historyBuffer = StringBuffer();
      historyBuffer.writeln('<agent_history>');
      for (var i = 0; i < history.length; i++) {
        final step = history[i];
        // Virtual summary step — emit its content directly
        if (step.actionName == '__summary__' && step.result != null) {
          historyBuffer.writeln(step.result);
          continue;
        }
        historyBuffer.writeln('<step_$i>');
        if (step.reasoning != null) {
          historyBuffer.writeln('Previous Goal Eval: ${step.reasoning!.previousGoalEval}');
          historyBuffer.writeln('Memory: ${step.reasoning!.memory}');
          historyBuffer.writeln('Plan: ${step.reasoning!.plan}');
        }
        historyBuffer.writeln('Action: ${step.actionName}');
        if (step.error != null) {
          historyBuffer.writeln('Action Result: Error — ${step.error}');
        } else if (step.result != null && step.result!.isNotEmpty) {
          historyBuffer.writeln('Action Result: ${step.result}');
        }
        historyBuffer.writeln('</step_$i>');
      }
      historyBuffer.writeln('</agent_history>');
      contentParts.add(TextPart(historyBuffer.toString()));
    }

    // 2. System prompt + user request (clean, no noisy toolDescriptions in userMessage)
    // The system prompt is injected via GenerativeModel's systemInstruction per-call below.
    contentParts.add(TextPart(userMessage));

    // 3. Add Optional Screenshot
    if (screenshotBase64 != null) {
      try {
        final uriData = UriData.parse(screenshotBase64);
        contentParts.add(DataPart(
          uriData.mimeType,
          uriData.contentAsBytes(),
        ));
      } catch (e) {
        // Fallback if it's just raw base64 without prefix
        contentParts.add(DataPart('image/jpeg', base64Decode(screenshotBase64)));
      }
    }

    final agentStepDeclaration = _buildAgentStepDeclaration(tools);
    final startTime = DateTime.now();

    // Build a per-request model with system prompt injected
    final requestModel = GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final response = await requestModel.generateContent(
        [Content('user', contentParts)],
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 2048,
        ),
        tools: [
          Tool(functionDeclarations: [agentStepDeclaration])
        ],
        toolConfig: ToolConfig(
          functionCallingConfig: FunctionCallingConfig(
            mode: FunctionCallingMode.any,
            allowedFunctionNames: {_agentStepFn},
          ),
        ),
      );

      final elapsed = DateTime.now().difference(startTime);
      Logger.info('Response received in ${elapsed.inMilliseconds}ms');

      return _parseAgentStepResponse(response, tools);
    } catch (e) {
      Logger.error('Gemini Request failed: $e');
      rethrow;
    }
  }

  FunctionDeclaration _buildAgentStepDeclaration(List<ToolDefinition> tools) {
    final properties = <String, Schema>{};
    final requiredProps = <String>[
      'plan',
      'action_name'
    ];

    // Reasoning fields
    properties['previous_goal_eval'] = Schema.string(
      description: 'One-sentence assessment of your last action. State success, failure, or uncertain. Skip on first step.',
      nullable: true,
    );
    properties['memory'] = Schema.string(
      description: 'Key facts to remember for future steps: progress made, items found, counters, field values already collected.',
      nullable: true,
    );
    properties['plan'] = Schema.string(
      description: 'Your immediate next goal — what action you will take and why.',
    );

    // Action Name Enum
    final toolNames = tools.map((t) => t.name).toList();
    properties['action_name'] = Schema.enumString(
      enumValues: toolNames,
      description: "Choose one action to execute based on available tools. Options: ${toolNames.join(', ')}, done",
    );

    // Flat properties from all tools
    for (final tool in tools) {
      for (final entry in tool.parameters.entries) {
        final pName = entry.key;
        final pDef = entry.value;
        if (properties.containsKey(pName)) continue;

        Schema typeSchema;
        switch (pDef.type) {
          case 'number':
          case 'integer':
            typeSchema = Schema.integer(description: pDef.description);
            break;
          case 'boolean':
            typeSchema = Schema.boolean(description: pDef.description);
            break;
          default:
            if (pDef.enumValues != null && pDef.enumValues!.isNotEmpty) {
              typeSchema = Schema.enumString(enumValues: pDef.enumValues!, description: pDef.description);
            } else {
              typeSchema = Schema.string(description: pDef.description);
            }
        }
        properties[pName] = typeSchema;
      }
    }

    return FunctionDeclaration(
      _agentStepFn,
      'Execute one agent step. Choose an action and provide reasoning.',
      Schema.object(properties: properties, requiredProperties: requiredProps),
    );
  }

  ProviderResult _parseAgentStepResponse(GenerateContentResponse response, List<ToolDefinition> tools) {
    final functionCalls = response.functionCalls;
    if (functionCalls.isEmpty) {
      throw Exception('Model did not return a function call. Text: ${response.text}');
    }

    final call = functionCalls.first;
    if (call.name != _agentStepFn) {
      throw Exception('Model called unexpected function: ${call.name}');
    }

    final args = call.args;
    final actionName = args['action_name'] as String?;

    if (actionName == null) {
      throw Exception('Model omitted action_name in agent_step call.');
    }

    final reasoning = AgentReasoning(
      previousGoalEval: args['previous_goal_eval'] as String? ?? '',
      memory: args['memory'] as String? ?? '',
      plan: args['plan'] as String? ?? '',
    );

    final toolParams = <String, dynamic>{};
    final targetTool = tools.where((t) => t.name == actionName).firstOrNull;
    
    if (targetTool != null) {
      for (final key in targetTool.parameters.keys) {
        if (args.containsKey(key)) {
          toolParams[key] = args[key];
        }
      }
    }

    return ProviderResult(
      actionName: actionName,
      actionParams: toolParams,
      reasoning: reasoning,
      // Dart SDK doesn't natively expose token usage yet in the same way, stubbing it for now
      tokenUsage: TokenUsage(promptTokens: 0, completionTokens: 0, estimatedCostUSD: 0),
    );
  }
}
