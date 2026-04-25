import 'dart:async';
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'types.dart';
import 'action_registry.dart';
import 'block_registry.dart';
import 'data_registry.dart';
import 'element_tree_walker.dart';
import 'flutter_platform_adapter.dart';
import 'screen_dehydrator.dart';
import 'system_prompt.dart';
import 'zone_registry.dart';
import 'verifier.dart';
import '../tools/types.dart';
import '../tools/tap_tool.dart';
import '../tools/type_tool.dart';
import '../tools/scroll_tool.dart';
import '../tools/keyboard_tool.dart';
import '../tools/long_press_tool.dart';
import '../tools/slider_tool.dart';
import '../tools/picker_tool.dart';
import '../tools/guide_tool.dart';
import '../tools/date_picker_tool.dart';
import '../tools/knowledge_tool.dart';
import '../services/knowledge_base_service.dart';
import '../utils/logger.dart';

class AgentRuntime {
  final AiProvider provider;
  final AgentConfig config;
  final GlobalKey rootKey;
  final GlobalKey<NavigatorState>? navKey;
  late final PlatformAdapter _platformAdapter;

  final Map<String, AgentTool> _tools = {};
  final List<AgentStep> _history = [];
  bool _isRunning = false;
  bool _isCancelRequested = false;

  List<InteractiveElement> _lastElements = [];

  /// Knowledge base service for RAG capabilities.
  KnowledgeBaseService? _knowledgeService;

  /// Approval workflow state for copilot mode.
  AppActionApprovalScope _approvalScope = AppActionApprovalScope.none;
  AppActionApprovalSource _approvalSource = AppActionApprovalSource.none;

  /// Outcome verifier for critical action verification.
  OutcomeVerifier? _verifier;
  PendingVerification? _pendingCriticalVerification;
  String? _verificationObservation;
  _VerifiedCriticalAction? _lastVerifiedCriticalAction;

  /// Current goal for verification context.
  String? _lastGoal;

  /// Error handling state for graceful error suppression.
  void Function(FlutterErrorDetails)? _originalErrorHandler;
  Timer? _errorGraceTimer;

  /// Tools that physically alter the app — must be gated by workflow approval.
  static const Set<String> _appActionTools = {
    'tap',
    'type',
    'scroll',
    'navigate',
    'keyboard',
    'long_press',
    'adjust_slider',
    'select_picker',
    'set_date',
  };

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
    _platformAdapter =
        config.platformAdapter ??
        FlutterPlatformAdapter(
          config: config,
          rootKey: rootKey,
          navigatorKey: navKey,
          getCurrentScreenName: _getCurrentScreenName,
          getRouteNames: _getRouteNames,
        );
    // Initialize knowledge base service if configured
    if (config.knowledgeBase != null) {
      _knowledgeService = KnowledgeBaseService(
        config.knowledgeBase,
        config.knowledgeMaxTokens,
      );
      Logger.info('Knowledge base service initialized');
    }

    // Initialize approval scope if configured
    if (config.initialApprovalScope != null) {
      _approvalScope = config.initialApprovalScope!;
      Logger.info('Initial approval scope: $_approvalScope');
    }

