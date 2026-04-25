import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  group('DatePickerTool', () {
    late DatePickerTool tool;
    late List<InteractiveElement> testElements;
    late GlobalKey testKey;
    late BuildContext testContext;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tool = DatePickerTool();
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
          type: ElementType.datePicker,
          label: 'Birth Date',
          element: Element(const SizedBox()).renderObject,
        ),
      ];
    });

    test('definition has correct name and description', () {
      expect(tool.definition.name, 'set_date');
      expect(tool.definition.description, contains('date'));
      expect(tool.definition.description, contains('ISO 8601'));
      expect(tool.definition.parameters['index'], isNotNull);
      expect(tool.definition.parameters['date'], isNotNull);
    });

    test('requires index and date parameters', () async {
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

      final result = tool.execute({'index': 999, 'date': '2025-03-25'}, context);
      await expectLater(
        result,
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('not found'),
        )),
      );
    });

    test('accepts valid ISO 8601 date formats', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      final validDates = [
        '2025-03-25',
        '2025-03-25T14:30:00',
        '2025-03-25T14:30:00Z',
        '2025-12-31',
      ];

      for (final date in validDates) {
        try {
          await tool.execute({'index': 0, 'date': date}, context);
        } catch (e) {
          // Should not be a format error
          expect(e.toString(), isNot(contains('Invalid date format')));
        }
      }
    });

    test('throws for invalid date formats', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      final invalidDates = [
        'not-a-date',
        '2025-13-01', // Invalid month
        '2025-02-30', // Invalid day
        '25-03-2025', // Wrong format
      ];

      for (final date in invalidDates) {
        expect(
          () => tool.execute({'index': 0, 'date': date}, context),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid date format'),
          )),
        );
      }
    });

    test('throws for empty date string', () async {
      final context = ToolContext(
        rootContext: testContext,
        lastElements: testElements,
      );

      expect(
        () => tool.execute({'index': 0, 'date': ''}, context),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('cannot be empty'),
        )),
      );
    });
  });
}
