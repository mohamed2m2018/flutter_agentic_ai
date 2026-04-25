import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen map generator emits canonical nested routes from current router', () async {
    final result = await Process.run(
      'dart',
      const ['run', 'tool/generate_screen_map.dart'],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    final generatedMap = File('${Directory.current.path}/example/lib/ai_screen_map.dart').readAsStringSync();

    expect(generatedMap, contains("'/profile/settings': ScreenMapEntry("));
    expect(generatedMap, contains("'/profile/settings',"));
    expect(generatedMap, contains('safeDirectNavigation: false'));
    expect(generatedMap, contains('Push Notifications'));
    expect(generatedMap, contains("'/home': ScreenMapEntry("));
    expect(generatedMap, contains('Shop by Category'));
    expect(generatedMap, contains("'/home',\n      '/category/:id',\n      '/product/:id',"));
    expect(generatedMap, contains("'/cart': ScreenMapEntry("));
    expect(generatedMap, contains('cart items list with product name, color, price, quantity controls'));
    expect(generatedMap, isNot(contains('No products found matching your search.')));
    expect(generatedMap, isNot(contains('Your cart is empty')));
    expect(generatedMap, isNot(contains('Order Placed Successfully!')));
    expect(generatedMap, isNot(contains("description: 'Product screen with Error")));
    expect(generatedMap, contains('safeDirectNavigation: true'));
  });

  test('screen map generator summarizes simple mapped row structures as durable list identity', () async {
    final tempDir = await Directory.systemTemp.createTemp('mobileai_screen_map_test_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final routerFile = File('${tempDir.path}/router.dart');
    final screensFile = File('${tempDir.path}/screens.dart');
    final outputFile = File('${tempDir.path}/ai_screen_map.dart');

    await screensFile.writeAsString(r'''
import 'package:flutter/material.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = [
      {'name': 'Wireless Mouse', 'price': 49.99, 'image': 'https://example.com/mouse.png'},
      {'name': 'Mechanical Keyboard', 'price': 129.99, 'image': 'https://example.com/keyboard.png'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: products.map((product) {
          return ListTile(
            leading: Image.network(product['image']!),
            title: Text(product['name']!),
            subtitle: Text('\$${product['price']}'),
            trailing: ElevatedButton(
              onPressed: () {},
              child: const Text('Add'),
            ),
          );
        }).toList(),
      ),
    );
  }
}
''');

    await routerFile.writeAsString('''
import 'package:go_router/go_router.dart';
import 'screens.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrdersScreen(),
    ),
  ],
);
''');

    final result = await Process.run(
      'dart',
      ['run', 'tool/generate_screen_map.dart', routerFile.path, outputFile.path],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    final generatedMap = outputFile.readAsStringSync();
    expect(generatedMap, contains('items list with product name, product image, price, add button'));
  });
}
