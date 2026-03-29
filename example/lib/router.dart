import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_agentic_ai/flutter_agentic_ai.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/search_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/category_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/reviews_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return Stack(
          children: [
            Scaffold(
              body: child,
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _calculateSelectedIndex(context),
                onTap: (int idx) => _onItemTapped(idx, context),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                  BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
                  BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
                  BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
                ],
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Colors.deepPurple,
                unselectedItemColor: Colors.grey,
              ),
            ),
          ],
        );
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/category/:id',
      builder: (context, state) => CategoryScreen(categoryId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/product/:id',
      builder: (context, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/product/:id/reviews',
      builder: (context, state) => ReviewsScreen(productId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/profile/settings',
      builder: (context, state) => const ProfileSettingsScreen(),
    ),
  ],
);

int _calculateSelectedIndex(BuildContext context) {
  final GoRouterState state = GoRouterState.of(context);
  final String location = state.matchedLocation;
  if (location.startsWith('/home')) return 0;
  if (location.startsWith('/search')) return 1;
  if (location.startsWith('/cart')) return 2;
  if (location.startsWith('/profile')) return 3;
  return 0;
}

void _onItemTapped(int index, BuildContext context) {
  switch (index) {
    case 0:
      context.go('/home');
      break;
    case 1:
      context.go('/search');
      break;
    case 2:
      context.go('/cart');
      break;
    case 3:
      context.go('/profile');
      break;
  }
}
