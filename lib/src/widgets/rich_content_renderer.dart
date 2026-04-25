import 'package:flutter/material.dart';

import '../core/block_registry.dart';
import '../core/types.dart';

class RichContentRenderer extends StatelessWidget {
  final Object? content;
  final BlockPlacement placement;

  const RichContentRenderer({
    super.key,
    required this.content,
    this.placement = BlockPlacement.chat,
  });

  @override
  Widget build(BuildContext context) {
    final nodes = normalizeRichContent(content, richContentToPlainText(content));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: nodes.map((node) {
        if (node is AiTextNode) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(node.text),
          );
        }
        if (node is AiBlockNode) {
          final definition = globalBlockRegistry.get(node.blockType);
          if (definition == null || !definition.allowedPlacements.contains(placement)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: definition.builder(context, node.props),
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}
