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
      'demo_navigator',
    ),
  );

  test('detects navigator mode for the fixture', () {
    expect(detectRoutingMode(fixtureRoot), RoutingMode.navigator);
  });

  test('parses MaterialApp routes, onGenerateRoute, and Navigator edges', () {
    final RouteGraph graph = parseProject(fixtureRoot);
    expect(graph.mode, 'navigator');
    expect(
      graph.routes.map((RouteNode route) => route.urlPath).toSet(),
      equals(<String>{'/', '/about', '/settings', '/details'}),
    );
    expect(
      graph.routes.firstWhere((RouteNode route) => route.urlPath == '/').file,
      'lib/screens/home_screen.dart',
    );
    expect(
      graph.routes
          .firstWhere((RouteNode route) => route.urlPath == '/details')
          .widgetName,
      'DetailsScreen',
    );
    expect(
      graph.edges.any(
        (Edge edge) => edge.from == 'index' && edge.to == 'about',
      ),
      isTrue,
    );
    expect(
      graph.edges.any(
        (Edge edge) => edge.from == 'index' && edge.to == 'settings',
      ),
      isTrue,
    );
    expect(
      graph.edges.any(
        (Edge edge) => edge.from == 'index' && edge.to == 'details',
      ),
      isTrue,
    );
    expect(
      graph.edges.any(
        (Edge edge) => edge.from == 'settings' && edge.to == 'about',
      ),
      isTrue,
    );
  });
}
