import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/rich_ui_theme.dart';

/// HighlightOverlay — Visual highlight for guide_user tool.
///
/// Displays a pulsing highlight around a specific element to draw
/// user attention. Used by the guide tool to show users where to tap.
class HighlightOverlay extends StatefulWidget {
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Duration duration;
  final Color? highlightColor;
  final double cornerRadius;
  final EdgeInsets padding;

  const HighlightOverlay({
    super.key,
    this.label,
    this.onTap,
    this.onDismiss,
    this.duration = const Duration(seconds: 5),
    this.highlightColor,
    this.cornerRadius = 12,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  State<HighlightOverlay> createState() => _HighlightOverlayState();
}

class _HighlightOverlayState extends State<HighlightOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat();

    // Auto-dismiss after duration
    if (widget.duration != Duration.zero) {
      _dismissTimer = Timer(widget.duration, () {
        if (mounted) {
          widget.onDismiss?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = RichUiThemeScope.of(context).chat;

    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        widget.onDismiss?.call();
      },
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.3),
        child: _HighlightPainter(
          label: widget.label,
          pulseAnimation: _pulseAnimation,
          highlightColor: widget.highlightColor ?? theme.accent,
          cornerRadius: widget.cornerRadius,
          padding: widget.padding,
        ),
      ),
    );
  }
}

class _HighlightPainter extends StatelessWidget {
  final String? label;
  final Animation<double> pulseAnimation;
  final Color highlightColor;
  final double cornerRadius;
  final EdgeInsets padding;

  const _HighlightPainter({
    required this.label,
    required this.pulseAnimation,
    required this.highlightColor,
    required this.cornerRadius,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height / 2);

    // Default highlight size (centered on screen)
    final highlightSize = Size(size.width * 0.6, size.height * 0.3);
    final highlightRect = Rect.fromCenter(
      center: center,
      width: highlightSize.width,
      height: highlightSize.height,
    ).inflate(padding.left + padding.right);

    return Stack(
      children: [
        // Dark overlay with hole
        CustomPaint(
          size: size,
          painter: _HolePainter(
            highlightRect: highlightRect,
            cornerRadius: cornerRadius,
          ),
        ),

        // Pulsing border
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            final pulseValue = pulseAnimation.value;
            final pulseWidth = 4.0 + (4.0 * math.sin(pulseValue * math.pi * 2));
            final pulseOpacity = 0.6 + (0.4 * math.sin(pulseValue * math.pi * 2));

            return CustomPaint(
              size: size,
              painter: _PulseBorderPainter(
                highlightRect: highlightRect,
                cornerRadius: cornerRadius,
                color: highlightColor.withValues(alpha: pulseOpacity),
                width: pulseWidth,
              ),
            );
          },
        ),

        // Label above highlight
        if (label != null && label!.isNotEmpty)
          Positioned(
            top: highlightRect.top - 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

        // Tap instruction below highlight
        Positioned(
          top: highlightRect.bottom + 16,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Tap here',
              style: TextStyle(
                color: highlightColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Painter for the dark overlay with a transparent hole.
class _HolePainter extends CustomPainter {
  final Rect highlightRect;
  final double cornerRadius;

  _HolePainter({
    required this.highlightRect,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Create path for the overlay with a hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        highlightRect,
        Radius.circular(cornerRadius),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);
  }

  @override
  bool shouldRepaint(_HolePainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}

/// Painter for the pulsing border around the highlight.
class _PulseBorderPainter extends CustomPainter {
  final Rect highlightRect;
  final double cornerRadius;
  final Color color;
  final double width;

  _PulseBorderPainter({
    required this.highlightRect,
    required this.cornerRadius,
    required this.color,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final rRect = RRect.fromRectAndRadius(
      highlightRect.inflate(width / 2),
      Radius.circular(cornerRadius + width / 2),
    );

    canvas.drawRRect(rRect, borderPaint);
  }

  @override
  bool shouldRepaint(_PulseBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.width != width ||
        oldDelegate.highlightRect != highlightRect;
  }
}

/// Target highlight for a specific widget position.
class TargetHighlight extends StatelessWidget {
  final GlobalKey targetKey;
  final String? label;
  final VoidCallback? onDismiss;
  final Duration duration;
  final Color? highlightColor;

  const TargetHighlight({
    super.key,
    required this.targetKey,
    this.label,
    this.onDismiss,
    this.duration = const Duration(seconds: 5),
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return _TargetHighlight(
      targetKey: targetKey,
      label: label,
      onDismiss: onDismiss,
      duration: duration,
      highlightColor: highlightColor,
    );
  }
}

class _TargetHighlight extends StatefulWidget {
  final GlobalKey targetKey;
  final String? label;
  final VoidCallback? onDismiss;
  final Duration duration;
  final Color? highlightColor;

  const _TargetHighlight({
    required this.targetKey,
    this.label,
    this.onDismiss,
    this.duration = const Duration(seconds: 5),
    this.highlightColor,
  });

  @override
  State<_TargetHighlight> createState() => _TargetHighlightState();
}

class _TargetHighlightState extends State<_TargetHighlight>
    with SingleTickerProviderStateMixin {
  Rect? _targetRect;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(_findTarget);
  }

  @override
  void didUpdateWidget(_TargetHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey) {
      SchedulerBinding.instance.addPostFrameCallback(_findTarget);
    }
  }

  void _findTarget(_) {
    if (_disposed) return;

    final renderObject = widget.targetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      try {
        final position = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;
        setState(() {
          _targetRect = Rect.fromLTWH(
            position.dx,
            position.dy,
            size.width,
            size.height,
          );
        });
      } catch (_) {
        // Target not available yet
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_targetRect == null) {
      return const SizedBox.shrink();
    }

    return _PositionedHighlight(
      targetRect: _targetRect!,
      label: widget.label,
      onDismiss: widget.onDismiss,
      duration: widget.duration,
      highlightColor: widget.highlightColor,
    );
  }
}

/// Positioned highlight at a specific screen location.
class _PositionedHighlight extends StatefulWidget {
  final Rect targetRect;
  final String? label;
  final VoidCallback? onDismiss;
  final Duration duration;
  final Color? highlightColor;

  const _PositionedHighlight({
    required this.targetRect,
    this.label,
    this.onDismiss,
    this.duration = const Duration(seconds: 5),
    this.highlightColor,
  });

  @override
  State<_PositionedHighlight> createState() => _PositionedHighlightState();
}

class _PositionedHighlightState extends State<_PositionedHighlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.repeat();

    _timer = Timer(widget.duration, () {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ),

        // Highlight border
        Positioned.fromRect(
          rect: widget.targetRect.inflate(8),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final value = _controller.value;
              final pulse = 2 + 2 * (1 + math.sin(value * math.pi * 2)) / 2;
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.highlightColor ?? Colors.blue,
                    width: pulse,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          ),
        ),

        // Label
        if (widget.label != null)
          Positioned(
            left: widget.targetRect.left + (widget.targetRect.width / 2) - 60,
            top: widget.targetRect.top - 45,
            child: _HighlightLabel(
              label: widget.label!,
              highlightColor: widget.highlightColor ?? Colors.blue,
            ),
          ),
      ],
    );
  }
}

class _HighlightLabel extends StatelessWidget {
  final String label;
  final Color highlightColor;

  const _HighlightLabel({
    required this.label,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: highlightColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
