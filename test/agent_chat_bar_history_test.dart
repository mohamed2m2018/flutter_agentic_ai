import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  testWidgets('history panel shows conversations and new conversation action', (
    tester,
  ) async {
    var selectedConversationId = '';
    var startedNewConversation = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AgentChatBar(
                onSend: (_) {},
                isThinking: false,
                conversations: const [
                  ConversationSummary(
                    id: 'conv_1',
                    title: 'Disable push notifications',
                    preview: 'I can help with that.',
                    messageCount: 2,
                    createdAt: 1,
                    updatedAt: 1,
                  ),
                ],
                onConversationSelect: (conversationId) {
                  selectedConversationId = conversationId;
                },
                onNewConversation: () {
                  startedNewConversation = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    final scaffoldSize = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(
      Offset(scaffoldSize.width - 50, scaffoldSize.height - 170),
    );
    await tester.pumpAndSettle();

    expect(find.text('History'), findsNothing);
    await tester.tap(find.byIcon(Icons.history_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Disable push notifications'), findsOneWidget);

    await tester.tap(find.text('Disable push notifications'));
    await tester.pumpAndSettle();
    expect(selectedConversationId, 'conv_1');

    await tester.tap(find.byIcon(Icons.history_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(startedNewConversation, isTrue);
  });

  testWidgets('text input stays answerable while awaiting a freeform reply', (
    tester,
  ) async {
    String sentMessage = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AgentChatBar(
                onSend: (value) {
                  sentMessage = value;
                },
                isThinking: true,
                awaitingUserResponse: true,
                messages: [
                  AiMessage(
                    role: 'assistant',
                    content: 'Hi there! How can I help you today?',
                    previewText: 'Hi there! How can I help you today?',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final scaffoldSize = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(
      Offset(scaffoldSize.width - 50, scaffoldSize.height - 170),
    );
    await tester.pumpAndSettle();

    final textField = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(textField.enabled, isTrue);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsNothing);

    await tester.enterText(find.byType(CupertinoTextField), 'add blue coffee machine to cart');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sentMessage, 'add blue coffee machine to cart');
  });
}
