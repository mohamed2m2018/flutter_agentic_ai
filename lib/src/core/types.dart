import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

/// Core types for the Flutter AI SDK.

// ─── Agent Modes ──────────────────────────────────────────────

enum InteractionMode { text, voice, human }

@Deprecated('Use InteractionMode instead.')
typedef AgentMode = InteractionMode;

enum AppInteractionMode { copilot, autopilot }

// ─── Approval Workflow ─────────────────────────────────────────

enum AskUserKind { freeform, approval }

class AskUserRequest {
  final String question;
  final AskUserKind kind;
  final bool requestAppAction;
  final bool grantsWorkflowApproval;

  const AskUserRequest({
    required this.question,
    this.kind = AskUserKind.freeform,
    this.requestAppAction = false,
    this.grantsWorkflowApproval = false,
  });

  @override
  String toString() {
    return 'AskUserRequest(kind: $kind, question: $question, requestAppAction: $requestAppAction, grantsWorkflowApproval: $grantsWorkflowApproval)';
  }
}

/// Approval scope for app-altering actions in copilot mode
enum AppActionApprovalScope {
  /// No approval granted - UI actions are blocked
  none,

  /// Workflow approval granted - routine UI actions are allowed for current task
  workflow,
}

/// Source of approval for app-altering actions
enum AppActionApprovalSource {
  /// No approval source
  none,

  /// Approval granted via explicit button press
  explicitButton,

  /// Approval granted via user input response
  userInput,
}

/// Request for user approval in copilot mode
class ApprovalRequest extends AskUserRequest {
  final String actionName;
  final Map<String, dynamic> actionParams;
  final String? elementLabel;
  final String? reason;

  ApprovalRequest({
    required this.actionName,
    required this.actionParams,
    this.elementLabel,
    this.reason,
  }) : super(
         question: '',
         kind: AskUserKind.approval,
         requestAppAction: true,
       );

  @override
  String toString() {
    return 'ApprovalRequest(action: $actionName, params: $actionParams, label: $elementLabel)';
  }
}

// ─── Provider Names ──────────────────────────────────────────

enum AiProviderName { gemini, openai }

// ─── Interactive Element (discovered from Element tree) ─────────

enum ElementType {
  pressable,
  textInput,
  switchToggle,
  scrollable,
  slider,
  picker,
  datePicker,
  checkbox,
  text,
}

enum AiPriority {
  high,
  low,
}

/// Represents an interactive widget discovered on the screen.
class InteractiveElement {
  /// Unique index assigned during tree walk
  final int index;

  /// Element type (e.g. pressable, textInput)
  final ElementType type;

  /// Human-readable label (extracted from Text children or semantics)
  final String label;

  /// Declarative AI priority explicitly set by the developer
  final AiPriority? aiPriority;

  /// The nearest enclosing AiZone ID (if any)
  final String? zoneId;

  /// Reference to the Flutter Element for execution (nullable when semantics-based)
  final Element? element;

  /// SemanticsNode ID — used to dispatch SemanticsAction.tap instead of direct callback
  final int? semanticsNodeId;

  /// Key-value pairs for state/properties (e.g. checked, value, enabled)
  final Map<String, dynamic> properties;

  InteractiveElement({
    required this.index,
    required this.type,
    required this.label,
    this.aiPriority,
    this.zoneId,
    this.element,
    this.semanticsNodeId,
    this.properties = const {},
  });
}

// ─── Wireframe Snapshot ────────────────────────────────────────

/// A privacy-safe wireframe of the current screen for heatmap analytics.
class WireframeSnapshot {
  final String screen;
  final List<WireframeComponent> components;
  final int deviceWidth;
  final int deviceHeight;
  final String capturedAt;

  WireframeSnapshot({
    required this.screen,
    required this.components,
    required this.deviceWidth,
    required this.deviceHeight,
    required this.capturedAt,
  });

