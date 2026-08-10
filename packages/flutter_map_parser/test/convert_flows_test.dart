import 'dart:convert';
import 'dart:io';

import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('converts legacy flow JSON to normalized Argent files', () {
    final Directory temp = Directory.systemTemp.createTempSync('flow_convert_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final Directory flows =
        Directory(p.join(temp.path, '.flutter-map', 'flows'))
          ..createSync(recursive: true);
    File(p.join(flows.path, 'legacy.json')).writeAsStringSync(
      jsonEncode(<String, Object?>{
        'name': 'open-settings',
        'route': 'settings',
        'pointSize': <num>[400, 800],
        'steps': <Object?>[
          <String, Object?>{
            'action': 'tap',
            'coordinate': <num>[100, 400],
            'target': 'Settings',
            'screen': 'settings',
          },
          <String, Object?>{'action': 'screenshot', 'file': 'settings.png'},
        ],
      }),
    );

    final ConvertFlowsResult result = convertLegacyFlows(
      projectRoot: temp.path,
    );

    expect(result.converted, 1);
    expect(
      File(p.join(flows.path, 'open-settings.yaml')).readAsStringSync(),
      contains('tap: { x: 0.25, y: 0.5 }'),
    );
    final Map<String, Object?> meta = jsonDecode(
      File(p.join(flows.path, 'open-settings.meta.json')).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(((meta['steps'] as Map)['0'] as Map)['capture'], 'settings.png');
  });
}
