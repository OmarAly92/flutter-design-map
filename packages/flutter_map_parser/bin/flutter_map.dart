import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;

/// Parse routes then pack `.flutter-map` into an `.appmap` bundle.
void main(List<String> arguments) {
  final ArgParser parser = ArgParser()
    ..addOption('out', help: 'Output .appmap path')
    ..addFlag(
      'parse-only',
      negatable: false,
      help: 'Only write graph.json; skip packing.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage.',
    );
  final ArgResults results = parser.parse(arguments);
  if (results['help'] == true) {
    stdout.writeln(
      'Usage: dart run bin/flutter_map.dart [projectRoot] [--out file.appmap]',
    );
    stdout.writeln(parser.usage);
    return;
  }
  final String projectRoot = results.rest.isEmpty
      ? Directory.current.path
      : p.normalize(p.absolute(results.rest.first));
  try {
    final RouteGraph graph = parseProject(projectRoot);
    final String graphPath = defaultGraphOutPath(projectRoot);
    writeGraphJson(graph: graph, outPath: graphPath);
    stdout.writeln('wrote $graphPath');
    stdout.writeln(
      'summary: routes=${graph.routes.length} edges=${graph.edges.length} '
      'mode=${graph.mode} scheme=${graph.scheme}',
    );
    if (results['parse-only'] == true) {
      return;
    }
    final PackResult packed = packMap(
      projectRoot: projectRoot,
      outPath: results['out'] as String?,
    );
    final int kb = (packed.bytes / 1024).round();
    stdout.writeln(
      'wrote ${packed.outPath} ($kb KB, ${packed.nodeCount} nodes, '
      '${packed.edgeCount} edges)',
    );
  } catch (error) {
    stderr.writeln('error: $error');
    exitCode = 1;
  }
}
