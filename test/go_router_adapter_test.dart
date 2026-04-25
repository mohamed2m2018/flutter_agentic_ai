import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/src/navigation/go_router_adapter.dart';

void main() {
  test('GoRouterAdapter prefers the top matched route over stale route information', () {
    final router = _FakeGoRouter(
      state: const _FakeGoRouterState('/product/coffee-maker'),
      routeInformationProvider: _FakeRouteInformationProvider('/home'),
      configuration: _FakeConfiguration([
        _FakeRoute('/home', null),
        _FakeRoute('/product/:id', null),
      ]),
    );

    final adapter = GoRouterAdapter(router: router);

    expect(adapter.getCurrentScreenName(), '/product/:id');
  });
}

class _FakeGoRouter {
  _FakeGoRouter({
    required this.state,
    required this.routeInformationProvider,
    required this.configuration,
  }) : routerDelegate = _FakeRouterDelegate(state);

  final _FakeGoRouterState state;
  final _FakeRouteInformationProvider routeInformationProvider;
  final _FakeConfiguration configuration;
  final _FakeRouterDelegate routerDelegate;

  void back() {}

  void go(String href) {}

  void push(String href) {}

  void replace(String href) {}
}

class _FakeGoRouterState {
  const _FakeGoRouterState(this.matchedLocation);

  final String matchedLocation;
}

class _FakeRouteInformationProvider {
  _FakeRouteInformationProvider(String path)
    : value = _FakeRouteInformationValue(Uri.parse(path));

  final _FakeRouteInformationValue value;
}

class _FakeRouteInformationValue {
  const _FakeRouteInformationValue(this.uri);

  final Uri uri;
}

class _FakeRouterDelegate {
  _FakeRouterDelegate(this.state);

  final _FakeGoRouterState state;
}

class _FakeConfiguration {
  const _FakeConfiguration(this.routes);

  final List<_FakeRoute> routes;
}

class _FakeRoute {
  const _FakeRoute(this.path, this.routes);

  final String path;
  final List<_FakeRoute>? routes;
}
