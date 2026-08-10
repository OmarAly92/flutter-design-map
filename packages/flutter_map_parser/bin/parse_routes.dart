import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;

void main(List<String> arguments) {
  final ArgParser parser = ArgParser()
    ..addOption(
      'out',
      help: 'Output path for graph.json '
          '(default: <project>/.flutter-map/graph.json)',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage.',
    );
  final ArgResults results = parser.parse(arguments);
  if (results['help'] == true) {
    stdout.writeln('Usage: dart run bin/parse_routes.dart [projectRoot] [--out path]');
    stdout.writeln(parser.usage);
    return;
  }
  final String projectRoot = results.rest.isEmpty
      ? Directory.current.path
      : p.normalize(p.absolute(results.rest.first));
  final String outPath = results['out'] as String? ??
      defaultGraphOutPath(projectRoot);
  try {
    final RouteGraph graph = parseProject(projectRoot);
    final String written = writeGraphJson(graph: graph, outPath: outPath);
    stdout.writeln('wrote $written');
    stdout.writeln(jsonEncode(graph.summary));
  } catch (error) {
    stderr.writeln('error: $error');
    exitCode = 1;
  }
}
