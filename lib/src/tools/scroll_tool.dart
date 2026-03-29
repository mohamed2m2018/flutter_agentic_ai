import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';


import '../core/types.dart';
import '../utils/logger.dart';
import 'types.dart';

class ScrollTool implements AgentTool {
  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'scroll',
    description: 'Scroll the current screen to reveal more content.',
    parameters: {
      'direction': ToolParam(
        type: 'string',
        description: 'Direction to scroll',
        enumValues: ['down', 'up', 'left', 'right'],
      ),
      'amount': ToolParam(
        type: 'string',
        description: 'Amount to scroll',
        enumValues: ['page', 'toEnd', 'toStart'],
        required: false,
      ),
      'containerIndex': ToolParam(
        type: 'integer',
        description: 'Optional index of a specific scrollable element (default: 0).',
        required: false,
      ),
    },
    handler: (args) => throw UnimplementedError(),
  );

  @override
  Future<String> execute(Map<String, dynamic> args, ToolContext context) async {
    final direction = args['direction'] as String?;
    final amount = args['amount'] as String? ?? 'page';
    final containerIndex = args['containerIndex'] as int? ?? 0;

    if (direction == null) throw Exception('Missing required parameter: direction');

    final scrollables = context.lastElements
        .where((e) => e.type == ElementType.scrollable)
        .toList();

    // Strategy 1: Dispatch via SemanticsAction on the scrollable node
    if (scrollables.isNotEmpty) {
      final targetScrollable = containerIndex < scrollables.length
          ? scrollables[containerIndex]
          : scrollables.first;

      if (targetScrollable.semanticsNodeId != null) {
        final owner = RendererBinding.instance.rootPipelineOwner.semanticsOwner;
        if (owner != null) {
          try {
            SemanticsAction action;
            if (amount == 'toEnd') {
              action = direction == 'up' || direction == 'left'
                  ? SemanticsAction.scrollLeft
                  : SemanticsAction.scrollDown;
            } else if (amount == 'toStart') {
              action = direction == 'up' || direction == 'left'
                  ? SemanticsAction.scrollUp
                  : SemanticsAction.scrollLeft;
            } else {
              // page scroll
              action = switch (direction) {
                'down' => SemanticsAction.scrollDown,
                'up'   => SemanticsAction.scrollUp,
                'left' => SemanticsAction.scrollLeft,
                _      => SemanticsAction.scrollRight,
              };
            }
            owner.performAction(targetScrollable.semanticsNodeId!, action);
            return 'Scrolled $direction by $amount successfully.';
          } catch (e) {
            Logger.warn('SemanticsAction scroll failed: $e — trying ScrollableState fallback');
          }
        }
      }
    }

    // Strategy 2: Find ScrollableState from widget element reference
    Element? targetElement;
    if (scrollables.isNotEmpty) {
      final el = containerIndex < scrollables.length
          ? scrollables[containerIndex].element
          : scrollables.first.element;
      targetElement = el;
    }

    if (targetElement == null || !targetElement.mounted) {
      // Last resort: use the rootContext scrollable
      final scrollableState = Scrollable.maybeOf(context.rootContext);
      if (scrollableState == null) {
        throw Exception('No scrollable content found on this screen.');
      }
      return _scrollViaPosition(scrollableState.position, direction, amount);
    }

    final scrollableState = Scrollable.maybeOf(targetElement) ??
        targetElement.findAncestorStateOfType<ScrollableState>();
    if (scrollableState == null) {
      throw Exception('Could not find ScrollableState for target element.');
    }

    return _scrollViaPosition(scrollableState.position, direction, amount);
  }

  Future<String> _scrollViaPosition(
      ScrollPosition pos, String direction, String amount) async {
    double targetOffset = pos.pixels;
    final viewportDimension = pos.viewportDimension;
    final isReverse = direction == 'up' || direction == 'left';
    final sign = isReverse ? -1 : 1;

    if (amount == 'page') {
      targetOffset += sign * viewportDimension * 0.8;
    } else if (amount == 'toEnd') {
      targetOffset = pos.maxScrollExtent;
    } else if (amount == 'toStart') {
      targetOffset = pos.minScrollExtent;
    }

    targetOffset = targetOffset.clamp(pos.minScrollExtent, pos.maxScrollExtent);

    if ((targetOffset - pos.pixels).abs() < 1.0) {
      return 'Already at the $direction edge of the scrollable area.';
    }

    await pos.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    await Future.delayed(const Duration(milliseconds: 100));
    return 'Scrolled $direction by $amount successfully.';
  }
}