    // Initialize verifier if enabled
    if (config.verifier?.enabled ?? true) {
      _verifier = OutcomeVerifier(provider: provider, config: config);
      Logger.info('Outcome verifier initialized');
    }

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
    _stopErrorSuppression();
  }

  /// Start error suppression mode during critical operations.
  void _startErrorSuppression() {
    if (!config.reportErrorsAsExceptions) return;

    _originalErrorHandler = FlutterError.onError;

    FlutterError.onError = (details) {
      // Log the error but don't crash
      Logger.warn('Suppressed Flutter error: ${details.exception}');
      Logger.debug('Stack trace: ${details.stack}');

      // Also notify via onError callback if configured
      config.onError?.call(
        details.exception,
        ExecutionResult(
          success: false,
          message: 'Error suppressed: ${details.exception}',
          steps: List.from(_history),
        ),
      );
    };
  }

  /// Stop error suppression with a grace period.
  void _stopErrorSuppression({Duration? gracePeriod}) {
    gracePeriod ??= config.gracePeriod;

    // Cancel any existing grace timer
    _errorGraceTimer?.cancel();

    // Set up grace period before restoring original error handler
    _errorGraceTimer = Timer(gracePeriod, () {
      if (_originalErrorHandler != null) {
        FlutterError.onError = _originalErrorHandler;
        _originalErrorHandler = null;
        Logger.info('Original error handler restored after grace period');
      }
      _errorGraceTimer = null;
    });
  }

  /// Request cancellation of the current task.
  /// The execution loop will exit cleanly at the next step boundary.
  void cancel() {
    _isCancelRequested = true;
  }

  AgentConfig getConfig() => config;
  bool getIsRunning() => _isRunning;

  // ─── Approval Workflow Methods ─────────────────────────────────

  /// Check if a tool needs approval based on current scope.
  bool _needsApproval(String toolName) {
    if (config.interactionMode == AppInteractionMode.autopilot) {
      return false;
    }

    // Only UI-altering tools need approval
    if (!_appActionTools.contains(toolName)) {
      return false;
    }

    // Check current approval scope
    return _approvalScope == AppActionApprovalScope.none;
  }

  /// Check if workflow approval is currently granted.
  bool _hasWorkflowApproval() {
    return _approvalScope == AppActionApprovalScope.workflow;
  }

  /// Grant workflow approval for the current task.
  void _grantWorkflowApproval(AppActionApprovalSource source) {
    _approvalScope = AppActionApprovalScope.workflow;
    _approvalSource = source;
    Logger.info('Workflow approval granted (source: $source)');
  }

  /// Get current approval scope (for testing/debugging).
  AppActionApprovalScope getApprovalScope() => _approvalScope;

  /// Get current approval source (for testing/debugging).
  AppActionApprovalSource getApprovalSource() => _approvalSource;

  /// Clear workflow approval when a new user task starts.
  void resetAppActionApproval([String reason = 'reset']) {
    _approvalScope = AppActionApprovalScope.none;
    _approvalSource = AppActionApprovalSource.none;
    Logger.info('Workflow approval cleared ($reason)');
  }

  List<ToolDefinition> getTools() {
    final allTools = _tools.values.map((t) => t.definition).toList();

    // Add dynamically registered actions
    for (final action in actionRegistry.getAll()) {
      final toolParams = <String, ToolParam>{};
      for (final entry in action.parameters.entries) {
        final key = entry.key;
        final val = entry.value;
        if (val is String) {
          toolParams[key] = ToolParam(
            type: 'string',
            description: val,
            required: true,
          );
        } else if (val is ActionParameterDef) {
          toolParams[key] = ToolParam(
            type: val.type,
            description: val.description,
            enumValues: val.enumValues,
            required: val.required,
          );
        }
      }
      allTools.add(
        ToolDefinition(
          name: action.name,
          description: action.description,
          parameters: toolParams,
          handler: (args) async {
            final res = await action.handler(args);
            return res.toString();
          },
        ),
      );
    }

    // Add knowledge base tool if configured
    if (_knowledgeService != null) {
      final knowledgeTool = KnowledgeTool(
        knowledgeService: _knowledgeService!,
        getCurrentScreenName: _getCurrentScreenName,
      );
      allTools.add(knowledgeTool.definition);
      Logger.info('Knowledge base tool registered');
    }

    if (dataRegistry.getAll().isNotEmpty) {
      allTools.add(
        ToolDefinition(
          name: 'query_data',
          description:
              'Query an app-registered data source for structured async data such as products, recommendations, inventory, pricing, or order status. Use when the app exposes a named data source and it is more reliable than inferring from the current screen.',
          parameters: {
            'source': ToolParam(
              type: 'string',
              description: 'The registered data source name to query',
              required: true,
            ),
            'query': ToolParam(
              type: 'string',
              description: 'What data you need from that source',
              required: true,
            ),
          },
          handler: (args) async => 'query_data',
        ),
      );
    }

    allTools.add(
      ToolDefinition(
        name: 'navigate',
        description:
            'Navigate to a safe top-level screen. Do not use for screens that require an item ID or prior selection.',
        parameters: {
          'screen': ToolParam(
            type: 'string',
            description: 'The target top-level screen name',
            required: true,
          ),
        },
        handler: (args) async => 'navigate',
      ),
    );

    allTools.add(
      ToolDefinition(
        name: 'wait',
        description:
            'Wait briefly for loading states or transitions to finish.',
        parameters: {
          'seconds': ToolParam(
            type: 'integer',
            description: 'How many seconds to wait',
            required: false,
          ),
        },
        handler: (args) async => 'wait',
      ),
    );

    allTools.add(
      ToolDefinition(
        name: 'simplify_zone',
        description: 'Simplify a registered AI zone to reduce visual clutter.',
        parameters: {
          'zoneId': ToolParam(
            type: 'string',
            description: 'The zone id to simplify',
            required: true,
          ),
        },
        handler: (args) async => 'simplify_zone',
      ),
    );

    allTools.add(
      ToolDefinition(
        name: 'restore_zone',
        description: 'Restore a previously simplified or injected AI zone.',
        parameters: {
          'zoneId': ToolParam(
            type: 'string',
            description: 'The zone id to restore',
            required: true,
          ),
        },
        handler: (args) async => 'restore_zone',
      ),
    );

    allTools.add(
      ToolDefinition(
        name: 'render_block',
        description:
            'Render a registered block into an AI zone as a local intervention.',
        parameters: {
          'zoneId': ToolParam(
            type: 'string',
            description: 'The target zone id',
            required: true,
          ),
          'blockType': ToolParam(
            type: 'string',
            description: 'The registered block type to render',
            required: true,
          ),
          'props': ToolParam(
            type: 'string',
            description: 'Optional JSON object props',
            required: false,
          ),
        },
        handler: (args) async => 'render_block',
      ),
    );

    allTools.add(
      ToolDefinition(
        name: 'inject_card',
        description: 'Deprecated compatibility alias for render_block.',
        parameters: {
          'zoneId': ToolParam(
            type: 'string',
            description: 'The target zone id',
            required: true,
          ),
          'templateName': ToolParam(
            type: 'string',
            description: 'The legacy card/template name',
            required: true,
          ),
          'props': ToolParam(
            type: 'string',
            description: 'Optional JSON object props',
            required: false,
          ),
        },
        handler: (args) async => 'inject_card',
      ),
    );

    allTools.add(
      ToolDefinition(
        name: 'done',
        description:
            'Complete the task with a user-facing response. Use text for simple replies, or use reply (JSON string) plus previewText for rich chat replies.',
        parameters: {
          'success': ToolParam(
            type: 'boolean',
            description:
                'True if the goal was successfully completed, false otherwise',
            required: true,
          ),
          'text': ToolParam(
            type: 'string',
            description: 'Response message to the user',
            required: false,
          ),
          'reply': ToolParam(
            type: 'string',
            description:
                'Optional JSON string representing an array of rich reply nodes for chat rendering.',
            required: false,
          ),
          'previewText': ToolParam(
            type: 'string',
            description:
                'Plain text preview used for history, notifications, and transcript previews.',
            required: false,
          ),
          'message': ToolParam(
            type: 'string',
            description: 'Alternative to text parameter',
            required: false,
          ),
        },
        handler: (args) async => 'done',
      ),
    );

    allTools.add(
      ToolDefinition(
        name: 'ask_user',
        description:
            'Communicate with the user. Use this to ask questions, request explicit permission for app actions, answer a direct question, or collect missing low-risk workflow data that can authorize routine in-flow steps.',
        parameters: {
          'question': ToolParam(
            type: 'string',
            description: 'The message or question to say to the user',
            required: true,
          ),
          'request_app_action': ToolParam(
            type: 'boolean',
            description:
                'Set to true when requesting permission to take an action in the app (navigate, tap, investigate). Shows explicit approval buttons to the user.',
            required: true,
          ),
          'grants_workflow_approval': ToolParam(
            type: 'boolean',
            description:
                'Optional. Set to true only when asking for missing low-risk input or a low-risk selection that you will directly apply in the current action workflow. If the user answers, their answer authorizes routine in-flow actions like typing/selecting/toggling, but NOT irreversible final commits or support investigations.',
            required: false,
          ),
        },
        handler: (args) async => 'ask_user',
      ),
    );

    for (final entry in config.customTools.entries) {
      allTools.removeWhere((tool) => tool.name == entry.key);
      allTools.add(entry.value);
    }

    return allTools;
  }

  void _registerBuiltInTools() {
    _tools['tap'] = TapTool();
    _tools['type'] = TypeTool();
    _tools['scroll'] = ScrollTool();
    _tools['keyboard'] = KeyboardTool();
    _tools['long_press'] = LongPressTool();
    _tools['adjust_slider'] = SliderTool();
    _tools['select_picker'] = PickerTool();
    _tools['set_date'] = DatePickerTool();
    _tools['guide_user'] = GuideTool();
  }

  /// Returns the effective tool list for the current execution context.
  /// When enableUiControl=false, strips all UI-interaction tools so the
  /// LLM acts as a knowledge-only assistant — mirrors RN's enableUIControl=false.
  static const _uiControlTools = {
    'tap',
    'type',
    'scroll',
    'keyboard',
    'navigate',
    'long_press',
    'adjust_slider',
    'select_picker',
    'set_date',
    'guide_user',
    'ask_user',
  };
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

  Future<ExecutionResult> execute(
    String instruction, {
    List<Map<String, String>>? chatHistory,
  }) async {
    if (_isRunning) {
      return ExecutionResult(
        success: false,
        message: 'Agent is already running.',
        steps: const [],
      );
    }

    _isRunning = true;
    _isCancelRequested = false;
    _history.clear();
    _lastGoal = instruction;
    _pendingCriticalVerification = null;
    _verificationObservation = null;
    _lastVerifiedCriticalAction = null;

    Logger.info('Starting agent execution: "$instruction"');

    // Start error suppression for graceful handling
    _startErrorSuppression();

    try {
      final hasKnowledge = _knowledgeService != null;
      final systemPrompt = config.enableUiControl
          ? buildSystemPrompt(
              config.language ?? 'en',
              hasKnowledge: hasKnowledge,
              isCopilot: config.interactionMode != AppInteractionMode.autopilot,
              supportStyle: config.supportStyle,
              userInstructions: config.instructions,
            )
          : buildKnowledgeOnlyPrompt(
              config.language ?? 'en',
              hasKnowledge: hasKnowledge,
              userInstructions: config.instructions,
            );

      for (int step = 1; step <= config.maxSteps; step++) {
        if (_isCancelRequested) {
          return ExecutionResult(
            success: false,
            message: 'Cancelled by user.',
            steps: _history,
          );
        }

        config.onStatusUpdate?.call('Thinking (Step $step)...');
        Logger.info('===== Step $step/${config.maxSteps} =====');

        // 1. Read current platform snapshot
        final snapshot = await _platformAdapter.getScreenSnapshot();
        var interactives = snapshot.elements;

        // ── Security: Blacklist / Whitelist filtering ──────────────
        final blacklist = config.interactiveBlacklist;
        final whitelist = config.interactiveWhitelist;
        if (blacklist != null && blacklist.isNotEmpty) {
          final blackIds = blacklist
              .map(
                (k) => k.currentContext?.findRenderObject()?.debugSemantics?.id,
              )
              .whereType<int>()
              .toSet();
          interactives = interactives.where((e) {
            return e.semanticsNodeId == null ||
                !blackIds.contains(e.semanticsNodeId);
          }).toList();
        }
        if (whitelist != null && whitelist.isNotEmpty) {
          final whiteIds = whitelist
              .map(
                (k) => k.currentContext?.findRenderObject()?.debugSemantics?.id,
              )
              .whereType<int>()
              .toSet();
          interactives = interactives.where((e) {
            return e.semanticsNodeId != null &&
                whiteIds.contains(e.semanticsNodeId);
          }).toList();
        }
        _lastElements = interactives;

        final elementsText = snapshot.elementsText;
        final screenName = snapshot.screenName;
        final routeNames = snapshot.availableScreens;

        await _processPendingCriticalVerification(snapshot);

        Logger.info(
          '[AgentRuntime] Step $step snapshot: '
          'screen=$screenName, elementCount=${interactives.length}, '
          'sample=${_summarizeInteractiveElements(interactives)}',
        );
        Logger.info('Screen: $screenName');
        Logger.debug('Dehydrated:\n$elementsText');

        // ── Security: enableUiControl=false → knowledge-only mode ──
        // Get tools, filtering UI tools when control is disabled
        final tools = _getEffectiveTools();

        final maxStepsNum = config.maxSteps;
        final stepInfoBlock =
            '<agent_state>\n<step_info>\nStep $step of $maxStepsNum max possible steps\n</step_info>\n</agent_state>';
        final dynamicPreface = _buildScreenStatePreface(
          instruction: instruction,
          snapshot: snapshot,
        );
        final screenStateBlock = buildScreenStateText(
          screenName: screenName,
          availableScreens: routeNames,
          elementsText: elementsText,
          elements: interactives,
          preface: dynamicPreface,
        );
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
        final fullUserMessage =
            '$instruction$chatBlock\n\n$stepInfoBlock\n\n$screenStateBlock';
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

        _history.add(
          AgentStep(
            actionName: actionNameSafe,
            actionParams: actionParamsSafe,
            reasoning: result.reasoning,
          ),
        );

        // 5. Execute Action
        if (actionNameSafe == 'done') {
          if (actionParamsSafe['success'] != false &&
              _shouldBlockSuccessCompletion()) {
            Logger.warn(
              '[AgentRuntime] Blocking done(success=true) until pending critical action is verified.',
            );
            _history.last.result =
                'Blocked completion until critical action is verified.';
            continue;
          }
          final result = _buildDoneExecutionResult(actionParamsSafe);
          Logger.info('Task completed: ${result.previewText}');
          _history.last.result = result.previewText;
          return ExecutionResult(
            success: result.success,
            message: result.message,
            reply: result.reply,
            previewText: result.previewText,
            steps: _history,
          );
        }

        config.onStatusUpdate?.call(
          result.reasoning?.plan ?? 'Executing $actionNameSafe...',
        );
        final preActionSnapshot = _createVerificationSnapshotFromScreenSnapshot(
          snapshot,
        );
        final executionMessage = await executeTool(
          actionNameSafe,
          actionParamsSafe,
        );
        Logger.info('Result: $executionMessage');
        _history.last.result = executionMessage;

        if (_toolExecutionAppearsSuccessful(executionMessage)) {
          _maybeStartCriticalVerification(
            toolName: actionNameSafe,
            args: actionParamsSafe,
            preActionSnapshot: preActionSnapshot,
          );
        } else if (actionNameSafe != 'done') {
          _pendingCriticalVerification = null;
        }

        // Let UI settle after action (300ms matches RN default)
        await Future.delayed(const Duration(milliseconds: 300));
      }

      return ExecutionResult(
        success: false,
        message: 'Reached maximum steps limit.',
        previewText: 'Reached maximum steps limit.',
        steps: _history,
      );
    } catch (e) {
      Logger.error('Runtime error: $e');
      return ExecutionResult(
        success: false,
        message: 'Error: ${e.toString()}',
        previewText: 'Error: ${e.toString()}',
        steps: _history,
      );
    } finally {
      _isRunning = false;
      // Stop error suppression with grace period
      _stopErrorSuppression();
    }
  }

  Future<String> executeTool(String name, Map<String, dynamic> args) async {
    VerificationAction? verificationAction;
    if (_verifier != null && _verifier!.isEnabled()) {
      verificationAction = buildVerificationAction(
        toolName: name,
        args: args,
        elements: _lastElements,
        fallbackLabel: name,
      );
      if (_shouldBlockRepeatedVerifiedAction(verificationAction)) {
        final currentScreen = _getCurrentScreenName();
        Logger.warn(
          '[AgentRuntime] Blocking repeated verified action: '
          '${verificationAction.label} on $currentScreen',
        );
        return 'Action "${verificationAction.label}" already appears completed on the current screen. Re-check the current UI before repeating the same consequence-bearing action.';
      }
    }

    // ── Approval Workflow Check ─────────────────────────────────────
    // Check if this tool requires approval and if approval is granted
    if (_needsApproval(name) && !_hasWorkflowApproval()) {
      // Approval required - ask user for permission
      if (config.onAskUser != null) {
        try {
          // Get element label for better context
          final elementIndex = args['index'] as int?;
          String? elementLabel;
          if (elementIndex != null) {
            final element = _lastElements
                .where((e) => e.index == elementIndex)
                .firstOrNull;
            elementLabel = element?.label;
          }

          final request = ApprovalRequest(
            actionName: name,
            actionParams: args,
            elementLabel: elementLabel,
            reason: 'UI action requires workflow approval',
          );

          Logger.info('Requesting approval for $name');
          final response = await config.onAskUser!(request);

          if (response == '__APPROVAL_GRANTED__') {
            _grantWorkflowApproval(AppActionApprovalSource.userInput);
            Logger.info('Workflow approval granted via user input');
          } else {
            Logger.info('Workflow approval denied by user');
            return 'Action "$name" requires approval. Request denied.';
          }
        } catch (e) {
          Logger.error('Error requesting approval: $e');
          return 'Action "$name" requires approval, but approval system failed: $e';
        }
      } else {
        // No approval callback configured - deny the action
        Logger.warn(
          'Action "$name" requires approval but no onAskUser callback provided',
        );
        return 'Action "$name" requires approval. Please configure onAskUser callback.';
      }
    }

    // ── Tool Execution ─────────────────────────────────────────────
    String result;

    final customTool = config.customTools[name];
    if (customTool != null) {
      try {
        result = await customTool.handler(args);
      } catch (e) {
        result = 'Tool "$name" failed: $e';
      }
    }
    // 1. Check dynamic actions first
    else if (actionRegistry.getAction(name) != null) {
      final customAction = actionRegistry.getAction(name)!;
      try {
        final actionResult = await customAction.handler(args);
        result = actionResult.toString();
      } catch (e) {
        result = 'Action "$name" failed: $e';
      }
    }
    // 2. Check built-in tool mapped instances
    else if (_getBuiltInToolInstance(name) != null) {
      final toolInstance = _getBuiltInToolInstance(name)!;
      try {
        result = await toolInstance.execute(args, _buildToolContext());
      } catch (e) {
        result = 'Tool "$name" failed: $e';
      }
    }
    // 3. Special case simple inline tools
    else if (name == 'wait') {
      result = await _platformAdapter.executeAction(
        ActionIntent(action: 'wait', args: args),
      );
    } else if (name == 'navigate') {
      final screen = args['screen'] as String?;
      if (screen == null) {
        result = 'Missing screen name';
      } else {
        try {
          result = await _platformAdapter.executeAction(
            ActionIntent(action: 'navigate', args: args),
          );
        } catch (e) {
          result = 'Failed to navigate: $e';
        }
      }
    } else if (name == 'query_data') {
      final source = (args['source'] as String?)?.trim();
      final query = (args['query'] as String?)?.trim();
      if (source == null || source.isEmpty) {
        result = '❌ query_data requires a non-empty source name.';
      } else if (query == null || query.isEmpty) {
        result = '❌ query_data requires a non-empty query.';
      } else {
        final definition = dataRegistry.get(source);
        if (definition == null) {
          result =
              '❌ Unknown data source "$source". Available sources: ${dataRegistry.getAll().map((source) => source.name).join(', ')}';
        } else {
          try {
            final value = await definition.handler(
              DataQueryContext(
                query: query,
                screenName: _getCurrentScreenName(),
              ),
            );
            if (value is String) {
              result = value;
            } else {
              result = jsonEncode(value);
            }
          } catch (e) {
            result = '❌ query_data failed for "$source": $e';
          }
        }
      }
    } else if (name == 'ask_user') {
      String cleanQuestion = (args['question'] as String? ?? '').trim();
      if (cleanQuestion.isNotEmpty) {
        cleanQuestion = cleanQuestion
            .replaceAll(RegExp(r'\[\d+\]'), '')
            .replaceAll(RegExp(r'  +'), ' ')
            .trim();
      }
      if (cleanQuestion.isEmpty) {
        result = 'ask_user requires a non-empty question.';
      } else if (config.onAskUser == null) {
        result = '❓ $cleanQuestion';
      } else {
        final requestAppAction = args['request_app_action'] == true;
        final grantsWorkflowApproval = args['grants_workflow_approval'] == true;
        final answer = await config.onAskUser!(
          AskUserRequest(
            question: cleanQuestion,
            kind: requestAppAction
                ? AskUserKind.approval
                : AskUserKind.freeform,
            requestAppAction: requestAppAction,
            grantsWorkflowApproval: grantsWorkflowApproval,
          ),
        );

        if (answer == '__APPROVAL_GRANTED__') {
          _grantWorkflowApproval(AppActionApprovalSource.explicitButton);
          result = 'User answered: __APPROVAL_GRANTED__';
        } else if (answer == '__APPROVAL_REJECTED__') {
          result = 'Action not approved by user.';
        } else {
          if (grantsWorkflowApproval && answer.trim().isNotEmpty) {
            _grantWorkflowApproval(AppActionApprovalSource.userInput);
          }
          result = 'User answered: $answer';
        }
      }
    } else if (name == 'simplify_zone') {
      final zoneId = args['zoneId'] as String?;
      if (zoneId == null) {
        result = 'Missing zoneId';
      } else {
        final zone = globalZoneRegistry.getZone(zoneId);
        final controller = zone?.controller;
        if (controller == null) {
          result = 'Zone "$zoneId" is not mounted.';
        } else {
          controller.simplify();
          result = 'Simplified zone "$zoneId".';
        }
      }
    } else if (name == 'restore_zone') {
      final zoneId = args['zoneId'] as String?;
      if (zoneId == null) {
        result = 'Missing zoneId';
      } else {
        final zone = globalZoneRegistry.getZone(zoneId);
        final controller = zone?.controller;
        if (controller == null) {
          result = 'Zone "$zoneId" is not mounted.';
        } else {
          controller.restore();
          result = 'Restored zone "$zoneId".';
        }
      }
    } else if (name == 'render_block' || name == 'inject_card') {
      final zoneId = args['zoneId'] as String?;
      final blockType = (args['blockType'] ?? args['templateName']) as String?;
      if (zoneId == null || blockType == null) {
        result = 'Missing zoneId or blockType';
      } else {
        final zone = globalZoneRegistry.getZone(zoneId);
        if (zone == null) {
          result = 'Zone "$zoneId" is not registered.';
        } else if (!globalZoneRegistry.isActionAllowed(
          zoneId,
          ZoneAction.card,
        )) {
          result = 'Zone "$zoneId" does not allow block injection.';
        } else {
          final controller = zone.controller;
          if (controller == null) {
            result = 'Zone "$zoneId" is not mounted.';
          } else {
            final definition = globalBlockRegistry.get(blockType);
            if (definition == null) {
              result = 'Unknown block "$blockType".';
            } else {
              final rawProps = args['props'];
              final props = rawProps is Map<String, dynamic>
                  ? rawProps
                  : rawProps is String && rawProps.trim().isNotEmpty
                  ? Map<String, dynamic>.from(
                      (rawProps.startsWith('{')
                              ? (const JsonDecoder().convert(rawProps) as Map)
                              : const <String, dynamic>{})
                          .map((key, value) => MapEntry('$key', value)),
                    )
                  : <String, dynamic>{};
              controller.renderBlock(
                AiBlockNode(
                  id: '$blockType-${DateTime.now().millisecondsSinceEpoch}',
                  blockType: blockType,
                  props: props,
                  placement: BlockPlacement.zone,
                ),
              );
              result = name == 'inject_card'
                  ? 'Injected "$blockType" in zone "$zoneId". inject_card() is deprecated; prefer render_block().'
                  : 'Rendered "$blockType" in zone "$zoneId".';
            }
          }
        }
      }
    } else {
      result = 'Unknown tool: $name';
    }

    return result;
  }

  AgentTool? _getBuiltInToolInstance(String name) {
    switch (name) {
      case 'tap':
        return TapTool();
      case 'type':
        return TypeTool();
      case 'scroll':
        return ScrollTool();
      case 'keyboard':
        return KeyboardTool();
      case 'long_press':
        return LongPressTool();
      case 'adjust_slider':
        return SliderTool();
      case 'select_picker':
        return PickerTool();
      case 'set_date':
        return DatePickerTool();
      case 'guide_user':
        return GuideTool();
      default:
        return null;
    }
  }

  /// Mirrors RN's history summarization:
  /// When history > 8 steps, compress middle steps into a `steps_summary`
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
    final summaryLines = middleSteps
        .asMap()
        .entries
        .map((e) {
          final i = keepHead + e.key;
          final step = e.value;
          final resultPreview = step.result ?? step.error ?? 'unknown';
          final succeeded =
              resultPreview.contains('Error') || resultPreview.contains('fail')
              ? 'fail'
              : 'success';
          return 'Step ${i + 1}: ${step.actionName} → $succeeded';
        })
        .join('\n');

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
    if (config.routerAdapter != null) {
      final current = config.routerAdapter!.getCurrentScreenName();
      if (current.isNotEmpty) {
        return current;
      }
    }
    // Try GoRouter first
    if (config.router != null) {
      final matchedLocation = _readGoRouterMatchedLocation(config.router);
      if (matchedLocation != null && matchedLocation.isNotEmpty) {
        return matchedLocation;
      }
      try {
        final uri = config.router!.routeInformationProvider.value.uri;
        final path = uri.path.trim();
        if (path.isNotEmpty) {
          return path;
        }
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

  String? _readGoRouterMatchedLocation(dynamic router) {
    try {
      final dynamic state = router.state;
      final matchedLocation = state?.matchedLocation;
      if (matchedLocation is String && matchedLocation.isNotEmpty) {
        return matchedLocation;
      }
    } catch (_) {}

    try {
      final dynamic delegateState = router.routerDelegate?.state;
      final matchedLocation = delegateState?.matchedLocation;
      if (matchedLocation is String && matchedLocation.isNotEmpty) {
        return matchedLocation;
      }
    } catch (_) {}

    try {
      final dynamic currentConfiguration =
          router.routerDelegate?.currentConfiguration;
      final dynamic lastMatch = currentConfiguration?.last;
      final matchedLocation = lastMatch?.matchedLocation;
      if (matchedLocation is String && matchedLocation.isNotEmpty) {
        return matchedLocation;
      }
    } catch (_) {}

    return null;
  }

  List<String> _getRouteNames() {
    if (config.routerAdapter != null) {
      final screens = config.routerAdapter!.getAvailableScreens();
      if (screens.isNotEmpty) return screens;
    }
    // Try GoRouter routes
    if (config.router != null) {
      try {
        final List<String> names = [];
        for (final route in config.router!.configuration.routes) {
          _collectRouteNames(route, names, null);
        }
        return names;
      } catch (_) {}
    }
    return [];
  }

  void _collectRouteNames(
    dynamic route,
    List<String> names,
    String? parentPath,
  ) {
    try {
      final path = route.path as String?;
      if (path != null && path.isNotEmpty && path != '/') {
        names.add(_joinRoutePath(parentPath, path));
      }
      final sub = route.routes as List?;
      if (sub != null) {
        for (final r in sub) {
          _collectRouteNames(
            r,
            names,
            path != null && path.isNotEmpty && path != '/'
                ? _joinRoutePath(parentPath, path)
                : parentPath,
          );
        }
      }
    } catch (_) {}
  }

  String _joinRoutePath(String? parent, String child) {
    if (child.startsWith('/')) {
      return _normalizePath(child);
    }

    final normalizedParent = parent == null || parent.isEmpty || parent == '/'
        ? ''
        : _normalizePath(parent);
    return _normalizePath('$normalizedParent/$child');
  }

  String _normalizePath(String path) {
    final normalized = path.trim().replaceAll(RegExp(r'/+'), '/');
    if (normalized.isEmpty) {
      return '/';
    }
    if (!normalized.startsWith('/')) {
      return '/$normalized';
    }
    return normalized.endsWith('/') && normalized.length > 1
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  VerificationSnapshot _createVerificationSnapshotFromScreenSnapshot(
    ScreenSnapshot snapshot,
  ) {
    return VerificationSnapshot(
      screenName: snapshot.screenName,
      screenContent: snapshot.elementsText,
      elements: List<InteractiveElement>.from(snapshot.elements),
      screenshot: null,
    );
  }

  ScreenContext getScreenContext() {
    final rootContext = rootKey.currentContext;
    if (rootContext == null) {
      Logger.warn(
        '[AgentRuntime] rootKey.currentContext is null while building screen context.',
      );
    } else {
      Logger.info(
        '[AgentRuntime] Building screen context from root=${rootContext.widget.runtimeType}',
      );
    }
    final walker = ElementTreeWalker(config);
    final interactives = walker.walk(rootKey.currentContext!);
    _lastElements = interactives;
    final elementsText = ScreenDehydrator.dehydrate(interactives);
    Logger.info(
      '[AgentRuntime] Screen context extracted ${interactives.length} interactive elements. '
      'sample=${_summarizeInteractiveElements(interactives)}',
    );
    return ScreenContext(
      screenName: _getCurrentScreenName(),
      availableScreens: _getRouteNames(),
      elementsText: elementsText,
      elements: interactives,
    );
  }

  ExecutionResult _buildDoneExecutionResult(Map<String, dynamic> args) {
    final success = args['success'] != false;
    final text = args['text'] as String?;
    final message = args['message'] as String?;
    final replyPayload = args['reply'];
    final previewText = args['previewText'] as String?;

    final fallbackReplySource = replyPayload ?? text ?? message ?? '';
    var reply = normalizeRichContent(
      fallbackReplySource,
      text ?? message ?? '',
    );

    final structuredReplyCandidate = replyPayload is String
        ? replyPayload
        : text is String
        ? text
        : message is String
        ? message
        : '';
    if (structuredReplyCandidate.trim().isNotEmpty) {
      try {
        final parsedReply = jsonDecode(structuredReplyCandidate);
        reply = normalizeRichContent(parsedReply, text ?? message ?? '');
      } catch (_) {
        reply = normalizeRichContent(
          fallbackReplySource,
          text ?? message ?? '',
        );
      }
    }

    final replyPlainText = richContentToPlainText(reply).trim();
    final effectivePreview =
        previewText != null && previewText.trim().isNotEmpty
        ? previewText
        : replyPlainText.isNotEmpty
        ? replyPlainText
        : text ?? message ?? 'Done';

    return ExecutionResult(
      success: success,
      message: effectivePreview,
      reply: reply.isNotEmpty
          ? reply
          : normalizeRichContent(text ?? message ?? effectivePreview),
      previewText: effectivePreview,
      steps: _history,
    );
  }

  String buildScreenStateText({
    required String screenName,
    required List<String> availableScreens,
    required String elementsText,
    List<InteractiveElement> elements = const <InteractiveElement>[],
    bool includeTags = true,
    String? preface,
  }) {
    final buffer = StringBuffer();
    if (preface != null && preface.isNotEmpty) {
      buffer.writeln(preface);
      buffer.writeln();
    }

    if (includeTags) {
      buffer.writeln('<screen_state>');
    }

    buffer.writeln('Current Screen: $screenName');

    buffer.writeln('Available Screens: ${availableScreens.join(', ')}');

    if (config.screenMap != null) {
      final map = config.screenMap!;
      final routeTruth = availableScreens.toSet();
      final hintedRoutes = routeTruth
          .where((route) => map.screens.containsKey(route))
          .toList(growable: false);

      if (hintedRoutes.isEmpty && routeTruth.isEmpty) {
        buffer.writeln();
        buffer.writeln(
          'Screen Map Hints: generated map provided, but no live route catalog is available.',
        );
      } else if (hintedRoutes.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Screen Map Hints:');
        for (final route in hintedRoutes) {
          final entry = map.screens[route]!;
          final title = entry.title != null && entry.title!.trim().isNotEmpty
              ? ' (${entry.title!.trim()})'
              : '';
          buffer.writeln('- $route$title: ${entry.description}');
        }
      }

      if (map.chains.isNotEmpty) {
        final hintedChains = routeTruth.isEmpty
            ? const <List<String>>[]
            : map.chains
                  .where((chain) => chain.every(routeTruth.contains))
                  .toList(growable: false);
        if (hintedChains.isNotEmpty) {
          buffer.writeln();
          buffer.writeln('Navigation Chain Hints:');
          for (final chain in hintedChains) {
            buffer.writeln('  ${chain.join(' -> ')}');
          }
        }
      }
    }

    final activeStateSummary = ScreenDehydrator.summarizeActiveState(elements);
    if (activeStateSummary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(activeStateSummary);
    }

    final dataSources = dataRegistry.getAll();
    if (dataSources.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Available Data Sources:');
      for (final source in dataSources) {
        final schemaSummary = source.schema == null || source.schema!.isEmpty
            ? ''
            : ' Fields: ${source.schema!.entries.map((entry) => '${entry.key} (${entry.value.type})').join(', ')}.';
        buffer.writeln('- ${source.name}: ${source.description}$schemaSummary');
      }
    }

    final normalizedElements = elementsText.trim();
    if (normalizedElements.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(normalizedElements);
    }

    if (includeTags) {
      buffer.write('</screen_state>');
    }

    return buffer.toString().trimRight();
  }

  String? _buildScreenStatePreface({
    required String instruction,
    required ScreenSnapshot snapshot,
  }) {
    final observation = _verificationObservation;
    _verificationObservation = null;
    return observation;
  }

  Future<void> _processPendingCriticalVerification(
    ScreenSnapshot snapshot,
  ) async {
    var pending = _pendingCriticalVerification;
    final verifier = _verifier;
    if (pending == null || verifier == null || !verifier.isEnabled()) {
      return;
    }

    pending = PendingVerification(
      goal: pending.goal,
      action: pending.action,
      preAction: pending.preAction,
      followupSteps: pending.followupSteps + 1,
    );
    _pendingCriticalVerification = pending;
    final result = await verifier.verify(
      VerificationContext(
        goal: pending.goal,
        action: pending.action,
        preAction: pending.preAction,
        postAction: _createVerificationSnapshotFromScreenSnapshot(snapshot),
      ),
    );

    Logger.info(
      '[AgentRuntime] Pending verification result: '
      '${result.status} - ${result.evidence}',
    );

    if (result.status == VerificationStatus.success) {
      _verificationObservation =
          'Outcome verifier: The previous action "${pending.action.label}" completed successfully based on the current screen. Do not repeat the same consequence-bearing action unless the user explicitly asks you to do it again.';
      _lastVerifiedCriticalAction = _VerifiedCriticalAction(
        signature: _verificationActionSignature(pending.action),
        screenName: snapshot.screenName,
        label: pending.action.label,
      );
      _pendingCriticalVerification = null;
      return;
    }

    if (result.status == VerificationStatus.error) {
      final details = <String>[
        'Outcome verifier: The previous action "${pending.action.label}" did not complete successfully.',
        result.evidence,
      ];
      if (result.validationMessages != null &&
          result.validationMessages!.isNotEmpty) {
        details.add(
          'Visible validation messages: ${result.validationMessages!.join(' | ')}.',
        );
      }
      if (result.missingFields != null && result.missingFields!.isNotEmpty) {
        details.add(
          'Visible missing required fields: ${result.missingFields!.join(', ')}.',
        );
      }
      _verificationObservation = details.join(' ');
      return;
    }

    final maxFollowupSteps = verifier.getMaxFollowupSteps();
    final ageNote = pending.followupSteps >= maxFollowupSteps
        ? ' This critical action is still unverified after ${pending.followupSteps} follow-up checks.'
        : '';
    _verificationObservation =
        'Outcome verifier: The previous action "${pending.action.label}" is still unverified. ${result.evidence}$ageNote Before calling done(success=true), keep checking for success or error evidence on the current screen.';
  }

  void _maybeStartCriticalVerification({
    required String toolName,
    required Map<String, dynamic> args,
    required VerificationSnapshot preActionSnapshot,
  }) {
    final verifier = _verifier;
    if (verifier == null || !verifier.isEnabled()) {
      return;
    }

    final action = buildVerificationAction(
      toolName: toolName,
      args: args,
      elements: preActionSnapshot.elements,
      fallbackLabel: toolName,
    );

    if (!verifier.isCriticalAction(action)) {
      return;
    }

    _pendingCriticalVerification = PendingVerification(
      goal: _lastGoal ?? 'Complete the requested action',
      action: action,
      preAction: preActionSnapshot,
      followupSteps: 0,
    );
  }

  bool _shouldBlockSuccessCompletion() {
    return _pendingCriticalVerification != null;
  }

  bool _toolExecutionAppearsSuccessful(String message) {
    final normalized = message.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized.startsWith('tool "') && normalized.contains('failed')) {
      return false;
    }
    if (normalized.startsWith('failed to')) {
      return false;
    }
    if (normalized.startsWith('missing ')) {
      return false;
    }
    if (normalized.startsWith('unknown tool:')) {
      return false;
    }
    if (normalized.startsWith('action "') &&
        normalized.contains('requires approval')) {
      return false;
    }
    if (normalized.startsWith('action "') &&
        normalized.contains('already appears completed')) {
      return false;
    }
    if (normalized.startsWith('action not approved by user.')) {
      return false;
    }
    if (normalized.startsWith('could not ')) {
      return false;
    }
    if (normalized.startsWith('❌')) {
      return false;
    }
    return true;
  }

  bool _shouldBlockRepeatedVerifiedAction(VerificationAction action) {
    final verified = _lastVerifiedCriticalAction;
    final verifier = _verifier;
    if (verified == null ||
        verifier == null ||
        !verifier.isCriticalAction(action)) {
      return false;
    }

    return verified.screenName == _getCurrentScreenName() &&
        verified.signature == _verificationActionSignature(action);
  }

  String _verificationActionSignature(VerificationAction action) {
    final target = action.targetElement;
    final identity =
        target?.properties['key']?.toString() ??
        target?.properties['id']?.toString() ??
        action.label.toLowerCase();
    final role =
        target?.properties['role']?.toString() ??
        target?.type.name ??
        'unknown';
    return '${action.toolName}|$role|$identity';
  }

  String _summarizeInteractiveElements(
    List<InteractiveElement> elements, {
    int limit = 8,
  }) {
    if (elements.isEmpty) {
      return '(none)';
    }
    return elements
        .take(limit)
        .map(
          (element) =>
              '[${element.index}] ${element.label} (${element.type.name})',
        )
        .join(' | ');
  }
}

class ScreenContext {
  final String screenName;
  final List<String> availableScreens;
  final String elementsText;
  final List<InteractiveElement> elements;

  ScreenContext({
    required this.screenName,
    required this.availableScreens,
    required this.elementsText,
    this.elements = const <InteractiveElement>[],
  });
}

class _VerifiedCriticalAction {
  final String signature;
  final String screenName;
  final String label;

  const _VerifiedCriticalAction({
    required this.signature,
    required this.screenName,
    required this.label,
  });
}
