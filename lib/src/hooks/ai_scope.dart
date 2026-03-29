import 'package:flutter/widgets.dart';

import '../core/agent_runtime.dart';
import '../core/types.dart';

class AiAgentController {
  final AgentRuntime runtime;
  final Future<void> Function(String instruction) send;
  final VoidCallback cancel;
  final bool isRunning;
  final ExecutionResult? lastResult;

  AiAgentController({
    required this.runtime,
    required this.send,
    required this.cancel,
    required this.isRunning,
    this.lastResult,
  });
}

class AiAgentScope extends InheritedWidget {
  final AiAgentController controller;

  const AiAgentScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static AiAgentController of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AiAgentScope>();
    assert(result != null, 'No AiAgentScope found in context');
    return result!.controller;
  }

  @override
  bool updateShouldNotify(AiAgentScope oldWidget) {
    return controller.isRunning != oldWidget.controller.isRunning;
  }
}

extension AiAgentContextX on BuildContext {
  AiAgentController get ai => AiAgentScope.of(this);
}
