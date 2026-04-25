import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  group('PickerTool', () {
    late PickerTool tool;
    late List<InteractiveElement> testElements;
    late GlobalKey testKey;
    late BuildContext testContext;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tool = PickerTool();
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
          type: ElementType.picker,
          label: 'Country Picker',
          element: Element(const SizedBox()).renderObject,
        ),
      ];
    });

    test('definition has correct name and description', () {
      expect(tool.definition.name, 'select_picker');
      expect(tool.definition.description, contains('picker'));
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

      final result = tool.execute({'index': 999, 'value': 'USA'}, context);
      await expectLater(
        result,
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('not found'),
        )),
      );
    });

    test('throws for empty value', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      expect(
        () => tool.execute({'index': 0, 'value': ''}, context),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('cannot be empty'),
        )),
      );

      expect(
        () => tool.execute({'index': 0, 'value': '   '}, context),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('cannot be empty'),
        )),
      );
    });

    test('accepts valid value parameter', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      // Valid value should not throw parameter validation errors
      try {
        await tool.execute({'index': 0, 'value': 'United States'}, context);
      } catch (e) {
        expect(e.toString(), isNot(contains('cannot be empty')));
      }
    });
  });
}
