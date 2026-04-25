import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  group('SliderTool', () {
    late SliderTool tool;
    late List<InteractiveElement> testElements;
    late GlobalKey testKey;
    late BuildContext testContext;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tool = SliderTool();
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
          type: ElementType.slider,
          label: 'Volume Slider',
          element: Element(const SizedBox()).renderObject,
        ),
      ];
    });

    test('definition has correct name and description', () {
      expect(tool.definition.name, 'adjust_slider');
      expect(tool.definition.description, contains('slider'));
      expect(tool.definition.parameters['index'], isNotNull);
      expect(tool.definition.parameters['value'], isNotNull);
    });

    test('requires index and value parameters', () async {
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

      final result = tool.execute({'index': 999, 'value': 0.5}, context);
      await expectLater(
        result,
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('not found'),
        )),
      );
    });

    test('throws for invalid value range', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      expect(
        () => tool.execute({'index': 0, 'value': 1.5}, context),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('between 0.0 and 1.0'),
        )),
      );

      expect(
        () => tool.execute({'index': 0, 'value': -0.1}, context),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('between 0.0 and 1.0'),
        )),
      );
    });

    test('accepts valid normalized value', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      // Valid values should not throw parameter validation errors
      for (final value in [0.0, 0.5, 1.0]) {
        try {
          await tool.execute({'index': 0, 'value': value}, context);
        } catch (e) {
          expect(e.toString(), isNot(contains('between 0.0 and 1.0')));
        }
      }
    });
  });
}
