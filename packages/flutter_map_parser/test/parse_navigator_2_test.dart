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
      'demo_navigator_2',
    ),
  );

  test('detects navigator_2 mode for the fixture', () {
    expect(detectRoutingMode(fixtureRoot), RoutingMode.navigator2);
  });

  test('parses RouterDelegate pages into routes and stack edges', () {
    final RouteGraph graph = parseProject(fixtureRoot);
    expect(graph.mode, 'navigator_2');
    expect(
      graph.routes.map((RouteNode route) => route.urlPath).toSet(),
      equals(<String>{'/', '/about', '/settings', '/details/:id'}),
    );
    expect(
      graph.routes.firstWhere((RouteNode route) => route.urlPath == '/').file,
      'lib/screens/home_screen.dart',
    );
    expect(
      graph.routes
          .firstWhere((RouteNode route) => route.urlPath == '/details/:id')
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
        (Edge edge) => edge.from == 'index' && edge.to == 'details_id',
      ),
      isTrue,
    );
  });
}
