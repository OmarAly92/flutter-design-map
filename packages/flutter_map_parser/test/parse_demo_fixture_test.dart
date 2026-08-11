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
      'demo_go_router',
    ),
  );

  test('detects go_router mode for the demo fixture', () {
    expect(detectRoutingMode(fixtureRoot), RoutingMode.goRouter);
  });

  test('deep-link templates keep the target in the URI path', () {
    final RouteGraph graph = parseProject(fixtureRoot);
    for (final String? template in graph.deepLinkTemplates.values) {
      expect(template, startsWith('demomap:///'));
      expect(Uri.parse(template!.replaceAll(RegExp(r'<[^>]*>'), 'x')).host,
          isEmpty);
    }
  });

  test('parses demo fixture routes, edges, scheme, and sheet hints', () {
    final RouteGraph graph = parseProject(fixtureRoot);
    expect(graph.mode, 'go_router');
    expect(graph.scheme, 'demomap');
    expect(graph.routes, hasLength(4));
    expect(graph.edges, hasLength(5));
    expect(
      graph.routes.map((RouteNode route) => route.id).toSet(),
      equals(<String>{'home', 'details', 'about', 'settings'}),
    );
    expect(
      graph.routes.map((RouteNode route) => route.urlPath).toSet(),
      equals(<String>{'/', '/details/:id', '/about', '/settings'}),
    );
    final RouteNode details = graph.routes.firstWhere(
      (RouteNode route) => route.id == 'details',
    );
    expect(details.params, equals(<String>['id']));
    expect(
      details.stateHints.any((StateHint hint) => hint.type == 'bottom-sheet'),
      isTrue,
    );
    expect(
      graph.summary['routesWithStateHints'],
      greaterThanOrEqualTo(1),
    );
  });

  test('CLI writes graph.json under .flutter-map', () {
    final String outPath = p.join(fixtureRoot, '.flutter-map', 'graph.json');
    final RouteGraph graph = parseProject(fixtureRoot);
    writeGraphJson(graph: graph, outPath: outPath);
    expect(File(outPath).existsSync(), isTrue);
    final String contents = File(outPath).readAsStringSync();
    expect(contents.contains('"scheme": "demomap"'), isTrue);
    expect(contents.contains('"mode": "go_router"'), isTrue);
  });
}