  /// Convert to JSON for telemetry.
  Map<String, dynamic> toJson() {
    return {
      'screen': screen,
      'components': components.map((c) => c.toJson()).toList(),
      'deviceWidth': deviceWidth,
      'deviceHeight': deviceHeight,
      'capturedAt': capturedAt,
    };
  }
}

/// A single interactive component in the wireframe.
class WireframeComponent {
  final String label;
  final String elementType;
  final int x; // Position normalized to 0-1000
  final int y;
  final int width; // Size normalized to 0-1000
  final int height;

  WireframeComponent({
    required this.label,
    required this.elementType,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'elementType': elementType,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}

// ─── Dehydrated Screen State ──────────────────────────────────

class DehydratedScreen {
  /// Current screen name (from routing state)
  final String screenName;

  /// All available screen names
  final List<String> availableScreens;

  /// Indexed interactive elements as text for the LLM prompt
  final String elementsText;

  /// Raw elements list for tool resolution
  final List<InteractiveElement> elements;

  DehydratedScreen({
    required this.screenName,
    required this.availableScreens,
    required this.elementsText,
    required this.elements,
  });
}

typedef InteractiveNode = InteractiveElement;

class NavigationSnapshot {
  final String currentScreenName;
  final List<String> availableScreens;

  const NavigationSnapshot({
    required this.currentScreenName,
    this.availableScreens = const [],
  });
}

class ZoneSnapshot {
  final String id;
  final bool allowInjectBlock;
  final bool interventionEligible;
  final bool proactiveIntervention;
  final List<String> blockNames;

  const ZoneSnapshot({
    required this.id,
    this.allowInjectBlock = false,
    this.interventionEligible = false,
    this.proactiveIntervention = false,
    this.blockNames = const [],
  });
}

class ScreenSnapshot {
  final String screenName;
  final List<String> availableScreens;
  final String elementsText;
  final List<InteractiveElement> elements;
  final List<ZoneSnapshot> zones;

  const ScreenSnapshot({
    required this.screenName,
    required this.availableScreens,
    required this.elementsText,
    this.elements = const [],
    this.zones = const [],
  });
}

class ActionIntent {
  final String action;
  final Map<String, dynamic> args;

  const ActionIntent({
    required this.action,
    this.args = const {},
  });
}

abstract class PlatformAdapter {
  Future<ScreenSnapshot> getScreenSnapshot();
  NavigationSnapshot getNavigationSnapshot();
  Future<String> executeAction(ActionIntent intent);
}

// ─── Screen Map (generated by CLI) ───────────────────────────

class ScreenMapEntry {
  final String? title;
  final String description;
  final List<String>? navigatesTo;
  final bool? safeDirectNavigation;

  ScreenMapEntry({
    this.title,
    required this.description,
    this.navigatesTo,
    this.safeDirectNavigation,
  });

  factory ScreenMapEntry.fromJson(Map<String, dynamic> json) {
    return ScreenMapEntry(
      title: json['title'] as String?,
      description: json['description'] as String? ?? 'Screen content',
      navigatesTo: (json['navigatesTo'] as List?)?.cast<String>(),
      safeDirectNavigation: json['safeDirectNavigation'] as bool?,
    );
  }
}

class ScreenMap {
  final String generatedAt;
  final String framework;
  final Map<String, ScreenMapEntry> screens;
  final List<List<String>> chains;

  ScreenMap({
    required this.generatedAt,
    required this.framework,
    required this.screens,
    required this.chains,
  });

  factory ScreenMap.fromJson(Map<String, dynamic> json) {
    var screensMap = <String, ScreenMapEntry>{};
    if (json['screens'] != null) {
      final screensObj = json['screens'] as Map<String, dynamic>;
      for (final key in screensObj.keys) {
        screensMap[key] = ScreenMapEntry.fromJson(screensObj[key]);
      }
    }

    var chainsList = <List<String>>[];
    if (json['chains'] != null) {
      chainsList = (json['chains'] as List)
          .map((e) => (e as List).cast<String>())
          .toList();
    }

    return ScreenMap(
      generatedAt: json['generatedAt'] as String? ?? '',
      framework: json['framework'] as String? ?? 'go_router',
      screens: screensMap,
      chains: chainsList,
    );
  }
}

// ─── Agent Execution & Configuration ──────────────────────────

class AgentReasoning {
  final String currentScreen;
  final String observation;
  final String? activeZone;
  final String goal;
  final String plan;
  final String? previousGoalEval;
  final String? memory;

  AgentReasoning({
    this.currentScreen = '',
    this.observation = '',
    this.activeZone,
    this.goal = '',
    this.plan = '',
    this.previousGoalEval,
    this.memory,
  });
}

class AgentStep {
  final int stepIndex;
  final AgentReasoning? reasoning;
  final String actionName;
  final Map<String, dynamic> actionParams;
  String? result;
  String? error;

  AgentStep({
    this.stepIndex = 0,
    this.reasoning,
    required this.actionName,
    required this.actionParams,
    this.result,
    this.error,
  });
}

class AgentAction {
  final String name;
  final Map<String, dynamic> input;
  final String output;

  AgentAction({
    required this.name,
    required this.input,
    required this.output,
  });
}

class ExecutionResult {
  final bool success;
  final String message;
  final Object? reply;
  final String previewText;
  final List<AgentStep> steps;

  ExecutionResult({
    required this.success,
    required this.message,
    this.reply,
    String? previewText,
    this.steps = const [],
  }) : previewText = previewText ?? message;
}

enum McpServerMode { auto, enabled, disabled }

class AgentConfig {
  /// Which LLM provider to use for text mode (default: gemini).
  final AiProviderName provider;

  /// API key (for prototyping only).
  final String? apiKey;

  /// The URL of your secure backend proxy (for production).
  final String? proxyUrl;

  /// Optional headers to send to your proxyUrl.
  final Map<String, String>? proxyHeaders;

  /// The model to use.
  final String? model;

  /// Maximum steps per task (default: 15).
  final int maxSteps;

  /// MCP server mode.
  final McpServerMode mcpServerMode;

  /// Elements the AI must NOT interact with.
  final List<GlobalKey>? interactiveBlacklist;

  /// If set, the AI can ONLY interact with these elements.
  final List<GlobalKey>? interactiveWhitelist;

  /// Automatically trigger errors if the app handles them gracefully (default: true).
  final bool reportErrorsAsExceptions;

  /// Extra time to wait after navigation/interaction before reading the tree.
  final Duration gracePeriod;

  // Lifecycle Callbacks
  final Future<void> Function(int stepCount)? onBeforeStep;
  final Future<void> Function(List<AgentStep> history)? onAfterStep;
  final Future<void> Function(ExecutionResult result)? onFinish;
  final Future<void> Function(Object error, ExecutionResult partialResult)? onError;
  
  /// Callback for agent thinking status
  final void Function(String message)? onStatusUpdate;

  // Instructions & Context
  final String? language;
  final String? instructions;
  final String? systemPromptSuffix;
  final String? toolInstructions;

  /// The pre-generated screen map containing routes and descriptions.
  final ScreenMap? screenMap;

  // Budget Guards
  final int? maxTokenBudget;
  final double? maxCostUsd;
  final void Function(TokenUsage usage, double estimatedCost)? onBudgetWarning;

  /// Allow the agent to interact with UI (default: true).
  final bool enableUiControl;

  /// Transform screen content before the LLM sees it.
  /// Use to mask PII, credit card numbers, passwords, or any sensitive data.
  /// Mirrors react-native-agentic-ai's `transformScreenContent` prop.
  /// Example: (content) async => content.replaceAll(cardNumberRegex, '****')
  final Future<String> Function(String content)? transformScreenContent;

  /// Router instance (go_router) used for deep navigation
  final dynamic router;
  final FlutterRouterAdapter? routerAdapter;
  final GlobalKey<NavigatorState>? navigatorKey;
  final PlatformAdapter? platformAdapter;
  final Map<String, ToolDefinition> customTools;

  /// Knowledge base configuration for RAG capabilities.
  /// Can be `List<KnowledgeEntry>` for static entries or a custom KnowledgeRetriever.
  final KnowledgeBaseConfig? knowledgeBase;
  final int? knowledgeMaxTokens;

  /// Initial approval scope for app-altering actions in copilot mode.
  final AppActionApprovalScope? initialApprovalScope;

  /// Copilot vs autopilot workflow gating.
  final AppInteractionMode interactionMode;

  /// Support persona preset mirrored from RN prompt surface.
  final String supportStyle;

  /// Callback for requesting user approval for app-altering actions.
  /// Return '__APPROVAL_GRANTED__' to grant workflow approval.
  /// Return any other value to deny approval.
  final Future<String> Function(AskUserRequest)? onAskUser;

  /// Verifier configuration for outcome verification.
  final VerifierConfig? verifier;

  AgentConfig({
    this.provider = AiProviderName.gemini,
    this.apiKey,
    this.proxyUrl,
    this.proxyHeaders,
    this.model,
    this.maxSteps = 15,
    this.mcpServerMode = McpServerMode.auto,
    this.interactiveBlacklist,
    this.interactiveWhitelist,
    this.reportErrorsAsExceptions = true,
    this.gracePeriod = const Duration(milliseconds: 1500),
    this.onBeforeStep,
    this.onAfterStep,
    this.onFinish,
    this.onError,
    this.onStatusUpdate,
    this.language,
    this.instructions,
    this.systemPromptSuffix,
    this.toolInstructions,
    this.screenMap,
    this.maxTokenBudget,
    this.maxCostUsd,
    this.onBudgetWarning,
    this.enableUiControl = true,
    this.transformScreenContent,
    this.router,
    this.routerAdapter,
    this.navigatorKey,
    this.platformAdapter,
    this.customTools = const {},
    this.knowledgeBase,
    this.knowledgeMaxTokens,
    this.initialApprovalScope,
    this.interactionMode = AppInteractionMode.copilot,
    this.supportStyle = 'warm-concise',
    this.onAskUser,
    this.verifier,
  });
}

// ─── Tools & Callbacks ───────────────────────────────────────

class ToolParam {
  final String type;
  final String description;
  final List<String>? enumValues;
  final bool required;

  ToolParam({
    required this.type,
    required this.description,
    this.enumValues,
    this.required = true,
  });
}

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, ToolParam> parameters;
  final Future<String> Function(Map<String, dynamic> args) handler;

  ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    required this.handler,
  });
}

