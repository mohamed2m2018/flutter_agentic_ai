import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  test('voice proxy connection includes Gemini Live API path', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final pathCompleter = Completer<String>();
    final messageCompleter = Completer<Map<String, dynamic>>();

    unawaited(
      server.first.then((request) async {
        pathCompleter.complete(request.uri.path);
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((message) {
          if (!messageCompleter.isCompleted) {
            messageCompleter.complete(
              jsonDecode(message as String) as Map<String, dynamic>,
            );
          }
          socket.add(jsonEncode({'setupComplete': {}}));
        });
      }),
    );

    final service = VoiceService(
      VoiceServiceConfig(
        proxyUrl:
            'http://${InternetAddress.loopbackIPv4.host}:${server.port}/ws/hosted-proxy/voice',
        proxyHeaders: const {'Authorization': 'Bearer test-key'},
      ),
    );

    await service.connect(const VoiceServiceCallbacks());

    expect(
      await pathCompleter.future,
      '/ws/hosted-proxy/voice/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent',
    );
    expect(await messageCompleter.future, contains('setup'));

    await service.disconnect();
    await server.close(force: true);
  });

  test('screen context is sent as client content', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final messages = <Map<String, dynamic>>[];
    final secondMessage = Completer<Map<String, dynamic>>();

    unawaited(
      server.first.then((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((message) {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          messages.add(decoded);
          if (messages.length == 1) {
            socket.add(jsonEncode({'setupComplete': {}}));
          } else if (messages.length == 2 && !secondMessage.isCompleted) {
            secondMessage.complete(decoded);
          }
        });
      }),
    );

    final service = VoiceService(
      VoiceServiceConfig(
        proxyUrl:
            'http://${InternetAddress.loopbackIPv4.host}:${server.port}/ws/hosted-proxy/voice',
        proxyHeaders: const {'Authorization': 'Bearer test-key'},
      ),
    );

    await service.connect(const VoiceServiceCallbacks());
    await service.sendScreenContext('<screen>...</screen>');

    final payload = await secondMessage.future;
    expect(payload['clientContent'], isNotNull);
    expect(payload['clientContent']['turnComplete'], isTrue);
    expect(
      payload['clientContent']['turns'][0]['parts'][0]['text'],
      '<screen>...</screen>',
    );

    await service.disconnect();
    await server.close(force: true);
  });

  test('live session handles audio, tool call, and function response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final audioCompleter = Completer<String>();
    final transcriptCompleter = Completer<String>();
    final toolCompleter = Completer<VoiceToolCall>();
    final functionResponseCompleter = Completer<Map<String, dynamic>>();

    unawaited(
      server.first.then((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((message) {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          if (decoded.containsKey('setup')) {
            socket.add(jsonEncode({'setupComplete': {}}));
            socket.add(
              jsonEncode({
                'serverContent': {
                  'modelTurn': {
                    'parts': [
                      {
                        'inlineData': {
                          'data': 'AQIDBA==',
                          'mimeType': 'audio/pcm;rate=24000',
                        },
                      },
                    ],
                  },
                  'outputTranscription': {'text': 'Ready'},
                },
              }),
            );
            socket.add(
              jsonEncode({
                'toolCall': {
                  'functionCalls': [
                    {
                      'name': 'navigate',
                      'id': 'call-1',
                      'args': {'screen': 'profile'},
                    },
                  ],
                },
              }),
            );
          }

          final toolResponse = decoded['toolResponse'];
          if (toolResponse is Map<String, dynamic> &&
              !functionResponseCompleter.isCompleted) {
            functionResponseCompleter.complete(decoded);
          }
        });
      }),
    );

    final service = VoiceService(
      VoiceServiceConfig(
        proxyUrl:
            'http://${InternetAddress.loopbackIPv4.host}:${server.port}/ws/hosted-proxy/voice',
        proxyHeaders: const {'Authorization': 'Bearer test-key'},
      ),
    );

    await service.connect(
      VoiceServiceCallbacks(
        onAudioResponse: audioCompleter.complete,
        onTranscript: (text, isFinal, role) {
          if (role == 'model' && !transcriptCompleter.isCompleted) {
            transcriptCompleter.complete(text);
          }
        },
        onToolCall: (toolCall) {
          toolCompleter.complete(toolCall);
          unawaited(
            service.sendFunctionResponse(toolCall.name, toolCall.id, {
              'result': 'Navigated to profile',
            }),
          );
        },
      ),
    );

    expect(await audioCompleter.future, 'AQIDBA==');
    expect(await transcriptCompleter.future, 'Ready');

    final toolCall = await toolCompleter.future;
    expect(toolCall.name, 'navigate');
    expect(toolCall.id, 'call-1');
    expect(toolCall.args['screen'], 'profile');

    final response = await functionResponseCompleter.future;
    expect(
      response['toolResponse']['functionResponses'][0]['response']['result'],
      'Navigated to profile',
    );

    await service.disconnect();
    await server.close(force: true);
  });

  test('input transcript is emitted before same-message tool call', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final events = <String>[];
    final toolCompleter = Completer<void>();

    unawaited(
      server.first.then((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((message) {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          if (decoded.containsKey('setup')) {
            socket.add(jsonEncode({'setupComplete': {}}));
            socket.add(
              jsonEncode({
                'serverContent': {
                  'inputTranscription': {'text': 'go home', 'finished': true},
                },
                'toolCall': {
                  'functionCalls': [
                    {
                      'name': 'navigate',
                      'id': 'call-home',
                      'args': {'screen': 'home'},
                    },
                  ],
                },
              }),
            );
          }
        });
      }),
    );

    final service = VoiceService(
      VoiceServiceConfig(
        proxyUrl:
            'http://${InternetAddress.loopbackIPv4.host}:${server.port}/ws/hosted-proxy/voice',
        proxyHeaders: const {'Authorization': 'Bearer test-key'},
      ),
    );

    await service.connect(
      VoiceServiceCallbacks(
        onTranscript: (text, isFinal, role) {
          if (role == 'user') events.add('transcript:$text');
        },
        onToolCall: (toolCall) {
          events.add('tool:${toolCall.name}');
          toolCompleter.complete();
        },
      ),
    );

    await toolCompleter.future;
    expect(events, ['transcript:go home', 'tool:navigate']);

    await service.disconnect();
    await server.close(force: true);
  });
}
