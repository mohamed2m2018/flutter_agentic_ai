import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/types.dart';

/// AgentChatBar — Floating, draggable, compressible chat widget.
/// Mirrors react-native-agentic-ai's AgentChatBar component fully:
/// - FAB (compressed) mode with drag support
/// - Expanded panel with drag handle + minimize button
/// - Result bubble (success/error) with dismiss
/// - Text input row with send button + loading dots
/// - Keyboard offset handling
class AgentChatBar extends StatefulWidget {
  final void Function(String) onSend;
  final bool isThinking;
  final ExecutionResult? lastResult;
  final String language;
  final VoidCallback? onDismiss;
  final VoidCallback? onCancel;
  final AgentChatBarTheme? theme;

  const AgentChatBar({
    super.key,
    required this.onSend,
    required this.isThinking,
    this.lastResult,
    this.language = 'en',
    this.onDismiss,
    this.onCancel,
    this.theme,
  });

  @override
  State<AgentChatBar> createState() => _AgentChatBarState();
}

class _AgentChatBarState extends State<AgentChatBar> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  final TextEditingController _textController = TextEditingController();
  late Offset _position;
  bool _initialized = false;
  double _keyboardOffset = 0;

  // Default colors (matching RN exactly)
  static const _bg = Color(0xF21A1A2E);
  static const _accent = Color(0xFF7B68EE);

  Color get _primaryColor => widget.theme?.primaryColor ?? _accent;
  Color get _backgroundColor => widget.theme?.backgroundColor ?? _bg;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      _position = Offset(size.width - 80, size.height - 200);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !widget.isThinking) {
      widget.onSend(text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    _keyboardOffset = mediaQuery.viewInsets.bottom;

    return Positioned(
      left: _isExpanded
          ? (MediaQuery.of(context).size.width - 340) / 2
          : _position.dx.clamp(0, MediaQuery.of(context).size.width - 70),
      top: (_isExpanded
              ? _position.dy.clamp(100, MediaQuery.of(context).size.height - 400)
              : _position.dy.clamp(0, MediaQuery.of(context).size.height - 80)) -
          _keyboardOffset,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(
                  0, MediaQuery.of(context).size.width - (_isExpanded ? 340 : 70)),
              (_position.dy + details.delta.dy).clamp(
                  0, MediaQuery.of(context).size.height - (_isExpanded ? 300 : 80)),
            );
          });
        },
        // Material wraps everything so TextField and InkWell work
        // even when rendered above MaterialApp in the widget tree.
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _isExpanded ? _buildExpanded() : _buildFab(),
          ),
        ),
      ),
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────

  Widget _buildFab() {
    return GestureDetector(
      key: const ValueKey('fab'),
      onTap: () => setState(() => _isExpanded = true),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.isThinking
            ? _LoadingDots(color: widget.theme?.textColor ?? Colors.white)
            : const _AIBadge(),
      ),
    );
  }

  // ─── Expanded Panel ───────────────────────────────────────────

  Widget _buildExpanded() {
    final isArabic = widget.language == 'ar';
    return Container(
      key: const ValueKey('expanded'),
      width: 340,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          if (widget.lastResult != null) _buildResultBubble(isArabic),
          _buildTextInputRow(isArabic),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Row(
      children: [
        const Expanded(
          child: Center(
            child: _DragGrip(),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _isExpanded = false),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              '—',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultBubble(bool isArabic) {
    final result = widget.lastResult!;
    final isSuccess = result.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess
            ? const Color(0x3328A745) // rgba(40, 167, 69, 0.2)
            : const Color(0x33DC3545), // rgba(220, 53, 69, 0.2)
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            // maxHeight: 200 — matches RN's resultScroll maxHeight
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  result.message.trim(),
                  style: TextStyle(
                    color: widget.theme?.textColor ?? Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
              ),
            ),
          ),
          if (widget.onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onDismiss,
              child: Icon(
                Icons.close,
                size: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextInputRow(bool isArabic) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            // CupertinoTextField has zero Material/Overlay dependency —
            // safe to render above MaterialApp in the widget tree.
            child: CupertinoTextField(
              controller: _textController,
              enabled: !widget.isThinking,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              onSubmitted: (_) => _handleSend(),
              textInputAction: TextInputAction.send,
              style: TextStyle(
                color: widget.theme?.textColor ?? Colors.white,
                fontSize: 16,
              ),
              placeholder: isArabic ? 'اكتب طلبك...' : 'Ask AI...',
              placeholderStyle: TextStyle(
                color: (widget.theme?.textColor ?? Colors.white).withValues(alpha: 0.4),
                fontSize: 16,
              ),
              decoration: null, // remove default iOS border — we style the Container
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: widget.isThinking ? widget.onCancel : _handleSend,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.isThinking
                  ? Colors.red.withValues(alpha: 0.6)
                  : _primaryColor.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: widget.isThinking
                ? const Icon(Icons.stop, size: 18, color: Colors.white)
                : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────

class _DragGrip extends StatelessWidget {
  const _DragGrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _AIBadge extends StatelessWidget {
  const _AIBadge();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '✦',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  final Color color;
  const _LoadingDots({required this.color});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, ___) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i / 3;
              final t = (_controller.value - delay).clamp(0.0, 1.0);
              final opacity = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─── Theme ────────────────────────────────────────────────────

class AgentChatBarTheme {
  final Color? primaryColor;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? successColor;
  final Color? errorColor;

  const AgentChatBarTheme({
    this.primaryColor,
    this.backgroundColor,
    this.textColor,
    this.successColor,
    this.errorColor,
  });
}
