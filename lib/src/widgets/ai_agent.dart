import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/agent_runtime.dart';
import '../core/types.dart';
import '../providers/gemini_provider.dart';
import '../hooks/ai_scope.dart';
import 'agent_overlay.dart';
import 'agent_chat_bar.dart';

/// AiAgent — Root widget that wraps your app with the AI agent engine.
///
/// Mirrors react-native-agentic-ai's `<AIAgent>` prop surface exactly.
///
/// ```dart
/// AiAgent(
///   apiKey: 'YOUR_KEY',       // or use provider: GeminiProvider(...)
///   maxSteps: 15,
///   router: router,
///   instructions: 'You are a helpful assistant for ShopFlow.',
///   onResult: (result) => print(result.message),
///   accentColor: Colors.deepPurple,
///   child: MaterialApp.router(...),
/// )
/// ```
class AiAgent extends StatefulWidget {
  // ─── Provider ─────────────────────────────────────────────────
  /// API key for direct Gemini access (dev/prototyping only).
  final String? apiKey;
  /// Pre-configured provider instance (takes precedence over apiKey).
  final AiProvider? provider;
  /// Proxy URL for production — routes LLM traffic through your backend.
  final String? proxyUrl;
  final Map<String, String>? proxyHeaders;
  /// LLM model override.
  final String? model;

  // ─── Behavior ─────────────────────────────────────────────────
  /// Maximum steps per task (default: 15).
  final int maxSteps;
  /// Instructions to guide agent behavior on all screens.
  final String? instructions;
  /// go_router instance for deep navigation.
  final dynamic router;
  /// Language: 'en' | 'ar' (controls chat bar placeholder and RTL).
  final String language;
  /// Pre-generated screen map for navigation intelligence.
  final ScreenMap? screenMap;
  /// Max token budget per task (auto-stops when exceeded).
  final int? maxTokenBudget;
  /// Max estimated cost in USD per task.
  final double? maxCostUsd;
  /// Enable debug logging (default: false).
  final bool debug;

  // ─── Lifecycle ─────────────────────────────────────────────────
  /// Called when the agent completes a task.
  final void Function(ExecutionResult result)? onResult;
  /// Called before each step.
  final Future<void> Function(int stepCount)? onBeforeStep;
  /// Called after each step.
  final Future<void> Function(List<AgentStep> history)? onAfterStep;
  /// Called when status changes (used to drive live status text).
  final void Function(String status)? onStatusUpdate;

  // ─── UI ────────────────────────────────────────────────────────
  /// Quick accent color for FAB + send button (shorthand for theme.primaryColor).
  final Color? accentColor;
  /// Full theme overrides for the chat bar. Overrides accentColor.
  final AgentChatBarTheme? theme;
  /// Show/hide the floating agent chat bar (default: true).
  final bool showChatBar;

  // ─── Security ─────────────────────────────────────────────────
  /// Elements the AI must NOT tap/type/interact with.
  /// Pass GlobalKeys of containers to blacklist their children.
  /// Mirrors react-native-agentic-ai's `interactiveBlacklist`.
  final List<GlobalKey>? interactiveBlacklist;

  /// If set, the AI can ONLY interact with these elements (whitelist mode).
  /// Mirrors react-native-agentic-ai's `interactiveWhitelist`.
  final List<GlobalKey>? interactiveWhitelist;

  /// Transform screen content before the LLM sees it.
  /// Use to mask PII, credit card numbers, passwords, etc.
  /// Example: (content) async => content.replaceAll(ccRegex, '****')
  final Future<String> Function(String content)? transformScreenContent;

  /// Set to false to make the AI a knowledge-only assistant
  /// (disables tap/type/scroll tools). Default: true.
  final bool enableUiControl;

  // ─── App ───────────────────────────────────────────────────────
  /// The app to wrap — typically MaterialApp.router or CupertinoApp.
  final Widget child;

  const AiAgent({
    super.key,
    // Provider (use one of these)
    this.apiKey,
    this.provider,
    this.proxyUrl,
    this.proxyHeaders,
    this.model,
    // Behavior
    this.maxSteps = 15,
    this.instructions,
    this.router,
    this.language = 'en',
    this.screenMap,
    this.maxTokenBudget,
    this.maxCostUsd,
    this.debug = false,
    // Lifecycle
    this.onResult,
    this.onBeforeStep,
    this.onAfterStep,
    this.onStatusUpdate,
    // Security
    this.interactiveBlacklist,
    this.interactiveWhitelist,
    this.transformScreenContent,
    this.enableUiControl = true,
    // UI
    this.accentColor,
    this.theme,
    this.showChatBar = true,
    // Required
    required this.child,
  });

  @override
  State<AiAgent> createState() => _AiAgentState();
}

