import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  group('LongPressTool', () {
    late LongPressTool tool;
    late List<InteractiveElement> testElements;
    late GlobalKey testKey;
    late BuildContext testContext;

    setUpAll(() async {
      // Initialize test environment
      TestWidgetsFlutterBinding.ensureInitialized();
      tool = LongPressTool();
      testKey = GlobalKey();

      // Create a test widget tree to get a valid BuildContext
      await pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: testKey,
            body: Container(),
          ),
        ),
      );

      // Find the Scaffold's context
      final scaffoldState = testKey.currentState as ScaffoldState?;
      testContext = scaffoldState?.context ?? Element(const SizedBox()).renderObject;
    });

    setUp(() {
      // Reset test elements for each test
      testElements = [
        InteractiveElement(
          index: 0,
          type: ElementType.pressable,
          label: 'Test Button',
          element: Element(const SizedBox()).renderObject,
        ),
      ];
    });

    test('definition has correct name and description', () {
      expect(tool.definition.name, 'long_press');
      expect(tool.definition.description, contains('long-press'));
      expect(tool.definition.parameters['index'], isNotNull);
    });

    test('requires index parameter', () async {
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
    });

    test('throws when element not found', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      final result = tool.execute({'index': 999}, context);
      await expectLater(
        result,
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('not found'),
        )),
      );
    });

    test('accepts valid index parameter', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      // This should not throw a parameter validation error
      // (may fail execution due to lack of actual widget)
      try {
        await tool.execute({'index': 0}, context);
      } catch (e) {
        expect(e.toString(), isNot(contains('Missing required')));
      }
    });
  });
}
