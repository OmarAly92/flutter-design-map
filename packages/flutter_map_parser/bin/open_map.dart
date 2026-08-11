import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  final ArgParser parser = ArgParser()
    ..addOption('map', help: 'Explicit .appmap path (default: newest in '
        '<project>/.flutter-map)')
    ..addOption('device', defaultsTo: 'chrome', help: 'Flutter device id')
    ..addFlag('no-run',
        negatable: false,
        help: 'Copy the map into the visualiser and stop, without launching it')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');
  final ArgResults results = parser.parse(arguments);
  if (results['help'] == true) {
    stdout.writeln(
      'Usage: dart run bin/open_map.dart [projectRoot] [--map file.appmap] '
      '[--device chrome] [--no-run]',
    );
    stdout.writeln(parser.usage);
    return;
  }

  final String projectRoot = results.rest.isEmpty
      ? Directory.current.path
      : p.normalize(p.absolute(results.rest.first));

  try {
    final File bundle = _resolveBundle(projectRoot, results['map'] as String?);
    final Directory visualiser = _resolveVisualiser();
    final File target = File(p.join(visualiser.path, 'web', 'app.appmap'));
    bundle.copySync(target.path);
    final int kb = (bundle.lengthSync() / 1024).round();
    stdout.writeln('using ${bundle.path} ($kb KB)');

    if (results['no-run'] == true) {
      stdout.writeln('copied to ${target.path}');
      return;
    }

    final String device = results['device'] as String;
    stdout.writeln('launching visualiser on $device...');
    final Process process = await Process.start(
      'flutter',
      <String>['run', '-d', device],
      workingDirectory: visualiser.path,
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await process.exitCode;
  } catch (error) {
    stderr.writeln('error: $error');
    exitCode = 1;
  }
}

File _resolveBundle(String projectRoot, String? explicit) {
  if (explicit != null) {
    final File file = File(p.normalize(p.absolute(explicit)));
    if (!file.existsSync()) {
      throw StateError('no .appmap at ${file.path}');
    }
    return file;
  }
  final Directory dir = Directory(p.join(projectRoot, '.flutter-map'));
  if (!dir.existsSync()) {
    throw StateError(
      'no .flutter-map in $projectRoot — run bin/flutter_map.dart first',
    );
  }
  final List<File> bundles = dir
      .listSync()
      .whereType<File>()
      .where((File f) => p.extension(f.path) == '.appmap')
      .toList()
    ..sort((File a, File b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
  if (bundles.isEmpty) {
    throw StateError(
      'no .appmap in ${dir.path} — run bin/pack_map.dart first',
    );
  }
  return bundles.first;
}

Directory _resolveVisualiser() {
  final String? pluginRoot = Platform.environment['CLAUDE_PLUGIN_ROOT'];
  final List<String> candidates = <String>[
    if (pluginRoot != null) p.join(pluginRoot, 'apps', 'flutter_map_visualiser'),
    p.normalize(
      p.join(
        p.dirname(p.fromUri(Platform.script)),
        '..',
        '..',
        '..',
        'apps',
        'flutter_map_visualiser',
      ),
    ),
  ];
  for (final String candidate in candidates) {
    if (File(p.join(candidate, 'pubspec.yaml')).existsSync()) {
      return Directory(candidate);
    }
  }
  throw StateError(
    'could not locate apps/flutter_map_visualiser (looked in: '
    '${candidates.join(", ")})',
  );
}