// ─── Provider & Token Management ─────────────────────────────

class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double estimatedCostUSD;

  TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    this.totalTokens = 0,
    this.estimatedCostUSD = 0.0,
  });
}

class ProviderResult {
  final String? text;
  final String? actionName;
  final Map<String, dynamic>? actionParams;
  final AgentReasoning? reasoning;
  final TokenUsage? tokenUsage;
  final Object? rawResponse;

  ProviderResult({
    this.text,
    this.actionName,
    this.actionParams,
    this.reasoning,
    this.tokenUsage,
    this.rawResponse,
  });
}

abstract class AiProvider {
  Future<ProviderResult> generateContent({
    required String systemPrompt,
    required String userMessage,
    required List<ToolDefinition> tools,
    required List<AgentStep> history,
    String? screenshotBase64,
  });
}

// ─── Actions & Zones ─────────────────────────────────────────

class ActionParameterDef {
  final String type;
  final String description;
  final List<String>? enumValues;
  final bool required;

  ActionParameterDef({
    required this.type,
    required this.description,
    this.enumValues,
    this.required = true,
  });
}

class ActionDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters; // String or ActionParameterDef
  final FutureOr<Object?> Function(Map<String, dynamic> args) handler;

  ActionDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    required this.handler,
  });
}

class AiZoneConfig {
  final String id;
  final String? description;
  final bool allowSimplify;
  final bool allowGuide;
  final bool allowHighlight;
  final bool allowInjectBlock;
  @Deprecated('Use allowInjectBlock')
  final bool allowInjectCard;
  final bool interventionEligible;
  final bool proactiveIntervention;
  final List<BlockDefinition> blocks;

