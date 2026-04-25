import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('AIAgent starts a fresh conversation on app launch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      '@mobileai_flutter_conversation_launch_test': '{"activeConversationId":"conv_123","messages":[{"role":"user","content":"old question","previewText":"old question","timestamp":1}]}',
    });

    final provider = _RecordingProvider();
    AIAgentController? controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AIAgent(
            provider: provider,
            consent: const AIConsentConfig(required: false, persist: false),
            conversationPersistenceKey: 'launch_test',
            child: Builder(
              builder: (context) {
                controller = context.ai;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(controller, isNotNull);
    expect(controller!.messages, isEmpty);

    final draft = await ConversationService.loadDraft('launch_test');
    expect(draft.activeConversationId, isNull);
    expect(draft.messages, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('AIAgent forwards recent chat history into follow-up runtime calls', (
    tester,
  ) async {
    final provider = _RecordingProvider();
    AIAgentController? controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AIAgent(
            provider: provider,
            consent: const AIConsentConfig(required: false, persist: false),
            child: Builder(
              builder: (context) {
                controller = context.ai;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(controller, isNotNull);

    await controller!.send('add blue coffee machine to cart');
    await tester.pumpAndSettle();

    await controller!.send('is it blue?');
    await tester.pumpAndSettle();

    expect(provider.userMessages, hasLength(2));
    final secondUserMessage = provider.userMessages.last;
    expect(secondUserMessage, contains('is it blue?'));
    expect(secondUserMessage, contains('<chat_history>'));
    expect(
      secondUserMessage,
      contains('[user]: add blue coffee machine to cart'),
    );
    expect(
      secondUserMessage,
      contains('[assistant]: Done! The Smart Coffee Maker has been added to your cart for \$149.00.'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}

class _RecordingProvider implements AiProvider {
  final List<String> userMessages = <String>[];

  @override
  Future<ProviderResult> generateContent({
    required String systemPrompt,
    required String userMessage,
    required List<ToolDefinition> tools,
    required List<AgentStep> history,
    String? screenshotBase64,
  }) async {
    userMessages.add(userMessage);
    if (userMessages.length == 1) {
      return ProviderResult(
        actionName: 'done',
        actionParams: <String, dynamic>{
          'success': true,
          'text':
              'Done! The Smart Coffee Maker has been added to your cart for \$149.00.',
        },
      );
    }
    return ProviderResult(
      actionName: 'done',
      actionParams: <String, dynamic>{
        'success': true,
        'text': 'Yes, it is blue.',
      },
    );
  }
}
