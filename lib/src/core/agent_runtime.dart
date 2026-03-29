import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'types.dart';
import 'action_registry.dart';
import 'element_tree_walker.dart';
import 'screen_dehydrator.dart';
import 'system_prompt.dart';
import '../tools/types.dart';
import '../tools/tap_tool.dart';
import '../tools/type_tool.dart';
import '../tools/scroll_tool.dart';
import '../tools/keyboard_tool.dart';
import '../utils/logger.dart';

class AgentRuntime {
  final AiProvider provider;
  final AgentConfig config;
  final GlobalKey rootKey;
  final GlobalKey<NavigatorState>? navKey;
  
  final Map<String, AgentTool> _tools = {};
  final List<AgentStep> _history = [];
  bool _isRunning = false;
  bool _isCancelRequested = false;
  
  List<InteractiveElement> _lastElements = [];

  /// Must hold the SemanticsHandle so the semantics tree stays enabled.
  /// Without this, RendererBinding.pipelineOwner.semanticsOwner is null.
  SemanticsHandle? _semanticsHandle;

  AgentRuntime({
    required this.provider,
    required this.config,
    required this.rootKey,
    this.navKey,
  }) {
    _registerBuiltInTools();
    // Enable Flutter's semantics tree — required for ElementTreeWalker.
    // Works transparently in production apps with zero developer setup.
    // The handle is released in dispose() to avoid unnecessary overhead
    // when the agent is not active.
    _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
  }

  /// Release the semantics handle. Call when the runtime is no longer needed.
  void dispose() {
    _semanticsHandle?.dispose();
    _semanticsHandle = null;
  }

  /// Request cancellation of the current task.
  /// The execution loop will exit cleanly at the next step boundary.
  void cancel() {
    _isCancelRequested = true;
  }

  AgentConfig getConfig() => config;
  bool getIsRunning() => _isRunning;

  List<ToolDefinition> getTools() {
    final allTools = _tools.values.map((t) => t.definition).toList();
    
    // Add dynamically registered actions
    // Add dynamically registered actions
    for (final action in actionRegistry.getAll()) {
      final toolParams = <String, ToolParam>{};
      for (final entry in action.parameters.entries) {
        final key = entry.key;
        final val = entry.value;
        if (val is String) {
          toolParams[key] = ToolParam(type: 'string', description: val, required: true);
        } else if (val is ActionParameterDef) {
          toolParams[key] = ToolParam(type: val.type, description: val.description, enumValues: val.enumValues, required: val.required);
        }
      }
      allTools.add(ToolDefinition(
        name: action.name,
        description: action.description,
        parameters: toolParams,
        handler: (args) async {
          final res = await action.handler(args);
          return res.toString();
        },
      ));
    }
    
    allTools.add(ToolDefinition(
      name: 'done',
      description: 'Call this when you have achieved the goal or there is nothing more to do.',
      parameters: {
        'success': ToolParam(type: 'boolean', description: 'True if the goal was successfully completed, false otherwise', required: true),
        'text': ToolParam(type: 'string', description: 'A final message or summary to display to the user', required: true),
      },
      handler: (args) async => 'done',
    ));

    return allTools;
  }

  void _registerBuiltInTools() {
    _tools['tap'] = TapTool();
    _tools['type'] = TypeTool();
    _tools['scroll'] = ScrollTool();
    _tools['keyboard'] = KeyboardTool();
  }

  /// Returns the effective tool list for the current execution context.
  /// When enableUiControl=false, strips all UI-interaction tools so the
  /// LLM acts as a knowledge-only assistant — mirrors RN's enableUIControl=false.
  static const _uiControlTools = {'tap', 'type', 'scroll', 'keyboard', 'navigate'};
  List<ToolDefinition> _getEffectiveTools() {
    final all = getTools();
    if (config.enableUiControl) return all;
    return all.where((t) => !_uiControlTools.contains(t.name)).toList();
  }

  ToolContext _buildToolContext() {
    return ToolContext(
      rootContext: rootKey.currentContext!,
      config: config,
      lastElements: _lastElements,
      getCurrentScreenName: _getCurrentScreenName,
      getRouteNames: _getRouteNames,
    );
  }

