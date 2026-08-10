import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;

void main(List<String> arguments) {
  final ArgParser parser = ArgParser()
    ..addOption('out', help: 'Output HTML path')
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults results = parser.parse(arguments);
  if (results['help'] == true) {
    stdout.writeln(
        'Usage: dart run bin/render_map.dart [projectRoot] [--out map.html]');
    stdout.writeln(parser.usage);
    return;
  }
  final String projectRoot = results.rest.isEmpty
      ? Directory.current.path
      : p.normalize(p.absolute(results.rest.first));
  try {
    final RenderResult result = renderStaticMap(
      projectRoot: projectRoot,
      outPath: results['out'] as String?,
    );
    stdout.writeln(
      'wrote ${result.outPath} '
      '(${result.routeCount} routes, ${result.captureCount} captures)',
    );
  } catch (error) {
    stderr.writeln('error: $error');
    exitCode = 1;
  }
}
