import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ConvertFlowsResult {
  const ConvertFlowsResult({required this.converted});

  final int converted;
}

/// Converts legacy inline-action JSON flow files to Argent YAML + sidecars.
ConvertFlowsResult convertLegacyFlows({
  required String projectRoot,
  String workingDirName = '.flutter-map',
  List<double> defaultPointSize = const <double>[402, 874],
  bool deleteLegacy = false,
}) {
  final Directory flows = Directory(
    p.join(p.normalize(p.absolute(projectRoot)), workingDirName, 'flows'),
  );
  if (!flows.existsSync()) {
    return const ConvertFlowsResult(converted: 0);
  }
  int converted = 0;
  for (final File file in flows.listSync().whereType<File>()) {
    final String name = p.basename(file.path);
    if (!name.endsWith('.json') || name.endsWith('.meta.json')) {
      continue;
    }
    final Map<String, Object?> legacy = Map<String, Object?>.from(
      jsonDecode(file.readAsStringSync()) as Map,
    );
    final List<double> pointSize =
        _numbers(legacy['pointSize']) ?? defaultPointSize;
    final String flowName =
        legacy['name']?.toString() ?? p.basenameWithoutExtension(name);
    final StringBuffer yaml = StringBuffer()
      ..writeln('# ${legacy['title'] ?? flowName}')
      ..writeln('steps:');
    final Map<String, Object?> metaSteps = <String, Object?>{};
    int yamlIndex = -1;
    for (final Object? raw
        in (legacy['steps'] as List<Object?>?) ?? <Object?>[]) {
      final Map<String, Object?> step = Map<String, Object?>.from(raw as Map);
      final String action = step['action']?.toString() ?? 'unknown';
      if (action == 'screenshot') {
        final String? capture = (step['file'] ?? step['capture'])?.toString();
        if (capture != null && yamlIndex >= 0) {
          final Map<String, Object?> metadata = Map<String, Object?>.from(
            metaSteps['$yamlIndex'] as Map? ?? <String, Object?>{},
          );
          metadata['capture'] = capture;
          metaSteps['$yamlIndex'] = metadata;
        }
        continue;
      }
      yamlIndex++;
      final Map<String, Object?> metadata = <String, Object?>{};
      if (step['target'] != null) metadata['target'] = step['target'];
      if (step['screen'] != null) metadata['screen'] = step['screen'];
      if (step['note'] != null) metadata['note'] = step['note'];
      if (metadata.isNotEmpty) metaSteps['$yamlIndex'] = metadata;
      switch (action) {
        case 'open_url':
          yaml
            ..writeln('  - tool: open-url')
            ..writeln('    args:')
            ..writeln('      url: ${_quote(step['url'])}');
        case 'wait':
          final int ms =
              (((step['seconds'] as num?)?.toDouble() ?? 1) * 1000).round();
          yaml.writeln('  - wait: $ms');
        case 'tap':
          final List<double> point =
              _numbers(step['coordinate']) ?? <double>[0, 0];
          yaml.writeln(
            '  - tap: { x: ${_normalized(point[0], pointSize[0])}, '
            'y: ${_normalized(point[1], pointSize[1])} }',
          );
        case 'swipe':
          final List<double> from = _numbers(step['from']) ?? <double>[0, 0];
          final List<double> to = _numbers(step['to']) ?? <double>[0, 0];
          yaml
            ..writeln('  - tool: gesture-swipe')
            ..writeln(
              '    args: { fromX: ${_normalized(from[0], pointSize[0])}, '
              'fromY: ${_normalized(from[1], pointSize[1])}, '
              'toX: ${_normalized(to[0], pointSize[0])}, '
              'toY: ${_normalized(to[1], pointSize[1])} }',
            );
        case 'type':
          yaml.writeln(
            '  - type: { into: ${_quote(step['target'])}, '
            'text: ${_quote(step['text'])} }',
          );
        default:
          yaml.writeln('  - ${_quote(action)}');
      }
    }
    final Map<String, Object?> meta = <String, Object?>{
      'formatVersion': 2,
      'name': flowName,
      'title': legacy['title'] ?? flowName,
      'route': legacy['route'],
      'device': legacy['device'],
      'recordedAt': legacy['recordedAt'],
      'steps': metaSteps,
      if (legacy['result'] != null) 'result': legacy['result'],
    };
    File(p.join(flows.path, '$flowName.yaml'))
        .writeAsStringSync(yaml.toString());
    File(p.join(flows.path, '$flowName.meta.json')).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(meta)}\n',
    );
    if (deleteLegacy) {
      file.deleteSync();
    }
    converted++;
  }
  return ConvertFlowsResult(converted: converted);
}

List<double>? _numbers(Object? value) => value is List
    ? value.whereType<num>().map((num number) => number.toDouble()).toList()
    : null;

double _normalized(double value, double extent) =>
    double.parse((value / extent).toStringAsFixed(4));

String _quote(Object? value) =>
    '"${(value ?? '').toString().replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