  AiZoneConfig({
    required this.id,
    this.description,
    this.allowSimplify = false,
    this.allowGuide = false,
    this.allowHighlight = true,
    this.allowInjectBlock = false,
    this.allowInjectCard = false,
    this.interventionEligible = false,
    this.proactiveIntervention = false,
    this.blocks = const [],
  });
}

class RegisteredZone {
  final AiZoneConfig config;
  final GlobalKey key;
  dynamic controller;

  RegisteredZone({
    required this.config,
    required this.key,
  });
}

// ─── Chat & Knowledge ────────────────────────────────────────

class AiMessage {
  final String role; // 'user', 'assistant', 'system'
  final Object content;
  final String previewText;
  final int timestamp;

  AiMessage({
    required this.role,
    required this.content,
    String? previewText,
    int? timestamp,
  })  : previewText = previewText ?? richContentToPlainText(content),
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
}

class KnowledgeEntry {
  final String title;
  final String content;
  final List<String>? tags;
  final List<String>? screens;
  final int? priority;

  KnowledgeEntry({
    required this.title,
    required this.content,
    this.tags,
    this.screens,
    this.priority,
  });
}

abstract class KnowledgeRetriever {
  Future<List<KnowledgeEntry>> retrieve(String query, String screenName);
}

/// Dynamic alias to support both static lists and custom retrievers.
typedef KnowledgeBaseConfig = dynamic; // List<KnowledgeEntry> or KnowledgeRetriever