  Future<ExecutionResult> execute(String instruction, {List<Map<String, String>>? chatHistory}) async {
    if (_isRunning) {
      return ExecutionResult(success: false, message: 'Agent is already running.', steps: const []);
    }

    _isRunning = true;
    _isCancelRequested = false;
    _history.clear();
    
    Logger.info('Starting agent execution: "$instruction"');

    try {
      final systemPrompt = buildSystemPrompt(
        config.language ?? 'en',
        hasKnowledge: false, 
        userInstructions: config.instructions,
      );

      for (int step = 1; step <= config.maxSteps; step++) {
        if (_isCancelRequested) {
          return ExecutionResult(success: false, message: 'Cancelled by user.', steps: _history);
        }

        config.onStatusUpdate?.call('Thinking (Step $step)...');
        Logger.info('===== Step $step/${config.maxSteps} =====');

        // 1. Walk UI Tree
        final walker = ElementTreeWalker(config);
        var interactives = walker.walk(rootKey.currentContext!);

        // ── Security: Blacklist / Whitelist filtering ──────────────
        final blacklist = config.interactiveBlacklist;
        final whitelist = config.interactiveWhitelist;
        if (blacklist != null && blacklist.isNotEmpty) {
          final blackIds = blacklist
              .map((k) => k.currentContext?.findRenderObject()?.debugSemantics?.id)
              .whereType<int>()
              .toSet();
          interactives = interactives.where((e) {
            return e.semanticsNodeId == null || !blackIds.contains(e.semanticsNodeId);
          }).toList();
        }
        if (whitelist != null && whitelist.isNotEmpty) {
          final whiteIds = whitelist
              .map((k) => k.currentContext?.findRenderObject()?.debugSemantics?.id)
              .whereType<int>()
              .toSet();
          interactives = interactives.where((e) {
            return e.semanticsNodeId != null && whiteIds.contains(e.semanticsNodeId);
          }).toList();
        }
        _lastElements = interactives;

        // 2. Dehydrate Screen
        var elementsText = ScreenDehydrator.dehydrate(_lastElements);

        // ── Security: transformScreenContent (data masking) ────────
        if (config.transformScreenContent != null) {
          elementsText = await config.transformScreenContent!(elementsText);
        }

        final screenName = _getCurrentScreenName();
        final routeNames = _getRouteNames();

        Logger.info('Screen: $screenName');
        Logger.debug('Dehydrated:\n$elementsText');

        // ── Security: enableUiControl=false → knowledge-only mode ──
        // Get tools, filtering UI tools when control is disabled
        final tools = _getEffectiveTools();

        final maxStepsNum = config.maxSteps;
        final stepInfoBlock = '<agent_state>\n<step_info>\nStep $step of $maxStepsNum max possible steps\n</step_info>\n</agent_state>';
        final screenStateBlock = '<screen_state>\nCurrent Screen: $screenName\nAvailable Screens: ${routeNames.join(', ')}\n\n$elementsText\n</screen_state>';
        // Chat history block (for follow-up requests like "try again")
        String chatBlock = '';
        if (chatHistory != null && chatHistory.isNotEmpty) {
          final buf = StringBuffer('<chat_history>\n');
          for (final msg in chatHistory) {
            buf.writeln('[${msg['role']}]: ${msg['content']}');
          }
          buf.write('</chat_history>');
          chatBlock = '\n\n${buf.toString()}';
        }
        final fullUserMessage = '$instruction$chatBlock\n\n$stepInfoBlock\n\n$screenStateBlock';
        Logger.info('Sending to AI with ${tools.length} tools...');
        final result = await provider.generateContent(
          systemPrompt: systemPrompt,
          userMessage: fullUserMessage,
          tools: tools,
          history: _buildSummarizedHistory(),
        );

        // 4. Record Step History
        final actionNameSafe = result.actionName ?? 'unknown';
        final actionParamsSafe = result.actionParams ?? {};
        
        Logger.info('🧠 Plan: ${result.reasoning?.plan ?? "N/A"}');
        Logger.debug('💾 Memory: ${result.reasoning?.memory ?? "N/A"}');
        Logger.info('Tool: $actionNameSafe($actionParamsSafe)');
        
        _history.add(AgentStep(
          actionName: actionNameSafe,
          actionParams: actionParamsSafe,
          reasoning: result.reasoning,
        ));

        // 5. Execute Action
        if (actionNameSafe == 'done') {
          final success = actionParamsSafe['success'] == true;
          final text = actionParamsSafe['text'] as String? ?? 'Done';
          Logger.info('Task completed: $text');
          _history.last.result = text;
          return ExecutionResult(success: success, message: text, steps: _history);
        }

        config.onStatusUpdate?.call(result.reasoning?.plan ?? 'Executing $actionNameSafe...');
        final executionMessage = await executeTool(actionNameSafe, actionParamsSafe);
        Logger.info('Result: $executionMessage');
        _history.last.result = executionMessage;
        
        // Let UI settle after action (300ms matches RN default)
        await Future.delayed(const Duration(milliseconds: 300));
      }

      return ExecutionResult(success: false, message: 'Reached maximum steps limit.', steps: _history);
    } catch (e) {
      Logger.error('Runtime error: $e');
      return ExecutionResult(success: false, message: 'Error: ${e.toString()}', steps: _history);
    } finally {
      _isRunning = false;
    }
  }

