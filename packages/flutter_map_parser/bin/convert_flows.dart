import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;

void main(List<String> arguments) {
  final ArgParser parser = ArgParser()
    ..addOption('point-size', defaultsTo: '402x874')
    ..addFlag('delete-v1', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults results = parser.parse(arguments);
  if (results['help'] == true) {
    stdout.writeln('Usage: dart run bin/convert_flows.dart [projectRoot]');
    stdout.writeln(parser.usage);
    return;
  }
  final List<double> pointSize =
      (results['point-size'] as String).split('x').map(double.parse).toList();
  final String projectRoot = results.rest.isEmpty
      ? Directory.current.path
      : p.normalize(p.absolute(results.rest.first));
  try {
    final ConvertFlowsResult result = convertLegacyFlows(
      projectRoot: projectRoot,
      defaultPointSize: pointSize,
      deleteLegacy: results['delete-v1'] == true,
    );
    stdout.writeln('converted ${result.converted} legacy flow(s)');
  } catch (error) {
    stderr.writeln('error: $error');
    exitCode = 1;
  }
}
