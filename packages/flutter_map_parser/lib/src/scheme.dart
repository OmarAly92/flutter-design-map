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
    'iosSim': scheme == null ? null : '$scheme://<urlPath minus leading slash>',
    'androidEmu':
        scheme == null ? null : '$scheme://<urlPath minus leading slash>',
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
  for (final String path in candidates) {
    final File file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final String source = file.readAsStringSync();
    final RegExpMatch? match =
        RegExp(r'android:scheme\s*=\s*"([A-Za-z0-9._+-]+)"').firstMatch(source);
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
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
    final RegExpMatch? match = RegExp(
      r'<key>CFBundleURLSchemes</key>\s*<array>\s*<string>([^<]+)</string>',
      multiLine: true,
    ).firstMatch(source);
    if (match != null) {
      return match.group(1)?.trim();
    }
  }
  return null;
}

String? _readDartSchemeFallback(String projectRoot) {
  final Directory libDirectory = Directory(p.join(projectRoot, 'lib'));
  if (!libDirectory.existsSync()) {
    return null;
  }
  for (final FileSystemEntity entity
      in libDirectory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final String source = entity.readAsStringSync();
    final RegExpMatch? match =
        RegExp(r'''["']([A-Za-z0-9._+-]+)://''').firstMatch(source);
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}