class _AiAgentState extends State<AiAgent> {
  late AgentRuntime _runtime;
  late AiAgentController _controller;
  final GlobalKey _rootKey = GlobalKey();

  bool _isRunning = false;
  String _statusText = '';
  ExecutionResult? _lastResult;

  @override
  void initState() {
    super.initState();
    // ── Security: Production apiKey warning ──────────────────────
    // Mirrors RN's warning: never ship raw API keys in production builds.
    if (const bool.fromEnvironment('dart.vm.product') &&
        widget.apiKey != null &&
        widget.apiKey!.isNotEmpty &&
        widget.proxyUrl == null &&
        widget.provider == null) {
      debugPrint(
        '[flutter_agentic_ai] ⚠️ SECURITY WARNING: You are using `apiKey` directly '
        'in a release build. This exposes your Gemini API key in the app binary. '
        'Use `proxyUrl` to route requests through your secured backend instead.'
      );
    }
    _initRuntime();
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  void _initRuntime() {
    final effectiveProvider = widget.provider ??
        GeminiProvider(
          apiKey: widget.apiKey ?? '',
          modelName: widget.model ?? 'gemini-2.5-flash',
        );

    final config = AgentConfig(
      maxSteps: widget.maxSteps,
      language: widget.language,
      instructions: widget.instructions,
      router: widget.router,
      model: widget.model,
      proxyUrl: widget.proxyUrl,
      proxyHeaders: widget.proxyHeaders,
      screenMap: widget.screenMap,
      maxTokenBudget: widget.maxTokenBudget,
      maxCostUsd: widget.maxCostUsd,
      onBeforeStep: widget.onBeforeStep,
      onAfterStep: widget.onAfterStep,
      interactiveBlacklist: widget.interactiveBlacklist,
      interactiveWhitelist: widget.interactiveWhitelist,
      transformScreenContent: widget.transformScreenContent,
      enableUiControl: widget.enableUiControl,
      onFinish: widget.onResult != null
          ? (result) async => widget.onResult!(result)
          : null,
      onStatusUpdate: (status) {
        if (mounted) setState(() => _statusText = status);
        widget.onStatusUpdate?.call(status);
      },
    );

    _runtime = AgentRuntime(
      provider: effectiveProvider,
      config: config,
      rootKey: _rootKey,
    );

    _updateController();
  }

  void _updateController() {
    _controller = AiAgentController(
      runtime: _runtime,
      isRunning: _isRunning,
      lastResult: _lastResult,
      send: (instruction) async {
        if (_isRunning) return;
        setState(() {
          _isRunning = true;
          _statusText = 'Starting...';
          _lastResult = null;
        });
        _updateController();

        try {
          final result = await _runtime.execute(instruction);
          if (mounted) setState(() => _lastResult = result);
        } finally {
          if (mounted) {
            setState(() {
              _isRunning = false;
              _statusText = '';
            });
            _updateController();
          }
        }
      },
      cancel: () {
        _runtime.cancel();
        if (mounted) {
          setState(() {
            _isRunning = false;
            _statusText = '';
          });
          _updateController();
        }
      },
    );
  }

  @override
  void didUpdateWidget(AiAgent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.apiKey != widget.apiKey ||
        oldWidget.provider != widget.provider ||
        oldWidget.maxSteps != widget.maxSteps ||
        oldWidget.instructions != widget.instructions ||
        oldWidget.router != widget.router;
    if (changed) {
      _runtime.dispose();
      _initRuntime();
    }
  }

  AgentChatBarTheme _resolveTheme() {
    if (widget.theme != null) return widget.theme!;
    if (widget.accentColor != null) {
      return AgentChatBarTheme(primaryColor: widget.accentColor);
    }
    return const AgentChatBarTheme();
  }

  @override
  Widget build(BuildContext context) {
    return AiAgentScope(
      controller: _controller,
      child: KeyedSubtree(
        key: _rootKey,
        // Inject Material + Localizations so AgentChatBar's TextField
        // works even though we render above MaterialApp in the widget tree.
        child: Localizations(
          locale: const Locale('en'),
          delegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  widget.child,
                  // Thinking pill
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_isRunning,
                      child: AgentOverlay(
                        visible: _isRunning,
                        statusText: _statusText,
                        onCancel: _controller.cancel,
                      ),
                    ),
                  ),
                  // Floating chat bar
                  if (widget.showChatBar)
                    AgentChatBar(
                      onSend: _controller.send,
                      isThinking: _isRunning,
                      lastResult: _lastResult,
                      language: widget.language,
                      onDismiss: () => setState(() => _lastResult = null),
                      onCancel: _controller.cancel,
                      theme: _resolveTheme(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
