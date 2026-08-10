import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Result of packing a `.flutter-map` working directory into an `.appmap` zip.
class PackResult {
  const PackResult({
    required this.outPath,
    required this.nodeCount,
    required this.edgeCount,
    required this.flowCount,
    required this.screenshotCount,
    required this.bytes,
  });

  final String outPath;
  final int nodeCount;
  final int edgeCount;
  final int flowCount;
  final int screenshotCount;
  final int bytes;
}

/// Packs `<projectRoot>/.flutter-map` into a v2 `.appmap` bundle.
///
/// Optional inputs in the working dir:
/// - `graph.json` (required)
/// - `capture-status.json`
/// - `screens/*.{png,jpg,jpeg,webp}`
/// - `flows/*.{yaml,meta.json}`
PackResult packMap({
  required String projectRoot,
  String? outPath,
  String workingDirName = '.flutter-map',
  String generator = 'flutter-map/0.1',
  String platform = 'ios-simulator',
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
  final Map<String, Object?> captureStatus = _readCaptureStatus(base);
  final List<String> shotFiles = _listScreenshots(base);
  final List<String> flowFiles = _listFlowFiles(base);
  final List<Map<String, Object?>> flowMetas = flowFiles
      .where((String name) => name.endsWith('.meta.json'))
      .map((String name) => _tryReadJson(p.join(base, 'flows', name)))
      .whereType<Map<String, Object?>>()
      .toList();
  final String appName = p.basename(
    (graph['projectRoot'] as String?) ?? resolvedRoot,
  );
  final List<Object?> routes = (graph['routes'] as List<Object?>?) ?? <Object?>[];
  final List<Object?> edges = (graph['edges'] as List<Object?>?) ?? <Object?>[];
  final List<Map<String, Object?>> nodes = routes.map((Object? raw) {
    final Map<String, Object?> route = Map<String, Object?>.from(raw as Map);
    final String id = route['id'] as String? ?? '';
    final String slug = route['slug'] as String? ?? id;
    final Map<String, Object?> status =
        Map<String, Object?>.from(captureStatus[id] as Map? ?? <String, Object?>{});
    final String? baseShot = _findBaseScreenshot(shotFiles, slug);
    final List<Map<String, Object?>> states = shotFiles
        .where((String file) => file.startsWith('$slug--'))
        .map((String file) {
          final String name =
              _basenameWithoutExt(file).substring(slug.length + 2);
          return <String, Object?>{
            'name': name,
            'screenshot': 'screens/$file',
          };
        })
        .toList()
      ..sort(
        (Map<String, Object?> a, Map<String, Object?> b) =>
            (a['name'] as String).compareTo(b['name'] as String),
      );
    return <String, Object?>{
      'id': id,
      'urlPath': route['urlPath'],
      'file': route['file'],
      'slug': slug,
      'group': route['layoutDir'] ?? '',
      'navigator': route['navigator'],
      'params': route['params'] ?? <String>[],
      'presentation': route['presentation'],
      'stateHints': route['stateHints'] ?? <Object?>[],
      'capture': <String, Object?>{
        'status': status['status'] ?? (baseShot == null ? 'missing' : 'ok'),
        'note': status['note'],
        'needsNavigation': status['needsNavigation'] ?? false,
        'screenshot': baseShot == null ? null : 'screens/$baseShot',
        'states': states,
      },
    };
  }).toList();
  final Map<String, Object?> map = <String, Object?>{
    'nodes': nodes,
    'edges': edges,
    'flows': <Object?>[],
  };
  final String? device = _firstDevice(flowMetas);
  final Map<String, Object?> manifest = <String, Object?>{
    'formatVersion': 2,
    'flowFormat': 'argent',
    'generator': generator,
    'app': <String, Object?>{
      'name': appName,
      'scheme': graph['scheme'],
      'platform': platform,
      'device': device,
      'mode': graph['mode'],
    },
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
  };
  final String date = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final String resolvedOut = p.normalize(
    p.absolute(
      outPath ?? p.join(base, '$appName-$date.appmap'),
    ),
  );
  final Archive archive = Archive();
  _addJson(archive, 'manifest.json', manifest);
  _addJson(archive, 'map.json', map);
  for (final String shot in shotFiles) {
    final List<int> bytes =
        File(p.join(base, 'screens', shot)).readAsBytesSync();
    archive.addFile(ArchiveFile('screens/$shot', bytes.length, bytes));
  }
  for (final String flow in flowFiles) {
    final List<int> bytes = File(p.join(base, 'flows', flow)).readAsBytesSync();
    archive.addFile(ArchiveFile('flows/$flow', bytes.length, bytes));
  }
  final List<int> zipBytes = ZipEncoder().encode(archive);
  final File outFile = File(resolvedOut);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsBytesSync(zipBytes);
  return PackResult(
    outPath: resolvedOut,
    nodeCount: nodes.length,
    edgeCount: edges.length,
    flowCount: flowMetas.length,
    screenshotCount: shotFiles.length,
    bytes: zipBytes.length,
  );
}

void _addJson(Archive archive, String name, Map<String, Object?> value) {
  final List<int> bytes =
      utf8.encode('${const JsonEncoder.withIndent('  ').convert(value)}\n');
  archive.addFile(ArchiveFile(name, bytes.length, bytes));
}

Map<String, Object?> _readCaptureStatus(String base) {
  final File file = File(p.join(base, 'capture-status.json'));
  if (!file.existsSync()) {
    return <String, Object?>{};
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  if (decoded is Map) {
    return Map<String, Object?>.from(decoded);
  }
  return <String, Object?>{};
}

Map<String, Object?>? _tryReadJson(String path) {
  try {
    final Object? decoded = jsonDecode(File(path).readAsStringSync());
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
  } catch (_) {}
  return null;
}

List<String> _listScreenshots(String base) {
  final Directory dir = Directory(p.join(base, 'screens'));
  if (!dir.existsSync()) {
    return <String>[];
  }
  return dir
      .listSync()
      .whereType<File>()
      .map((File file) => p.basename(file.path))
      .where((String name) => RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false)
          .hasMatch(name))
      .toList()
    ..sort();
}

List<String> _listFlowFiles(String base) {
  final Directory dir = Directory(p.join(base, 'flows'));
  if (!dir.existsSync()) {
    return <String>[];
  }
  return dir
      .listSync()
      .whereType<File>()
      .map((File file) => p.basename(file.path))
      .where(
        (String name) => name.endsWith('.yaml') || name.endsWith('.meta.json'),
      )
      .toList()
    ..sort();
}

String _basenameWithoutExt(String fileName) {
  final int dot = fileName.lastIndexOf('.');
  if (dot <= 0) {
    return fileName;
  }
  return fileName.substring(0, dot);
}

String? _findBaseScreenshot(List<String> shotFiles, String slug) {
  for (final String file in shotFiles) {
    if (_basenameWithoutExt(file) == slug) {
      return file;
    }
  }
  return null;
}

String? _firstDevice(List<Map<String, Object?>> flowMetas) {
  for (final Map<String, Object?> meta in flowMetas) {
    final Object? device = meta['device'];
    if (device is String && device.isNotEmpty) {
      return device;
    }
  }
  return null;
}
