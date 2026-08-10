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
      'demo_go_router_builder',
    ),
  );

  test('detects go_router_builder mode for the typed fixture', () {
    expect(detectRoutingMode(fixtureRoot), RoutingMode.goRouterBuilder);
  });

  test('parses TypedGoRoute annotations into routes and typed edges', () {
    final RouteGraph graph = parseProject(fixtureRoot);
    expect(graph.mode, 'go_router_builder');
    expect(graph.scheme, 'demomap');
    expect(graph.routes, hasLength(4));
    expect(graph.edges, hasLength(5));
    expect(
      graph.routes.map((RouteNode route) => route.id).toSet(),
      equals(<String>{
        'HomeRoute',
        'DetailsRoute',
        'AboutRoute',
        'SettingsRoute',
      }),
    );
    expect(
      graph.routes.map((RouteNode route) => route.urlPath).toSet(),
      equals(<String>{'/', '/details/:id', '/about', '/settings'}),
    );
    final RouteNode details = graph.routes.firstWhere(
      (RouteNode route) => route.id == 'DetailsRoute',
    );
    expect(details.params, equals(<String>['id']));
    expect(details.file, 'lib/screens/details_screen.dart');
    expect(
      details.stateHints.any((StateHint hint) => hint.type == 'bottom-sheet'),
      isTrue,
    );
    expect(
      graph.edges.any(
        (Edge edge) =>
            edge.from == 'HomeRoute' && edge.to == 'DetailsRoute',
      ),
      isTrue,
    );
  });
}
