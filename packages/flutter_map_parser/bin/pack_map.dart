import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;

void main(List<String> arguments) {
  final ArgParser parser = ArgParser()
    ..addOption(
      'out',
      help: 'Output .appmap path '
          '(default: <project>/.flutter-map/<app>-<date>.appmap)',
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
      'Usage: dart run bin/pack_map.dart [projectRoot] [--out file.appmap]',
    );
    stdout.writeln(parser.usage);
    return;
  }
  final String projectRoot = results.rest.isEmpty
      ? Directory.current.path
      : p.normalize(p.absolute(results.rest.first));
  try {
    final PackResult packed = packMap(
      projectRoot: projectRoot,
      outPath: results['out'] as String?,
    );
    final int kb = (packed.bytes / 1024).round();
    stdout.writeln(
      'wrote ${packed.outPath} ($kb KB, ${packed.nodeCount} nodes, '
      '${packed.edgeCount} edges, ${packed.flowCount} flows, '
      '${packed.screenshotCount} screenshots)',
    );
  } catch (error) {
    stderr.writeln('error: $error');
    exitCode = 1;
  }
}
