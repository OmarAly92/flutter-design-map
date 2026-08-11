import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads the deep-link scheme from Android / iOS platform config.
String? readDeepLinkScheme(String projectRoot) {
  final String? androidScheme = _readAndroidScheme(projectRoot);
  if (androidScheme != null) {
    return androidScheme;
  }
  final String? iosScheme = _readIosScheme(projectRoot);
  if (iosScheme != null) {
    return iosScheme;
  }
  return _readDartSchemeFallback(projectRoot);
}

Map<String, String?> buildDeepLinkTemplates(String? scheme) {
  return <String, String?>{
    'iosSim':
        scheme == null ? null : '$scheme:///<urlPath minus leading slash>',
    'androidEmu':
        scheme == null ? null : '$scheme:///<urlPath minus leading slash>',
  };
}

String? _readAndroidScheme(String projectRoot) {
  final List<String> candidates = <String>[
    p.join(
      projectRoot,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
    p.join(projectRoot, 'android', 'AndroidManifest.xml'),
  ];
  final List<String> schemes = <String>[];
  for (final String path in candidates) {
    final File file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final String source = file.readAsStringSync();
    for (final RegExpMatch match
        in RegExp(r'android:scheme\s*=\s*"([A-Za-z0-9._+-]+)"')
            .allMatches(source)) {
      final String scheme = match.group(1)!;
      if (!_isIgnoredScheme(scheme)) {
        schemes.add(scheme);
      }
    }
  }
  return schemes.isEmpty ? null : schemes.first;
}

String? _readIosScheme(String projectRoot) {
  final List<String> candidates = <String>[
    p.join(projectRoot, 'ios', 'Runner', 'Info.plist'),
    p.join(projectRoot, 'macos', 'Runner', 'Info.plist'),
  ];
  for (final String path in candidates) {
    final File file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final String source = file.readAsStringSync();
    for (final RegExpMatch match in RegExp(
      r'<key>CFBundleURLSchemes</key>\s*<array>(.*?)</array>',
      multiLine: true,
      dotAll: true,
    ).allMatches(source)) {
      final String block = match.group(1)!;
      for (final RegExpMatch stringMatch
          in RegExp(r'<string>([^<]+)</string>').allMatches(block)) {
        final String scheme = stringMatch.group(1)!.trim();
        if (!_isIgnoredScheme(scheme)) {
          return scheme;
        }
      }
    }
  }
  return null;
}

String? _readDartSchemeFallback(String projectRoot) {
  final Directory libDirectory = Directory(p.join(projectRoot, 'lib'));
  if (!libDirectory.existsSync()) {
    return null;
  }
  final Set<String> ignored = <String>{
    'http',
    'https',
    'mailto',
    'tel',
    'ws',
    'wss',
    'file',
    'package',
    'asset',
  };
  for (final FileSystemEntity entity
      in libDirectory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final String source = entity.readAsStringSync();
    for (final RegExpMatch match
        in RegExp(r'''["']([A-Za-z0-9._+-]+)://''').allMatches(source)) {
      final String scheme = match.group(1)!;
      if (!ignored.contains(scheme.toLowerCase())) {
        return scheme;
      }
    }
  }
  return null;
}

bool _isIgnoredScheme(String scheme) {
  const Set<String> ignored = <String>{
    'http',
    'https',
    'mailto',
    'tel',
    'ws',
    'wss',
    'file',
  };
  return ignored.contains(scheme.toLowerCase());
}
