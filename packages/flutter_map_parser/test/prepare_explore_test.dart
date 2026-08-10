import 'dart:convert';
import 'dart:io';

import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flutter_map_explore_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('prepareExplore writes plan, capture-status, and deep-link flows', () {
    final String fixtureRoot = p.normalize(
      p.join(
        Directory.current.path,
        '..',
        '..',
        'fixtures',
        'demo_go_router',
      ),
    );
    final RouteGraph graph = parseProject(fixtureRoot);
    writeGraphJson(
      graph: graph,
      outPath: p.join(tempDir.path, '.flutter-map', 'graph.json'),
    );
    final ExplorePrepareResult prepared = prepareExplore(
      projectRoot: tempDir.path,
      waitMs: 1200,
    );
    expect(prepared.routeCount, 4);
    expect(prepared.flowCount, 4);
    expect(File(prepared.planPath).existsSync(), isTrue);
    expect(File(prepared.captureStatusPath).existsSync(), isTrue);
    final Map<String, Object?> plan = jsonDecode(
      File(prepared.planPath).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(plan['scheme'], 'demomap');
    final List<Object?> routes = plan['routes'] as List<Object?>;
    final Map<String, Object?> details = Map<String, Object?>.from(
      routes.firstWhere(
        (Object? route) => (route as Map)['id'] == 'details',
      ) as Map,
    );
    expect(details['concretePath'], '/details/42');
    expect(details['deepLink'], 'demomap:///details/42');
    expect(
      details['iosOpenUrl'],
      contains('xcrun simctl openurl booted "demomap:///details/42"'),
    );
    final String flowYaml = File(
      p.join(tempDir.path, '.flutter-map', 'flows', 'deeplink-details_id.yaml'),
    ).readAsStringSync();
    expect(flowYaml.contains('demomap:///details/42'), isTrue);
    expect(flowYaml.contains('wait: 1200'), isTrue);
    final Map<String, Object?> meta = jsonDecode(
      File(
        p.join(
          tempDir.path,
          '.flutter-map',
          'flows',
          'deeplink-details_id.meta.json',
        ),
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(meta['route'], 'details');
    expect(meta['formatVersion'], 2);
    final Map<String, Object?> metaSteps = Map<String, Object?>.from(
      meta['steps'] as Map,
    );
    expect((metaSteps['0'] as Map)['screen'], 'details');
    expect((metaSteps['1'] as Map)['capture'], 'details_id.png');
    final Map<String, Object?> captureStatus = jsonDecode(
      File(prepared.captureStatusPath).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(captureStatus['details'], isA<Map>());
    expect((captureStatus['details'] as Map)['status'], 'missing');
  });
}
