import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;

void main(List<String> arguments) {
  final ArgParser parser = ArgParser()
    ..addFlag(
      'parse',
      defaultsTo: true,
      help: 'Parse routes into graph.json before preparing explore artifacts.',
    )
    ..addOption(
      'wait-ms',
      defaultsTo: '1500',
      help: 'Default wait after open-url in generated deep-link flows.',
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
      'Usage: dart run bin/prepare_explore.dart [projectRoot] [--no-parse]',
    );
    stdout.writeln(parser.usage);
    return;
  }
  final String projectRoot = results.rest.isEmpty
      ? Directory.current.path
      : p.normalize(p.absolute(results.rest.first));
  try {
    if (results['parse'] == true) {
      final RouteGraph graph = parseProject(projectRoot);
      final String graphPath = defaultGraphOutPath(projectRoot);
      writeGraphJson(graph: graph, outPath: graphPath);
      stdout.writeln('wrote $graphPath');
    }
    final int waitMs = int.parse(results['wait-ms'] as String);
    final ExplorePrepareResult prepared = prepareExplore(
      projectRoot: projectRoot,
      waitMs: waitMs,
    );
    stdout.writeln(
      'prepared ${prepared.routeCount} routes, '
      '${prepared.flowCount} deep-link flows',
    );
    stdout.writeln('plan: ${prepared.planPath}');
    stdout.writeln('capture-status: ${prepared.captureStatusPath}');
  } catch (error) {
    stderr.writeln('error: $error');
    exitCode = 1;
  }
}
