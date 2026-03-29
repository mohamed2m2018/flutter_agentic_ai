import 'package:flutter/rendering.dart';


import '../core/types.dart';
import '../utils/logger.dart';
import 'types.dart';

class TapTool implements AgentTool {
  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'tap',
    description: 'Tap an interactive element by its index.',
    parameters: {
      'index': ToolParam(
        type: 'integer',
        description: 'The index of the element to tap',
      ),
    },
    handler: (args) => throw UnimplementedError('Handled by execute()'),
  );

  @override
  Future<String> execute(Map<String, dynamic> args, ToolContext context) async {
    final index = args['index'] as int?;
    if (index == null) throw Exception('Missing required parameter: index');

    final target = context.lastElements.where((e) => e.index == index).firstOrNull;
    if (target == null) {
      throw Exception('Element [$index] not found. Did the screen change?');
    }

    // Strategy 1: Dispatch via SemanticsOwner.performAction (preferred — works for
    // NavigationBar, Tab, BottomNavigationBar, etc. that don't expose callbacks)
    if (target.semanticsNodeId != null) {
      final owner = RendererBinding.instance.rootPipelineOwner.semanticsOwner;
      if (owner != null) {
        try {
          owner.performAction(target.semanticsNodeId!, SemanticsAction.tap);
          return 'Tapped [${target.index}] ${target.label} successfully.';
        } catch (e) {
          Logger.warn('SemanticsAction.tap failed for [${target.index}]: $e — trying widget fallback');
        }
      }
    }

    // Strategy 2: Widget callback fallback (for elements found via widget tree)
    if (target.element != null && target.element!.mounted) {
      final success = _performWidgetTap(target.element!);
      if (success) {
        return 'Tapped [${target.index}] ${target.label} successfully.';
      }
    }

    throw Exception('Could not tap [${target.index}] ${target.label}. Element may not be interactive.');
  }

  bool _performWidgetTap(dynamic targetElement) {
    final widget = targetElement.widget;

    // ignore: unnecessary_type_check
    final matchers = [
      () {
        try {
          if (widget.onPressed != null) { widget.onPressed!(); return true; }
        } catch (_) {}
        return false;
      },
      () {
        try {
          if (widget.onTap != null) { widget.onTap!(); return true; }
        } catch (_) {}
        return false;
      },
    ];

    for (final matcher in matchers) {
      if (matcher()) return true;
    }
    return false;
  }
}