// ─── Rich Content ─────────────────────────────────────────────

enum BlockPlacement { chat, zone }

enum BlockLifecycle { persistent, dismissible }

enum BlockInterventionType {
  errorPrevention,
  decisionSupport,
  contextualHelp,
  recovery,
  none,
}

sealed class AiRichNode {
  const AiRichNode();
}

class AiTextNode extends AiRichNode {
  final String text;

  const AiTextNode(this.text);
}

class AiBlockNode extends AiRichNode {
  final String id;
  final String blockType;
  final Map<String, dynamic> props;
  final BlockPlacement placement;
  final BlockLifecycle lifecycle;

  const AiBlockNode({
    required this.id,
    required this.blockType,
    required this.props,
    this.placement = BlockPlacement.chat,
    this.lifecycle = BlockLifecycle.dismissible,
  });
}

String richContentToPlainText(Object? content) {
  if (content == null) return '';
  if (content is String) return content;
  if (content is AiTextNode) return content.text;
  if (content is AiBlockNode) return '';
  if (content is List<AiRichNode>) {
    return content
        .whereType<AiTextNode>()
        .map((node) => node.text)
        .join('\n')
        .trim();
  }
  return content.toString();
}

List<AiRichNode> normalizeRichContent(Object? content, [String fallbackText = '']) {
  if (content == null) {
    return fallbackText.isEmpty ? const [] : [AiTextNode(fallbackText)];
  }
  if (content is List<AiRichNode>) return content;
  if (content is AiRichNode) return [content];
  if (content is List) {
    final parsedNodes = _decodeRichNodes(content);
    if (parsedNodes.isNotEmpty) return parsedNodes;
    return fallbackText.isEmpty
        ? [AiTextNode(content.toString())]
        : [AiTextNode(fallbackText)];
  }
  if (content is Map) {
    final parsedNodes = _decodeRichNodes(content);
    if (parsedNodes.isNotEmpty) return parsedNodes;
    return fallbackText.isEmpty
        ? [AiTextNode(content.toString())]
        : [AiTextNode(fallbackText)];
  }
  if (content is String) {
    final parsedNodes = _decodeRichNodes(content);
    if (parsedNodes.isNotEmpty) return parsedNodes;
    return [AiTextNode(content)];
  }
  return fallbackText.isEmpty ? [AiTextNode(content.toString())] : [AiTextNode(fallbackText)];
}

