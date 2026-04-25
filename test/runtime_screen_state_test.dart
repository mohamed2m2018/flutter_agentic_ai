import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  tearDown(() {
    dataRegistry.clear();
  });

  testWidgets('runtime screen state includes enriched screens and chains', (
    tester,
  ) async {
    final rootKey = GlobalKey();
    dataRegistry.register(
      const DataDefinition(
        name: 'catalog',
        description:
            'Structured product catalog with pricing and availability.',
        schema: <String, DataFieldDef>{
          'name': DataFieldDef(type: 'string', description: 'Product name'),
          'price': DataFieldDef(type: 'number', description: 'Product price'),
        },
        handler: _noopDataHandler,
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: KeyedSubtree(key: rootKey, child: const SizedBox.shrink()),
      ),
    );

    final runtime = AgentRuntime(
      provider: _FakeProvider(),
      config: AgentConfig(
        screenMap: ScreenMap(
          generatedAt: '2026-04-20T00:00:00Z',
          framework: 'go_router',
          screens: <String, ScreenMapEntry>{
            '/home': ScreenMapEntry(
              title: 'Home',
              description: 'Home feed with category shortcuts.',
              safeDirectNavigation: true,
            ),
            '/profile': ScreenMapEntry(
              title: 'Profile',
              description: 'Profile screen with access to settings.',
              safeDirectNavigation: true,
            ),
            '/profile/settings': ScreenMapEntry(
              title: 'Profile Settings',
              description: 'Profile settings screen with Push Notifications.',
              safeDirectNavigation: false,
            ),
          },
          chains: const <List<String>>[
            <String>['/home', '/profile', '/profile/settings'],
          ],
        ),
      ),
      rootKey: rootKey,
    );

    final screenState = runtime.buildScreenStateText(
      screenName: '/home',
      availableScreens: const <String>[
        '/home',
        '/profile',
        '/profile/settings',
      ],
      elementsText: '[1]<pressable role="button" selected="true">Profile />',
      elements: <InteractiveElement>[
        InteractiveElement(
          index: 1,
          type: ElementType.pressable,
          label: 'Profile',
          properties: <String, dynamic>{
            'role': 'button',
            'selected': true,
            'enabled': true,
          },
        ),
        InteractiveElement(
          index: 2,
          type: ElementType.textInput,
          label: 'Search products...',
          properties: <String, dynamic>{
            'role': 'textbox',
            'value': 'cotton t-shirts',
            'hint': 'Search products...',
          },
        ),
      ],
    );

    expect(screenState, contains('Available Screens:'));
    expect(
      screenState,
      contains(
        '/profile/settings (Profile Settings): Profile settings screen with Push Notifications.',
      ),
    );
    expect(screenState, contains('Navigation Chain Hints:'));
    expect(screenState, contains('/home -> /profile -> /profile/settings'));
    expect(screenState, contains('Active UI State:'));
    expect(screenState, contains('<pressable> Profile | selected="true"'));
    expect(
      screenState,
      contains('<text-input> Search products... | value="cotton t-shirts"'),
    );
    expect(screenState, contains('Available Data Sources:'));
    expect(
      screenState,
      contains(
        '- catalog: Structured product catalog with pricing and availability. Fields: name (string), price (number).',
      ),
    );

    runtime.dispose();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('screen map does not become the live route catalog', (
    tester,
  ) async {
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: KeyedSubtree(key: rootKey, child: const SizedBox.shrink()),
      ),
    );

    final runtime = AgentRuntime(
      provider: _FakeProvider(),
      config: AgentConfig(
        screenMap: ScreenMap(
          generatedAt: '2026-04-20T00:00:00Z',
          framework: 'go_router',
          screens: <String, ScreenMapEntry>{
            '/home': ScreenMapEntry(
              title: 'Home',
              description: 'Home feed with category shortcuts.',
              safeDirectNavigation: true,
            ),
          },
          chains: const <List<String>>[],
        ),
      ),
      rootKey: rootKey,
    );

    final screenContext = runtime.getScreenContext();
    expect(screenContext.availableScreens, isEmpty);

    final screenState = runtime.buildScreenStateText(
      screenName: '/home',
      availableScreens: const <String>[],
      elementsText: '',
    );

    expect(screenState, contains('Available Screens:'));
    expect(screenState, isNot(contains('- /home (Home):')));
    expect(
      screenState,
      contains(
        'Screen Map Hints: generated map provided, but no live route catalog is available.',
      ),
    );

    runtime.dispose();
    await tester.pump(const Duration(seconds: 2));
  });
}

class _FakeProvider implements AiProvider {
  @override
  Future<ProviderResult> generateContent({
    required String systemPrompt,
    required String userMessage,
    required List<ToolDefinition> tools,
    required List<AgentStep> history,
    String? screenshotBase64,
  }) {
    throw UnimplementedError('Not used in this test.');
  }
}

Future<Object?> _noopDataHandler(DataQueryContext context) async =>
    <String, Object?>{};
