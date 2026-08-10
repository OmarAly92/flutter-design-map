import 'dart:io';

import 'package:path/path.dart' as p;

/// Routing modes supported by the parser.
enum RoutingMode {
  goRouter,
  goRouterBuilder,
  autoRoute,
  unknown,
}

/// Detects the primary Flutter routing mode for [projectRoot].
RoutingMode detectRoutingMode(String projectRoot) {
  final String pubspecPath = p.join(projectRoot, 'pubspec.yaml');
  final String pubspec =
      File(pubspecPath).existsSync() ? File(pubspecPath).readAsStringSync() : '';
  final bool hasGoRouterDep = RegExp(r'^\s*go_router\s*:', multiLine: true)
      .hasMatch(pubspec);
  final bool hasGoRouterBuilderDep =
      RegExp(r'^\s*go_router_builder\s*:', multiLine: true).hasMatch(pubspec);
  final bool hasAutoRouteDep = RegExp(r'^\s*auto_route\s*:', multiLine: true)
      .hasMatch(pubspec);
  final List<String> dartFiles = _listDartFiles(p.join(projectRoot, 'lib'));
  bool hasGoRouterCall = false;
  bool hasTypedGoRoute = false;
  bool hasAutoRouterConfig = false;
  for (final String filePath in dartFiles) {
    final String source = File(filePath).readAsStringSync();
    if (source.contains('GoRouter(')) {
      hasGoRouterCall = true;
    }
    if (source.contains('@TypedGoRoute') || source.contains('TypedGoRoute<')) {
      hasTypedGoRoute = true;
    }
    if (source.contains('@AutoRouterConfig') ||
        source.contains('AutoRouterConfig')) {
      hasAutoRouterConfig = true;
    }
  }
  if (hasTypedGoRoute || hasGoRouterBuilderDep) {
    return RoutingMode.goRouterBuilder;
  }
  if (hasGoRouterCall || hasGoRouterDep) {
    return RoutingMode.goRouter;
  }
  if (hasAutoRouterConfig || hasAutoRouteDep) {
    return RoutingMode.autoRoute;
  }
  return RoutingMode.unknown;
}

String routingModeLabel(RoutingMode mode) {
  switch (mode) {
    case RoutingMode.goRouter:
      return 'go_router';
    case RoutingMode.goRouterBuilder:
      return 'go_router_builder';
    case RoutingMode.autoRoute:
      return 'auto_route';
    case RoutingMode.unknown:
      return 'unknown';
  }
}

List<String> _listDartFiles(String directoryPath) {
  final Directory directory = Directory(directoryPath);
  if (!directory.existsSync()) {
    return <String>[];
  }
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .map((File file) => file.path)
      .toList();
}