List<AiRichNode> _decodeRichNodes(Object? raw) {
  if (raw == null) return const [];
  if (raw is List<AiRichNode>) return raw;
  if (raw is AiRichNode) return [raw];
  if (raw is List) {
    return raw
        .map(_decodeRichNode)
        .whereType<AiRichNode>()
        .toList(growable: false);
  }
  if (raw is Map) {
    final node = _decodeRichNode(raw);
    return node == null ? const [] : [node];
  }
  if (raw is String) {
    final parsed = _parseRichNodeString(raw);
    if (parsed == null) return const [];
    return _decodeRichNodes(parsed);
  }
  return const [];
}

AiRichNode? _decodeRichNode(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final type = '${map['type'] ?? ''}'.trim();
  if (type == 'text') {
    final text = '${map['text'] ?? map['content'] ?? ''}';
    return text.isEmpty ? null : AiTextNode(text);
  }
  if (type == 'block') {
    final blockType = '${map['blockType'] ?? map['templateName'] ?? ''}'.trim();
    if (blockType.isEmpty) {
      return null;
    }
    final props = <String, dynamic>{};
    final rawProps = map['props'];
    if (rawProps is Map) {
      props.addAll(Map<String, dynamic>.from(rawProps));
    }
    for (final entry in map.entries) {
      if (_richBlockReservedKeys.contains(entry.key)) {
        continue;
      }
      props.putIfAbsent(entry.key, () => entry.value);
    }
    return AiBlockNode(
      id: '${map['id'] ?? '${blockType.toLowerCase()}-${map.hashCode}'}',
      blockType: blockType,
      props: props,
      placement: _decodePlacement('${map['placement'] ?? ''}'),
      lifecycle: _decodeLifecycle('${map['lifecycle'] ?? ''}'),
    );
  }
  return null;
}

const Set<String> _richBlockReservedKeys = {
  'type',
  'id',
  'blockType',
  'templateName',
  'props',
  'placement',
  'lifecycle',
};

Object? _parseRichNodeString(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (!_looksLikeStructuredRichContent(trimmed)) {
    return null;
  }

  try {
    return jsonDecode(trimmed);
  } catch (_) {
    // Fall through to tolerant parsing.
  }

  final normalizedKeys = trimmed.replaceAllMapped(
    RegExp(r'([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:)'),
    (match) => '${match[1]}"${match[2]}"${match[3]}',
  );
  final normalizedQuotes = normalizedKeys.replaceAllMapped(
    RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'"),
    (match) => jsonEncode(match[1]),
  );
  final normalizedBareValues = normalizedQuotes.replaceAllMapped(
    RegExp(r'(:\s*)([A-Za-z_][A-Za-z0-9_-]*)(\s*[,}\]])'),
    (match) {
      final value = match[2] ?? '';
      if (value == 'true' || value == 'false' || value == 'null') {
        return '${match[1]}$value${match[3]}';
      }
      return '${match[1]}"$value"${match[3]}';
    },
  );
  final normalizedTrailingCommas = normalizedBareValues.replaceAllMapped(
    RegExp(r',(\s*[}\]])'),
    (match) => match[1] ?? '',
  );

  try {
    return jsonDecode(normalizedTrailingCommas);
  } catch (_) {
    return null;
  }
}

bool _looksLikeStructuredRichContent(String value) {
  if (!(value.startsWith('[') || value.startsWith('{'))) {
    return false;
  }
  return value.contains('type') ||
      value.contains('blockType') ||
      value.contains('templateName') ||
      value.contains('content') ||
      value.contains('text');
}

