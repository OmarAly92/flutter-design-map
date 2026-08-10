import 'dart:convert';
import 'dart:io';

import 'package:flutter_map_parser/src/model.dart';
import 'package:path/path.dart' as p;

/// Writes [graph] as pretty JSON to [outPath] (creating parent dirs).
String writeGraphJson({
  required RouteGraph graph,
  required String outPath,
}) {
  final File file = File(outPath);
  file.parent.createSync(recursive: true);
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(graph.toJson())}\n');
  return file.path;
}

String defaultGraphOutPath(String projectRoot) {
  return p.join(projectRoot, '.flutter-map', 'graph.json');
}
