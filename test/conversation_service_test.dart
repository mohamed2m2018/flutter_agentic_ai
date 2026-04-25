import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('conversation service round-trips rich assistant content', () async {
    SharedPreferences.setMockInitialValues({});

    const key = 'roundtrip';
    final messages = [
      AiMessage(role: 'user', content: 'Show me pricing'),
      AiMessage(
        role: 'assistant',
        content: [
          const AiTextNode('Here is the current plan.'),
          const AiBlockNode(
            id: 'product-1',
            blockType: 'ProductCard',
            props: {'title': 'Starter', 'price': '\$29'},
          ),
        ],
      ),
    ];

    await ConversationService.saveMessages(key: key, messages: messages);
    final restored = await ConversationService.loadMessages(key);

    expect(restored, hasLength(2));
    expect(restored.first.role, 'user');
    expect(restored.first.previewText, 'Show me pricing');
    expect(restored.last.role, 'assistant');
    expect(restored.last.content, isA<List<AiRichNode>>());

    final richContent = restored.last.content as List<AiRichNode>;
    expect(richContent.first, isA<AiTextNode>());
    expect(richContent.last, isA<AiBlockNode>());
    expect(restored.last.previewText, 'Here is the current plan.');
  });

  test('conversation draft preserves active conversation id', () async {
    SharedPreferences.setMockInitialValues({});

    const key = 'draft';
    final draft = ConversationDraft(
      activeConversationId: 'conv_123',
      messages: [
        AiMessage(role: 'user', content: 'Hello again'),
        AiMessage(role: 'assistant', content: 'Welcome back'),
      ],
    );

    await ConversationService.saveDraft(key: key, draft: draft);
    final restored = await ConversationService.loadDraft(key);

    expect(restored.activeConversationId, 'conv_123');
    expect(restored.messages, hasLength(2));
    expect(restored.messages.first.previewText, 'Hello again');
    expect(restored.messages.last.previewText, 'Welcome back');
  });
}
