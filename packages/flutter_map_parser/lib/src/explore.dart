import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Prepared exploration artifacts written under `.flutter-map/`.
class ExplorePrepareResult {
  const ExplorePrepareResult({
    required this.workingDir,
    required this.routeCount,
    required this.flowCount,
    required this.planPath,
    required this.captureStatusPath,
  });

  final String workingDir;
  final int routeCount;
  final int flowCount;
  final String planPath;
  final String captureStatusPath;
}

/// Builds deep-link explore plan + argent flow stubs from `graph.json`.
///
/// Does not talk to a simulator — that is the agent skill's job. This step
/// materializes deterministic deep-link flows and a machine-readable plan.
ExplorePrepareResult prepareExplore({
  required String projectRoot,
  String workingDirName = '.flutter-map',
  int waitMs = 1500,
}) {
  final String resolvedRoot = p.normalize(p.absolute(projectRoot));
  final String base = p.join(resolvedRoot, workingDirName);
  final File graphFile = File(p.join(base, 'graph.json'));
  if (!graphFile.existsSync()) {
    throw StateError(
      'Missing $workingDirName/graph.json under $resolvedRoot. '
      'Run parse_routes first.',
    );
  }
  final Map<String, Object?> graph =
      jsonDecode(graphFile.readAsStringSync()) as Map<String, Object?>;
  final String? scheme = graph['scheme'] as String?;
  final List<Object?> routes = (graph['routes'] as List<Object?>?) ?? <Object?>[];
  final List<Object?> edges = (graph['edges'] as List<Object?>?) ?? <Object?>[];
  final Map<String, String> sampleParams = _collectSampleParams(edges);
  final Directory flowsDir = Directory(p.join(base, 'flows'))
    ..createSync(recursive: true);
  Directory(p.join(base, 'screens')).createSync(recursive: true);
  final List<Map<String, Object?>> planRoutes = <Map<String, Object?>>[];
  final Map<String, Object?> captureStatus = <String, Object?>{};
  int flowCount = 0;
  for (final Object? raw in routes) {
    final Map<String, Object?> route = Map<String, Object?>.from(raw as Map);
    final String id = route['id'] as String? ?? '';
    final String urlPath = route['urlPath'] as String? ?? '/';
    final String slug = route['slug'] as String? ?? id;
    final List<String> params = ((route['params'] as List<Object?>?) ?? <Object?>[])
        .map((Object? value) => value.toString())
        .toList();
    final Map<String, String> substitutions = <String, String>{};
    for (final String param in params) {
      substitutions[param] = sampleParams[param] ??
          sampleParams['$id:$param'] ??
          '1';
    }
    final String concretePath = _substituteParams(urlPath, substitutions);
    final String? deepLink =
        scheme == null ? null : _buildDeepLink(scheme, concretePath);
    planRoutes.add(<String, Object?>{
      'id': id,
      'slug': slug,
      'urlPath': urlPath,
      'concretePath': concretePath,
      'deepLink': deepLink,
      'params': substitutions,
      'stateHints': route['stateHints'] ?? <Object?>[],
      'file': route['file'],
      'iosOpenUrl': deepLink == null
          ? null
          : 'xcrun simctl openurl booted "$deepLink"',
      'androidOpenUrl': deepLink == null
          ? null
          : 'adb shell am start -a android.intent.action.VIEW -d "$deepLink"',
      'screenshotPath': '$workingDirName/screens/$slug.png',
    });
    captureStatus[id] = <String, Object?>{
      'status': 'missing',
      'needsNavigation': false,
      'note': deepLink == null
          ? 'No deep-link scheme found; explore via in-app navigation.'
          : 'Awaiting simulator capture.',
    };
    if (deepLink != null) {
      final String flowName = 'deeplink-$slug';
      _writeDeepLinkFlow(
        flowsDir: flowsDir,
        flowName: flowName,
        routeId: id,
        title: 'Deep link to $urlPath',
        deepLink: deepLink,
        slug: slug,
        waitMs: waitMs,
      );
      flowCount += 1;
    }
  }
  final Map<String, Object?> plan = <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'projectRoot': resolvedRoot,
    'scheme': scheme,
    'mode': graph['mode'],
    'waitMs': waitMs,
    'routes': planRoutes,
    'commands': <String, Object?>{
      'iosScreenshot':
          'xcrun simctl io booted screenshot $workingDirName/screens/<slug>.png',
      'androidScreenshot':
          'adb exec-out screencap -p > $workingDirName/screens/<slug>.png',
      'pack': 'dart run bin/pack_map.dart <project>',
    },
  };
  final String planPath = p.join(base, 'explore-plan.json');
  final String captureStatusPath = p.join(base, 'capture-status.json');
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  File(planPath).writeAsStringSync('${encoder.convert(plan)}\n');
  File(captureStatusPath)
      .writeAsStringSync('${encoder.convert(captureStatus)}\n');
  return ExplorePrepareResult(
    workingDir: base,
    routeCount: planRoutes.length,
    flowCount: flowCount,
    planPath: planPath,
    captureStatusPath: captureStatusPath,
  );
}

Map<String, String> _collectSampleParams(List<Object?> edges) {
  final Map<String, String> samples = <String, String>{};
  for (final Object? raw in edges) {
    final Map<String, Object?> edge = Map<String, Object?>.from(raw as Map);
    final String? target = edge['target'] as String?;
    if (target == null || !target.startsWith('/')) {
      continue;
    }
    final List<String> segments = target.split('/');
    for (final String segment in segments) {
      if (segment.isEmpty || segment.startsWith(':')) {
        continue;
      }
      // Heuristic: numeric / uuid-like segments are useful param samples.
      if (RegExp(r'^\d+$').hasMatch(segment) ||
          RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(segment)) {
        samples.putIfAbsent('id', () => segment);
        samples.putIfAbsent(segment, () => segment);
      }
    }
  }
  return samples;
}

String _substituteParams(String urlPath, Map<String, String> substitutions) {
  return urlPath.split('/').map((String segment) {
    if (segment.startsWith(':')) {
      final String name = segment.substring(1);
      return substitutions[name] ?? '1';
    }
    return segment;
  }).join('/');
}

String _buildDeepLink(String scheme, String concretePath) {
  final String path = concretePath.startsWith('/')
      ? concretePath.substring(1)
      : concretePath;
  if (path.isEmpty) {
    return '$scheme://';
  }
  return '$scheme://$path';
}

void _writeDeepLinkFlow({
  required Directory flowsDir,
  required String flowName,
  required String routeId,
  required String title,
  required String deepLink,
  required String slug,
  required int waitMs,
}) {
  final String yaml = '''
# $title
steps:
  - tool: open-url
    args:
      url: "$deepLink"
  - wait: $waitMs
''';
  final Map<String, Object?> meta = <String, Object?>{
    'formatVersion': 2,
    'name': flowName,
    'title': title,
    'route': routeId,
    'device': null,
    'recordedAt': DateTime.now().toUtc().toIso8601String(),
    'steps': <String, Object?>{
      '0': <String, Object?>{
        'screen': routeId,
        'capture': '$slug.png',
      },
    },
  };
  File(p.join(flowsDir.path, '$flowName.yaml')).writeAsStringSync(yaml);
  File(p.join(flowsDir.path, '$flowName.meta.json')).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(meta)}\n',
  );
}
