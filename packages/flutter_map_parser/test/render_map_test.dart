import 'dart:convert';
import 'dart:io';

import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flutter_map_render_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('renders a self-contained capture review map', () {
    final String work = p.join(tempDir.path, '.flutter-map');
    Directory(p.join(work, 'screens')).createSync(recursive: true);
    File(p.join(work, 'graph.json')).writeAsStringSync(
      jsonEncode(<String, Object?>{
        'routes': <Object?>[
          <String, Object?>{
            'id': 'home',
            'urlPath': '/',
            'slug': 'home',
          },
        ],
        'edges': <Object?>[],
      }),
    );
    File(p.join(work, 'screens', 'home.png')).writeAsBytesSync(
      <int>[137, 80, 78, 71, 13, 10, 26, 10],
    );

    final RenderResult result = renderStaticMap(projectRoot: tempDir.path);

    final String html = File(result.outPath).readAsStringSync();
    expect(result.routeCount, 1);
    expect(result.captureCount, 1);
    expect(html, contains('data:image/png;base64,'));
    expect(html, contains('<h2>&#47;</h2>'));
  });
}
