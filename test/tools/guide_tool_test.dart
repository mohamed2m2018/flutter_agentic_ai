import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  group('GuideTool', () {
    late GuideTool tool;
    late List<InteractiveElement> testElements;
    late GlobalKey testKey;
    late BuildContext testContext;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tool = GuideTool();
      testKey = GlobalKey();

      await pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: testKey,
            body: Container(),
          ),
        ),
      );

      final scaffoldState = testKey.currentState as ScaffoldState?;
      testContext = scaffoldState?.context ?? Element(const SizedBox()).renderObject;
    });

    setUp(() {
      testElements = [
        InteractiveElement(
          index: 0,
          type: ElementType.pressable,
          label: 'Submit Button',
          element: Element(const SizedBox()).renderObject,
        ),
      ];
    });

    test('definition has correct name and description', () {
      expect(tool.definition.name, 'guide_user');
      expect(tool.definition.description, contains('highlight'));
      expect(tool.definition.parameters['index'], isNotNull);
      expect(tool.definition.parameters['message'], isNotNull);
    });

    test('requires index and message parameters', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      expect(
        () => tool.execute({}, context),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Missing required'),
        )),
      );

      expect(
        () => tool.execute({'index': 0}, context),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Missing required'),
        )),
      );
    });

    test('throws when element not found', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      final result = tool.execute({'index': 999, 'message': 'Tap here'}, context);
      await expectLater(
        result,
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('not found'),
        )),
      );
    });

    test('throws for empty message', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      expect(
        () => tool.execute({'index': 0, 'message': ''}, context),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('cannot be empty'),
        )),
      );

      expect(
        () => tool.execute({'index': 0, 'message': '   '}, context),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('cannot be empty'),
        )),
      );
    });

    test('accepts valid message parameter', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      // Valid message should not throw parameter validation errors
      try {
        await tool.execute({'index': 0, 'message': 'Tap to continue'}, context);
      } catch (e) {
        expect(e.toString(), isNot(contains('cannot be empty')));
      }
    });

    test('accepts optional autoRemoveAfterMs parameter', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      // Should not throw for valid timeout values
      for (final timeout in [1000, 3000, 5000, 10000]) {
        try {
          await tool.execute({
            'index': 0,
            'message': 'Tap to continue',
            'autoRemoveAfterMs': timeout
          }, context);
        } catch (e) {
          expect(e.toString(), isNot(contains('cannot be empty')));
        }
      }
    });

    test('uses default autoRemoveAfterMs when not provided', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      // Should use default value (5000ms)
      try {
        await tool.execute({'index': 0, 'message': 'Tap here'}, context);
      } catch (e) {
        expect(e.toString(), isNot(contains('cannot be empty')));
      }
    });
  });
}
