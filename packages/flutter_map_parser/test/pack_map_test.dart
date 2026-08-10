import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flutter_map_pack_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('packs graph.json into a v2 .appmap zip', () {
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
    final String working = p.join(tempDir.path, '.flutter-map');
    writeGraphJson(
      graph: graph,
      outPath: p.join(working, 'graph.json'),
    );
    Directory(p.join(working, 'screens')).createSync(recursive: true);
    File(p.join(working, 'screens', 'index.png')).writeAsBytesSync(
      <int>[137, 80, 78, 71, 13, 10, 26, 10],
    );
    Directory(p.join(working, 'flows')).createSync(recursive: true);
    File(p.join(working, 'flows', 'home.yaml')).writeAsStringSync(
      'steps:\n  - wait: 100\n',
    );
    File(p.join(working, 'flows', 'home.meta.json')).writeAsStringSync(
      jsonEncode(<String, Object?>{
        'formatVersion': 2,
        'name': 'home',
        'route': 'home',
        'device': 'iPhone 16',
      }),
    );
    final String outPath = p.join(tempDir.path, 'demo.appmap');
    final PackResult packed = packMap(
      projectRoot: tempDir.path,
      outPath: outPath,
    );
    expect(File(outPath).existsSync(), isTrue);
    expect(packed.nodeCount, 4);
    expect(packed.edgeCount, 5);
    expect(packed.flowCount, 1);
    expect(packed.screenshotCount, 1);
    final Archive archive =
        ZipDecoder().decodeBytes(File(outPath).readAsBytesSync());
    final ArchiveFile? manifestFile = archive.findFile('manifest.json');
    final ArchiveFile? mapFile = archive.findFile('map.json');
    expect(manifestFile, isNotNull);
    expect(mapFile, isNotNull);
    final Map<String, Object?> manifest = jsonDecode(
      utf8.decode(manifestFile!.content as List<int>),
    ) as Map<String, Object?>;
    expect(manifest['formatVersion'], 2);
    expect(manifest['generator'], 'flutter-map/0.1');
    final Map<String, Object?> app =
        Map<String, Object?>.from(manifest['app'] as Map);
    expect(app['scheme'], 'demomap');
    expect(app['mode'], 'go_router');
    expect(app['device'], 'iPhone 16');
    final Map<String, Object?> map = jsonDecode(
      utf8.decode(mapFile!.content as List<int>),
    ) as Map<String, Object?>;
    final List<Object?> nodes = map['nodes'] as List<Object?>;
    expect(nodes, hasLength(4));
    final Map<String, Object?> home = Map<String, Object?>.from(
      nodes.firstWhere(
        (Object? node) => (node as Map)['id'] == 'home',
      ) as Map,
    );
    final Map<String, Object?> capture =
        Map<String, Object?>.from(home['capture'] as Map);
    expect(capture['status'], 'ok');
    expect(capture['screenshot'], 'screens/index.png');
    expect(archive.findFile('screens/index.png'), isNotNull);
    expect(archive.findFile('flows/home.yaml'), isNotNull);
    expect(archive.findFile('flows/home.meta.json'), isNotNull);
  });

  test('marks captures missing when screenshots are absent', () {
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
    final PackResult packed = packMap(projectRoot: tempDir.path);
    final Archive archive =
        ZipDecoder().decodeBytes(File(packed.outPath).readAsBytesSync());
    final Map<String, Object?> map = jsonDecode(
      utf8.decode(archive.findFile('map.json')!.content as List<int>),
    ) as Map<String, Object?>;
    final List<Object?> nodes = map['nodes'] as List<Object?>;
    expect(
      nodes.every(
        (Object? node) =>
            ((node as Map)['capture'] as Map)['status'] == 'missing',
      ),
      isTrue,
    );
  });
}
