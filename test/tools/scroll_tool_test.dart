import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';
import 'package:mobileai_flutter/src/tools/scroll_tool.dart';
import 'package:mobileai_flutter/src/tools/types.dart';

void main() {
  testWidgets(
    'ScrollTool resolves descendant ScrollableState for ListView wrappers',
    (tester) async {
      final tool = ScrollTool();
      final listKey = GlobalKey();
      final scaffoldKey = GlobalKey();
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            body: ListView.builder(
              key: listKey,
              controller: controller,
              itemCount: 60,
              itemBuilder: (context, index) => SizedBox(
                height: 80,
                child: Text('Row $index'),
              ),
            ),
          ),
        ),
      );

      final listElement = listKey.currentContext! as Element;
      final rootContext = scaffoldKey.currentContext!;

      controller.jumpTo(controller.position.maxScrollExtent);

      final result = await tool.execute(
        {
          'direction': 'down',
          'amount': 'toEnd',
          'containerIndex': 0,
        },
        ToolContext(
          rootContext: rootContext,
          config: AgentConfig(),
          lastElements: [
            InteractiveElement(
              index: 1,
              type: ElementType.scrollable,
              label: 'Scrollable content',
              element: listElement,
              properties: const {
                'role': 'scrollable',
                'enabled': true,
              },
            ),
          ],
          getCurrentScreenName: () => '/search',
          getRouteNames: () => ['/search'],
        ),
      );

      expect(result, contains('Already at the down edge'));
      expect(controller.offset, controller.position.maxScrollExtent);
    },
  );

  testWidgets(
    'ScrollTool prefers a vertical scroll area by default when containerIndex is omitted',
    (tester) async {
      final tool = ScrollTool();
      final horizontalKey = GlobalKey();
      final verticalKey = GlobalKey();
      final scaffoldKey = GlobalKey();
      final horizontalController = ScrollController();
      final verticalController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            body: Column(
              children: [
                SizedBox(
                  height: 72,
                  child: SingleChildScrollView(
                    key: horizontalKey,
                    controller: horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        12,
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Chip(label: Text('Chip $index')),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    key: verticalKey,
                    controller: verticalController,
                    itemCount: 40,
                    itemBuilder: (context, index) => SizedBox(
                      height: 80,
                      child: Text('Row $index'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final horizontalElement = horizontalKey.currentContext! as Element;
      final verticalElement = verticalKey.currentContext! as Element;

      final result = await tool.execute(
        {
          'direction': 'down',
          'amount': 'page',
        },
        ToolContext(
          rootContext: scaffoldKey.currentContext!,
          config: AgentConfig(),
          lastElements: [
            InteractiveElement(
              index: 1,
              type: ElementType.scrollable,
              label: 'Horizontal scroll area',
              element: horizontalElement,
              properties: const {
                'role': 'scrollable',
                'enabled': true,
                'orientation': 'horizontal',
              },
            ),
            InteractiveElement(
              index: 2,
              type: ElementType.scrollable,
              label: 'Vertical scroll area',
              element: verticalElement,
              properties: const {
                'role': 'scrollable',
                'enabled': true,
                'orientation': 'vertical',
              },
            ),
          ],
          getCurrentScreenName: () => '/search',
          getRouteNames: () => ['/search'],
        ),
      );

      expect(result, contains('Scrolled down by page successfully.'));
      expect(verticalController.offset, greaterThan(0));
      expect(horizontalController.offset, 0);
    },
  );
}
