import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';
import 'package:mobileai_flutter/src/core/element_tree_walker.dart';

void main() {
  testWidgets('widget tree walker finds tabs, rows, and toggles', (tester) async {
    final rootKey = GlobalKey();
    var pushNotifications = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: StatefulBuilder(
            builder: (context, setState) {
              return KeyedSubtree(
                key: rootKey,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Settings',
                        onPressed: () {},
                        icon: const Icon(Icons.settings),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text('Notifications'),
                            onTap: () {},
                          ),
                          SwitchListTile(
                            title: const Text('Push Notifications'),
                            value: pushNotifications,
                            onChanged: (value) {
                              setState(() => pushNotifications = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    BottomNavigationBar(
                      currentIndex: 0,
                      onTap: (_) {},
                      items: const [
                        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
                        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
                        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);
    final labels = elements.map((element) => element.label).toList(growable: false);

    expect(labels, contains('Settings'));
    expect(labels, contains('Notifications'));
    expect(labels, contains('Push Notifications'));
    expect(
      elements.any((element) => element.label == 'Home' && element.properties['actionIndex'] == 0),
      isTrue,
    );
    expect(
      elements.any((element) => element.label == 'Profile' && element.properties['actionIndex'] == 3),
      isTrue,
    );
    expect(
      elements.any((element) => element.label == 'Push Notifications' && element.type == ElementType.switchToggle),
      isTrue,
    );
  });

  testWidgets('widget tree walker finds gesture-driven category cards and prunes hidden routes', (tester) async {
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: KeyedSubtree(
            key: rootKey,
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.all(12),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.checkroom),
                              SizedBox(height: 8),
                              Text('Fashion'),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.all(12),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chair_alt),
                              SizedBox(height: 8),
                              Text('Home'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Offstage(
                  offstage: true,
                  child: ListTile(
                    title: Text('Hidden Route Button'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);
    final labels = elements.map((element) => element.label).toList(growable: false);

    expect(labels, contains('Fashion'));
    expect(labels, contains('Home'));
    expect(labels, isNot(contains('Hidden Route Button')));
    expect(
      elements.where((element) => element.label == 'Fashion' && element.type == ElementType.pressable).length,
      1,
    );
  });

  testWidgets('widget tree walker surfaces selector metadata from keys and tooltips', (tester) async {
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: KeyedSubtree(
            key: rootKey,
            child: Tooltip(
              message: 'Clear search',
              child: GestureDetector(
                key: const ValueKey('clear-search'),
                onTap: () {},
                child: const Icon(Icons.clear),
              ),
            ),
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);
    final clearAction = elements.firstWhere((element) => element.properties['key'] == 'clear-search');

    expect(clearAction.label, 'Clear search');
    expect(clearAction.properties['tooltip'], 'Clear search');
    expect(clearAction.properties['widgetType'], 'GestureDetector');
    expect((clearAction.properties['id'] as String?)?.startsWith('el-'), isTrue);
  });

  testWidgets('widget tree walker prunes inactive IndexedStack branches', (tester) async {
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: KeyedSubtree(
            key: rootKey,
            child: IndexedStack(
              index: 0,
              children: [
                ListTile(
                  title: const Text('Visible Settings'),
                  onTap: () {},
                ),
                ListTile(
                  title: const Text('Hidden Settings'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);
    final labels = elements.map((element) => element.label).toList(growable: false);

    expect(labels, contains('Visible Settings'));
    expect(labels, isNot(contains('Hidden Settings')));
  });

  testWidgets('widget tree walker prunes inactive navigator route branches', (tester) async {
    final rootKey = GlobalKey();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      KeyedSubtree(
        key: rootKey,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: Material(
            child: ListTile(
              title: const Text('Home Route Action'),
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => Material(
          child: ListTile(
            title: const Text('Product Route Action'),
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);
    final labels = elements.map((element) => element.label).toList(growable: false);

    expect(labels, contains('Product Route Action'));
    expect(labels, isNot(contains('Home Route Action')));
  });

  testWidgets('widget tree walker keeps parent cards and nested call to action buttons separate', (tester) async {
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: KeyedSubtree(
            key: rootKey,
            child: GestureDetector(
              onTap: () {},
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Silver Cotton T-Shirt'),
                      const SizedBox(height: 8),
                      const Text('\$39.99'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Add to Cart'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);
    final productCard = elements.where((element) => element.label.contains('Silver Cotton T-Shirt')).toList();
    final addToCartButtons = elements.where((element) => element.label == 'Add to Cart').toList();
    final priceTexts = elements.where((element) => element.label == '\$39.99').toList();

    expect(productCard, isNotEmpty);
    expect(productCard.every((element) => !element.label.contains('Add to Cart')), isTrue);
    expect(addToCartButtons.length, 1);
    expect(addToCartButtons.single.type, ElementType.pressable);
    expect(priceTexts.any((element) => element.type == ElementType.text), isTrue);
  });

  testWidgets('widget tree walker emits visible detail text inside a main scroll view', (tester) async {
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: KeyedSubtree(
            key: rootKey,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('\$19.99'),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {},
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('4.5 (320 reviews)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Cotton T-Shirt'),
                    const SizedBox(height: 8),
                    const Text('100% organic cotton basic t-shirt.'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {},
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Black'),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Silver'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Add to Cart'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);
    final labels = elements.map((element) => element.label).toList(growable: false);

    expect(labels, contains('\$19.99'));
    expect(labels, contains('Cotton T-Shirt'));
    expect(labels, contains('100% organic cotton basic t-shirt.'));
    expect(labels, contains('Add to Cart'));
    expect(elements.any((element) => element.label == '\$19.99' && element.type == ElementType.text), isTrue);
    final scrollHost = elements.firstWhere((element) => element.type == ElementType.scrollable);
    final priceText = elements.firstWhere((element) => element.label == '\$19.99');
    expect(scrollHost.properties['scrollHostId'], scrollHost.properties['id']);
    expect(priceText.properties['scrollHostId'], scrollHost.properties['id']);
  });

  testWidgets('widget tree walker emits home-like category cards instead of only scrollables', (tester) async {
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: KeyedSubtree(
            key: rootKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Shop by Category'),
                  ),
                  SizedBox(
                    height: 180,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryCard(
                          icon: Icons.devices,
                          label: 'Electronics',
                        ),
                        _CategoryCard(
                          icon: Icons.checkroom,
                          label: 'Fashion',
                        ),
                        _CategoryCard(
                          icon: Icons.chair_alt,
                          label: 'Home',
                        ),
                        _CategoryCard(
                          icon: Icons.restaurant,
                          label: 'Food',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {},
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Silver Cotton T-Shirt'),
                            const SizedBox(height: 8),
                            const Text('Soft premium cotton'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {},
                              child: const Text('Add to Cart'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);
    final labels = elements.map((element) => element.label).toList(growable: false);

    expect(labels, contains('Electronics'));
    expect(labels, contains('Fashion'));
    expect(labels, contains('Home'));
    expect(labels, contains('Food'));
    expect(elements.any((element) => element.label == 'Electronics' && element.type == ElementType.pressable), isTrue);
    expect(elements.any((element) => element.label == 'Add to Cart' && element.type == ElementType.pressable), isTrue);
  });

  testWidgets('widget tree walker normalizes generic control state like RN', (tester) async {
    final rootKey = GlobalKey();
    final controller = TextEditingController(text: 'cotton t-shirts');
    String shippingSpeed = 'standard';

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: StatefulBuilder(
            builder: (context, setState) {
              return KeyedSubtree(
                key: rootKey,
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Search products...',
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: false,
                          onSelected: (_) {},
                        ),
                        FilterChip(
                          label: const Text('Fashion'),
                          selected: true,
                          onSelected: (_) {},
                        ),
                      ],
                    ),
                    // ignore: deprecated_member_use
                    RadioListTile<String>(
                      value: 'standard',
                      // ignore: deprecated_member_use
                      groupValue: shippingSpeed,
                      // ignore: deprecated_member_use
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => shippingSpeed = value);
                      },
                      title: const Text('Standard Shipping'),
                    ),
                    BottomNavigationBar(
                      currentIndex: 3,
                      onTap: (_) {},
                      items: const [
                        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
                        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
                        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);

    final searchField = elements.firstWhere((element) => element.label == 'Search products...');
    final fashionChip = elements.firstWhere((element) => element.label == 'Fashion');
    final shippingRadio = elements.firstWhere((element) => element.label == 'Standard Shipping');
    final profileTab = elements.firstWhere((element) => element.label == 'Profile');

    expect(searchField.type, ElementType.textInput);
    expect(searchField.properties['role'], 'textbox');
    expect(searchField.properties['value'], 'cotton t-shirts');
    expect(searchField.properties['hint'], 'Search products...');

    expect(fashionChip.properties['selected'], true);
    expect(fashionChip.properties['role'], 'button');

    expect(shippingRadio.properties['role'], 'radio');
    expect(shippingRadio.properties['checked'], true);
    expect(shippingRadio.properties['selected'], true);
    expect(shippingRadio.properties['value'], 'standard');

    expect(profileTab.properties['role'], 'tab');
    expect(profileTab.properties['selected'], true);
  });

  testWidgets('widget tree walker exposes input-adjacent actions and scroll orientation', (tester) async {
    final rootKey = GlobalKey();
    final controller = TextEditingController(text: 'cotton tshirt');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyedSubtree(
            key: rootKey,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
                SizedBox(
                  height: 72,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        8,
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Chip(label: Text('Chip $index')),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: const [
                      ListTile(title: Text('Cotton T-Shirt')),
                      ListTile(title: Text('Running Shoes')),
                      ListTile(title: Text('Denim Jacket')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);

    expect(elements.any((element) => element.label == 'Search products...' && element.type == ElementType.textInput), isTrue);
    expect(elements.any((element) => element.label == 'Clear' && element.type == ElementType.pressable), isTrue);
    expect(
      elements.any(
        (element) =>
            element.label == 'Horizontal scroll area' &&
            element.type == ElementType.scrollable &&
            element.properties['orientation'] == 'horizontal',
      ),
      isTrue,
    );
    expect(
      elements.any(
        (element) =>
            element.label == 'Vertical scroll area' &&
            element.type == ElementType.scrollable &&
            element.properties['orientation'] == 'vertical',
      ),
      isTrue,
    );
  });

  testWidgets('widget tree walker emits one canonical scroll host per scroll region', (tester) async {
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: KeyedSubtree(
            key: rootKey,
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(
                  6,
                  (index) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Row $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);
    final scrollables = elements.where((element) => element.type == ElementType.scrollable).toList();

    expect(scrollables.length, 1);
    expect(scrollables.single.properties['orientation'], 'vertical');
  });

  testWidgets('widget tree walker does not duplicate bottom navigation items', (tester) async {
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: KeyedSubtree(
            key: rootKey,
            child: BottomNavigationBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
                BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
              ],
            ),
          ),
        ),
      ),
    );

    final walker = ElementTreeWalker(AgentConfig());
    final rootElement = tester.element(find.byKey(rootKey));
    final elements = walker.walk(rootElement);

    expect(elements.where((element) => element.label == 'Home').length, 1);
    expect(elements.where((element) => element.label == 'Search').length, 1);
    expect(elements.where((element) => element.label == 'Cart').length, 1);
  });
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CategoryCard({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 140,
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon),
                const SizedBox(height: 8),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