BlockPlacement _decodePlacement(String? value) {
  return BlockPlacement.values.firstWhere(
    (placement) => placement.name == value,
    orElse: () => BlockPlacement.chat,
  );
}

BlockLifecycle _decodeLifecycle(String? value) {
  return BlockLifecycle.values.firstWhere(
    (lifecycle) => lifecycle.name == value,
    orElse: () => BlockLifecycle.dismissible,
  );
}

class DataFieldDef {
  final String type;
  final String description;
  final bool required;

  const DataFieldDef({
    required this.type,
    required this.description,
    this.required = false,
  });
}

class DataQueryContext {
  final String query;
  final String screenName;

  const DataQueryContext({
    required this.query,
    required this.screenName,
  });
}

class DataDefinition {
  final String name;
  final String description;
  final Map<String, DataFieldDef>? schema;
  final FutureOr<Object?> Function(DataQueryContext context) handler;

  const DataDefinition({
    required this.name,
    required this.description,
    this.schema,
    required this.handler,
  });
}

typedef BlockPreviewTextBuilder = String Function(Map<String, dynamic> props);
typedef BlockWidgetBuilder = Widget Function(BuildContext context, Map<String, dynamic> props);

class BlockDefinition {
  final String name;
  final BlockWidgetBuilder builder;
  final List<BlockPlacement> allowedPlacements;
  final Map<String, DataFieldDef>? propSchema;
  final BlockPreviewTextBuilder? previewTextBuilder;
  final BlockInterventionType interventionType;
  final bool interventionEligible;
  final List<String> styleSlots;

  const BlockDefinition({
    required this.name,
    required this.builder,
    this.allowedPlacements = const [BlockPlacement.chat, BlockPlacement.zone],
    this.propSchema,
    this.previewTextBuilder,
    this.interventionType = BlockInterventionType.none,
    this.interventionEligible = false,
    this.styleSlots = const [],
  });
}

class ConversationSummary {
  final String id;
  final String title;
  final String preview;
  final String previewRole;
  final int messageCount;
  final int createdAt;
  final int updatedAt;

  const ConversationSummary({
    required this.id,
    required this.title,
    this.preview = '',
    this.previewRole = 'assistant',
    this.messageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  String get previewText => preview;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'New conversation'}',
      preview: '${json['preview'] ?? json['previewText'] ?? ''}',
      previewRole: '${json['previewRole'] ?? 'assistant'}',
      messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
      createdAt:
          (json['createdAt'] as num?)?.toInt() ??
          (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

abstract class FlutterRouterAdapter {
  const FlutterRouterAdapter();

  FutureOr<void> push(String href);
  FutureOr<void> replace(String href);
  FutureOr<void> back();
  FutureOr<void> navigate(String screen, {Object? params});
  String getCurrentScreenName();
  List<String> getAvailableScreens();
  String? resolveRoute(String screen, {Object? params});
}

abstract class RouteCatalogProvider {
  const RouteCatalogProvider();

  List<String> getKnownRoutes();
}

// ─── Verification ──────────────────────────────────────────────────────

/// Configuration for the outcome verifier.
class VerifierConfig {
  final bool enabled;
  final int maxFollowupSteps;

  const VerifierConfig({
    this.enabled = true,
    this.maxFollowupSteps = 2,
  });
}

// ─── Telemetry ────────────────────────────────────────────────────────────

/// Configuration for the telemetry service.
class TelemetryConfig {
  final bool enabled;
  final String? analyticsKey;
  final String? baseUrl;
  final Map<String, String>? headers;
  final String? userId;
  final String? sessionId;

  const TelemetryConfig({
    this.enabled = true,
    this.analyticsKey,
    this.baseUrl,
    this.headers,
    this.userId,
    this.sessionId,
  });
}

/// Telemetry event for analytics tracking.
class TelemetryEvent {
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> properties;

  const TelemetryEvent({
    required this.name,
    required this.timestamp,
    this.properties = const {},
  });
}
