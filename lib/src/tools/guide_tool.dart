import 'package:flutter/material.dart';

import '../core/types.dart';
import '../utils/logger.dart';
import 'types.dart';

/// GuideTool — Highlight elements with user guidance messages.
///
/// Uses Flutter's Overlay and OverlayEntry system to display:
/// - Visual highlights around target elements
/// - Instructional messages near highlighted elements
/// - Auto-dismiss after configurable duration
class GuideTool implements AgentTool {
  @override
  ToolDefinition get definition => ToolDefinition(
        name: 'guide_user',
        description:
            'Highlight a specific element to draw the user\'s attention. Use when you want to show the user where to tap next. Auto-dismisses after a few seconds.',
        parameters: {
          'index': ToolParam(
            type: 'integer',
            description: 'The element index to highlight',
          ),
          'message': ToolParam(
            type: 'string',
            description:
                'Short instruction shown near the highlighted element (e.g. "Tap here to continue")',
          ),
          'autoRemoveAfterMs': ToolParam(
            type: 'integer',
            description:
                'Auto-dismiss after this many milliseconds. Default: 5000',
            required: false,
          ),
        },
        handler: (args) =>
            throw UnimplementedError('Handled by execute()'),
      );

  @override
  Future<String> execute(Map<String, dynamic> args, ToolContext context) async {
    // Validate parameters
    final index = args['index'] as int?;
    final message = args['message'] as String?;
    final autoRemoveAfterMs = args['autoRemoveAfterMs'] as int? ?? 5000;

    if (index == null || message == null) {
      throw Exception('Missing required parameters: index, message');
    }

    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    // Find target element
    final target =
        context.lastElements.where((e) => e.index == index).firstOrNull;
    if (target == null) {
      throw Exception(
          'Element [$index] not found. Did the screen change?');
    }

    // Check widget availability for position calculation
    if (target.element == null || !target.element!.mounted) {
      throw Exception(
          'Cannot guide to [$index]: no widget reference available for positioning.');
    }

    try {
      // Get element position for highlighting
      final renderObject = target.element!.findRenderObject();
      if (renderObject is! RenderBox) {
        throw Exception(
            'Element [$index] is not a RenderBox, cannot determine position.');
      }

      final position = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.paintBounds.size;

      Logger.info(
          'Guiding user to [$index] ${target.label} at position ${position.dx},${position.dy}');

      // Show the guide highlight
      _showGuideHighlight(
        context.rootContext,
        position,
        size,
        trimmedMessage,
        Duration(milliseconds: autoRemoveAfterMs),
      );

      return 'Guiding user to [$index] ${target.label}: "$trimmedMessage"';
    } catch (e) {
      Logger.error('Failed to show guide highlight: $e');
      throw Exception('Could not show guide highlight for [$index]: $e');
    }
  }

  void _showGuideHighlight(
    BuildContext context,
    Offset position,
    Size size,
    String message,
    Duration duration,
  ) {
    try {
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (overlayContext) => _GuideHighlight(
          targetRect: Rect.fromLTWH(position.dx, position.dy, size.width, size.height),
          message: message,
          onDismiss: () => overlayEntry.remove(),
        ),
      );

      overlay.insert(overlayEntry);
      Logger.info('Guide highlight shown, will auto-dismiss in ${duration.inMilliseconds}ms');

      // Auto-dismiss after duration
      Future.delayed(duration, () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
          Logger.info('Guide highlight auto-dismissed');
        }
      });
    } catch (e) {
      Logger.error('Failed to insert overlay: $e');
      rethrow;
    }
  }
}

class _GuideHighlight extends StatelessWidget {
  final Rect targetRect;
  final String message;
  final VoidCallback onDismiss;

  const _GuideHighlight({
    required this.targetRect,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Stack(
            children: [
              // Highlight border around target element
              Positioned(
                left: targetRect.left - 4,
                top: targetRect.top - 4,
                child: Container(
                  width: targetRect.width + 8,
                  height: targetRect.height + 8,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 3),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // Message tooltip positioned near the target
              Positioned(
                left: targetRect.left,
                top: targetRect.bottom + 8,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth - targetRect.left - 16,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Optional tap-to-dismiss hint
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Tap anywhere to dismiss',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
