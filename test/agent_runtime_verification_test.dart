import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  testWidgets(
    'AgentRuntime blocks repeating a verified critical action on the same screen',
    (tester) async {
      final rootKey = GlobalKey();
      final provider = _SequenceProvider(<ProviderResult>[
        ProviderResult(
          actionName: 'tap',
          actionParams: <String, dynamic>{'index': 1},
        ),
        ProviderResult(
          actionName: 'tap',
          actionParams: <String, dynamic>{'index': 1},
        ),
        ProviderResult(
          actionName: 'done',
          actionParams: <String, dynamic>{
            'success': true,
            'text': 'Added successfully.',
          },
        ),
      ]);

      var addCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: KeyedSubtree(
              key: rootKey,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            addCount += 1;
                          });
                        },
                        child: const Text('Add to Cart'),
                      ),
                      if (addCount > 0) const Text('Added to cart!'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      final runtime = AgentRuntime(
        provider: provider,
        config: AgentConfig(
          maxSteps: 3,
          gracePeriod: Duration(milliseconds: 10),
          interactionMode: AppInteractionMode.autopilot,
        ),
        rootKey: rootKey,
      );

      final future = runtime.execute('add the item to the cart');
      for (var index = 0; index < 30; index += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final result = await future;

      expect(result.success, isTrue);
      expect(addCount, 1);
      expect(
        result.steps.any(
          (step) =>
              (step.result ?? '').contains(
                'already appears completed on the current screen',
              ),
        ),
        isTrue,
      );

      runtime.dispose();
      await tester.pump(const Duration(seconds: 2));
    },
  );
}

class _SequenceProvider implements AiProvider {
  _SequenceProvider(this._responses);

  final List<ProviderResult> _responses;
  int _index = 0;

  @override
  Future<ProviderResult> generateContent({
    required String systemPrompt,
    required String userMessage,
    required List<ToolDefinition> tools,
    required List<AgentStep> history,
    String? screenshotBase64,
  }) async {
    if (tools.any((tool) => tool.name == 'report_verification')) {
      return ProviderResult(
        actionName: 'report_verification',
        actionParams: const <String, dynamic>{
          'status': 'success',
          'failureKind': 'controllable',
          'evidence': 'The current screen shows a successful completion message.',
        },
      );
    }
    if (_index >= _responses.length) {
      return ProviderResult(
        actionName: 'done',
        actionParams: const <String, dynamic>{
          'success': false,
          'text': 'No more responses configured.',
        },
      );
    }
    return _responses[_index++];
  }
}
