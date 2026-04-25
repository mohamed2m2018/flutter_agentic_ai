import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobileai_flutter/src/core/types.dart';
import 'package:mobileai_flutter/src/providers/gemini_provider.dart';

void main() {
  test('Gemini proxy parser falls back gracefully when content parts are missing', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'candidates': <Map<String, dynamic>>[
            <String, dynamic>{
              'finishReason': 'MALFORMED_FUNCTION_CALL',
            },
          ],
        }),
        200,
        headers: const <String, String>{
          'content-type': 'application/json',
        },
      );
    });

    final provider = GeminiProvider(
      proxyUrl: 'http://localhost:3001/api/v1/hosted-proxy/text',
      httpClient: mockClient,
    );

    final result = await provider.generateContent(
      systemPrompt: 'system',
      userMessage: 'user',
      tools: <ToolDefinition>[
        ToolDefinition(
          name: 'tap',
          description: 'Tap a button.',
          parameters: <String, ToolParam>{
            'index': ToolParam(
              type: 'integer',
              description: 'Interactive element index.',
              required: true,
            ),
          },
          handler: (_) async => 'tap',
        ),
      ],
      history: const <AgentStep>[],
    );

    expect(result.actionName, 'done');
    expect(result.actionParams?['success'], isFalse);
    expect(
      result.actionParams?['text'],
      'The AI response was incomplete. Please try again.',
    );
  });
}
