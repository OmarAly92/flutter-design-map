import 'dart:io';

import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final String fixtureRoot = p.normalize(
    p.join(
      Directory.current.path,
      '..',
      '..',
      'fixtures',
      'demo_navigator_generate_route',
    ),
  );

  test('detects navigator mode when onGenerateRoute is a class tear-off', () {
    expect(detectRoutingMode(fixtureRoot), RoutingMode.navigator);
  });

  test('resolves onGenerateRoute pointing at a static method in another file',
      () {
    final RouteGraph graph = parseProject(fixtureRoot);
    expect(graph.mode, 'navigator');
    expect(
      graph.routes.map((RouteNode route) => route.urlPath).toSet(),
      equals(<String>{
        '/home-screen',
        '/login-screen',
        '/settings-screen',
        '/add-transaction-screen',
      }),
    );
  });

  test('resolves switch-case labels from a constants class in another file',
      () {
    final RouteGraph graph = parseProject(fixtureRoot);
    final RouteNode settings = graph.routes.firstWhere(
      (RouteNode route) => route.urlPath == '/settings-screen',
    );
    expect(settings.widgetName, 'SettingsScreen');
    expect(settings.file, 'lib/screens/settings_screen.dart');
  });

  test('extracts pushNamed edges between generateRoute routes', () {
    final RouteGraph graph = parseProject(fixtureRoot);
    expect(
      graph.edges.any(
        (Edge edge) =>
            edge.from == 'home-screen' && edge.to == 'settings-screen',
      ),
      isTrue,
      reason: 'Navigator.pushNamed edge should resolve',
    );
    expect(
      graph.edges.any(
        (Edge edge) =>
            edge.from == 'home-screen' && edge.to == 'add-transaction-screen',
      ),
      isTrue,
      reason: 'Navigator.of(context).pushNamed edge should resolve',
    );
  });

  test('attributes a nav call in a child widget outside the route directory',
      () {
    final RouteGraph graph = parseProject(fixtureRoot);
    expect(
      graph.edges.any(
        (Edge edge) => edge.from == 'home-screen' && edge.to == 'login-screen',
      ),
      isTrue,
      reason: 'PromoCard lives in lib/widgets and is only used by HomeScreen, '
          'so the edge is reachable only through widget composition',
    );
    expect(
      graph.edges.any(
        (Edge edge) => edge.to == 'login-screen' && edge.from != 'home-screen',
      ),
      isFalse,
      reason: 'the call site must not be attributed to any other route',
    );
  });
}