  Future<String> executeTool(String name, Map<String, dynamic> args) async {
    // 1. Check dynamic actions first
    final customAction = actionRegistry.getAction(name);
    if (customAction != null) {
      try {
        final result = await customAction.handler(args);
        return result.toString();
      } catch (e) {
        return 'Action "$name" failed: $e';
      }
    }
    
    // 2. Check built-in tool mapped instances
    final toolInstance = _getBuiltInToolInstance(name);
    if (toolInstance != null) {
      try {
        return await toolInstance.execute(args, _buildToolContext());
      } catch (e) {
        return 'Tool "$name" failed: $e';
      }
    }

    // 3. Special case simple inline tools
    if (name == 'wait') {
      final seconds = (args['seconds'] as num?)?.toInt() ?? 2;
      await Future.delayed(Duration(seconds: seconds));
      return 'Waited $seconds seconds.';
    }

    if (name == 'navigate') {
      final screen = args['screen'] as String?;
      if (screen == null) return 'Missing screen name';
      try {
        if (config.router != null) {
          config.router!.go('/$screen');
        } else if (navKey?.currentState != null) {
          navKey!.currentState!.pushNamed(screen);
        } else {
          return 'No router or navigator available.';
        }
        return 'Navigated to $screen.';
      } catch (e) {
        return 'Failed to navigate: $e';
      }
    }

    return 'Unknown tool: $name';
  }

  AgentTool? _getBuiltInToolInstance(String name) {
    switch (name) {
      case 'tap': return TapTool();
      case 'type': return TypeTool();
      case 'scroll': return ScrollTool();
      case 'keyboard': return KeyboardTool();
      default: return null;
    }
  }

  /// Mirrors RN's history summarization:
  /// When history > 8 steps, compress middle steps into a <steps_summary>
  /// to prevent context overflow. Keeps first 2 + last 4 in full detail.
  List<AgentStep> _buildSummarizedHistory() {
    const summarizeThreshold = 8;
    const keepHead = 2;
    const keepTail = 4;

    if (_history.length <= summarizeThreshold) {
      return List.unmodifiable(_history);
    }

    // Build a virtual step that represents the summary of middle steps
    final middleSteps = _history.sublist(keepHead, _history.length - keepTail);
    final summaryLines = middleSteps.asMap().entries.map((e) {
      final i = keepHead + e.key;
      final step = e.value;
      final resultPreview = step.result ?? step.error ?? 'unknown';
      final succeeded = resultPreview.contains('Error') || resultPreview.contains('fail') ? 'fail' : 'success';
      return 'Step ${i + 1}: ${step.actionName} → $succeeded';
    }).join('\n');

    final summaryStep = AgentStep(
      actionName: '__summary__',
      actionParams: {},
      result: '<steps_summary>\n$summaryLines\n</steps_summary>',
    );

    return [
      ..._history.take(keepHead),
      summaryStep,
      ..._history.skip(_history.length - keepTail),
    ];
  }

  String _getCurrentScreenName() {
    // Try GoRouter first
    if (config.router != null) {
      try {
        final uri = config.router!.routeInformationProvider.value.uri;
        final segments = uri.pathSegments;
        final name = segments.isNotEmpty ? segments.last : uri.path;
        return name.isNotEmpty ? name : 'Home';
      } catch (_) {}
    }
    // Fall back to Navigator
    if (navKey?.currentState != null) {
      try {
        final route = navKey!.currentState!.widget.pages.lastOrNull;
        return route?.name ?? 'Unknown';
      } catch (_) {}
    }
    return 'Unknown';
  }

  List<String> _getRouteNames() {
    // Try GoRouter routes
    if (config.router != null) {
      try {
        final List<String> names = [];
        for (final route in config.router!.configuration.routes) {
          _collectRouteNames(route, names);
        }
        return names;
      } catch (_) {}
    }
    return [];
  }

  void _collectRouteNames(dynamic route, List<String> names) {
    try {
      final path = route.path as String?;
      if (path != null && path.isNotEmpty && path != '/') {
        final segment = path.split('/').where((s) => s.isNotEmpty && !s.startsWith(':')).lastOrNull;
        if (segment != null) names.add(segment);
      }
      final sub = route.routes as List?;
      if (sub != null) {
        for (final r in sub) {
          _collectRouteNames(r, names);
        }
      }
    } catch (_) {}
  }

  ScreenContext getScreenContext() {
    final walker = ElementTreeWalker(config);
    final interactives = walker.walk(rootKey.currentContext!);
    return ScreenContext(
      screenName: _getCurrentScreenName(),
      availableScreens: _getRouteNames(),
      elementsText: ScreenDehydrator.dehydrate(interactives),
    );
  }
}

class ScreenContext {
  final String screenName;
  final List<String> availableScreens;
  final String elementsText;

  ScreenContext({
    required this.screenName,
    required this.availableScreens,
    required this.elementsText,
  });
}
