import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  test('normalizes rich content into preview text', () {
    final message = AiMessage(
      role: 'assistant',
      content: [
        const AiTextNode('Hello'),
        const AiBlockNode(
          id: 'product-1',
          blockType: 'ProductCard',
          props: {'title': 'Chicken'},
        ),
      ],
    );

    expect(message.previewText, 'Hello');
  });

  test('normalizeRichContent parses strict JSON rich reply strings', () {
    final nodes = normalizeRichContent(
      '[{"type":"text","content":"Hello"},{"type":"block","blockType":"ProductCard","props":{"title":"Cotton T-Shirt","price":"\$19.99"}}]',
    );

    expect(nodes, hasLength(2));
    expect(nodes.first, isA<AiTextNode>());
    expect((nodes.first as AiTextNode).text, 'Hello');
    expect(nodes.last, isA<AiBlockNode>());
    expect((nodes.last as AiBlockNode).blockType, 'ProductCard');
    expect((nodes.last as AiBlockNode).props['title'], 'Cotton T-Shirt');
  });

  test('normalizeRichContent salvages JS-like rich reply strings', () {
    final nodes = normalizeRichContent(
      "[{type: text, content: 'Yes, I found a Cotton T-Shirt for \$19.99 with a 4.5 rating.'}]",
    );

    expect(nodes, hasLength(1));
    expect(nodes.first, isA<AiTextNode>());
    expect(
      (nodes.first as AiTextNode).text,
      'Yes, I found a Cotton T-Shirt for \$19.99 with a 4.5 rating.',
    );
  });

  test('normalizeRichContent preserves block fields provided at top level', () {
    final nodes = normalizeRichContent(
      '[{"type":"block","blockType":"ComparisonCard","title":"Fashion comparison","items":[{"title":"Cotton T-Shirt","price":"\$19.99","summary":"Soft organic cotton basic tee."}]}]',
    );

    expect(nodes, hasLength(1));
    expect(nodes.first, isA<AiBlockNode>());
    final block = nodes.first as AiBlockNode;
    expect(block.blockType, 'ComparisonCard');
    expect(block.props['title'], 'Fashion comparison');
    expect(block.props['items'], isA<List<dynamic>>());
    expect((block.props['items'] as List<dynamic>).first, isA<Map<String, dynamic>>());
  });

  testWidgets(
    'RichContentRenderer renders ComparisonCard content from top-level block fields',
    (tester) async {
      registerBuiltInBlocks();

      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: RichContentRenderer(
              content:
                  '[{"type":"text","content":"Here are some fashion items I found for comparison:"},{"type":"block","blockType":"ComparisonCard","title":"Fashion comparison","items":[{"title":"Cotton T-Shirt","price":"\$19.99","summary":"Soft organic cotton basic tee.","badges":["Best value"]},{"name":"Running Shoes","price":"\$89.99","description":"Lightweight trainers for daily wear.","badges":["Top rated"]}]}]',
            ),
          ),
        ),
      );

      expect(find.text('Here are some fashion items I found for comparison:'), findsOneWidget);
      expect(find.text('Fashion comparison'), findsOneWidget);
      expect(find.text('Cotton T-Shirt'), findsOneWidget);
      expect(find.text('\$19.99'), findsOneWidget);
      expect(find.text('Soft organic cotton basic tee.'), findsOneWidget);
      expect(find.text('Running Shoes'), findsOneWidget);
      expect(find.text('\$89.99'), findsOneWidget);
      expect(find.text('Lightweight trainers for daily wear.'), findsOneWidget);
    },
  );
}
