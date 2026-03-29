import 'package:flutter/widgets.dart';
import '../core/types.dart';
import '../core/zone_registry.dart';

class AiZone extends StatefulWidget {
  final String id;
  final bool allowHighlight;
  final bool allowGuide;
  final bool allowSimplify;
  final String? description;
  final Widget child;

  const AiZone({
    super.key,
    required this.id,
    this.allowHighlight = true,
    this.allowGuide = true,
    this.allowSimplify = false,
    this.description,
    required this.child,
  });

  @override
  State<AiZone> createState() => _AiZoneState();
}

class _AiZoneState extends State<AiZone> {
  final GlobalKey _zoneKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(AiZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      globalZoneRegistry.unregister(oldWidget.id);
      _register();
    } else {
      _register();
    }
  }

  @override
  void dispose() {
    globalZoneRegistry.unregister(widget.id);
    super.dispose();
  }

  void _register() {
    globalZoneRegistry.register(
      AiZoneConfig(
        id: widget.id,
        allowHighlight: widget.allowHighlight,
        allowGuide: widget.allowGuide,
        allowSimplify: widget.allowSimplify,
        description: widget.description,
      ),
      _zoneKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _zoneKey,
      child: widget.child,
    );
  }
}
