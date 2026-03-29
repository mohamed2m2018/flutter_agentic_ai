import 'package:flutter/widgets.dart';
import '../core/types.dart';

/// Context injected into tools during execution.
class ToolContext {
  /// The root widget context used for Element Tree walking
  final BuildContext rootContext;
  
  /// The current Agent Config
  final AgentConfig config;
  
  /// The most recently discovered interactive elements list
  final List<InteractiveElement> lastElements;
  
  /// Get current screen name
  final String Function() getCurrentScreenName;
  
  /// Get available route names
  final List<String> Function() getRouteNames;
  
  /// Build nested path
  final List<String> Function(String)? findScreenPath;

  /// Optional function to capture a screenshot base64
  final Future<String?> Function()? captureScreenshot;

  ToolContext({
    required this.rootContext,
    required this.config,
    required this.lastElements,
    required this.getCurrentScreenName,
    required this.getRouteNames,
    this.findScreenPath,
    this.captureScreenshot,
  });
}

/// Abstract base class for all UI Interaction Tools.
abstract class AgentTool {
  ToolDefinition get definition;
  
  Future<String> execute(Map<String, dynamic> args, ToolContext context);
}
