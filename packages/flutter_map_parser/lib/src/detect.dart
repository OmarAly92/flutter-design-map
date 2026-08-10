import 'dart:io';

import 'package:path/path.dart' as p;

/// Routing modes supported by the parser.
enum RoutingMode {
  goRouter,
  goRouterBuilder,
  autoRoute,
  navigator,
  navigator2,
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
  bool hasNavigatorNamedRoutes = false;
  bool hasNavigator2 = false;
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
    if (_hasNavigatorNamedRoutes(source)) {
      hasNavigatorNamedRoutes = true;
    }
    if (_hasNavigator2(source)) {
      hasNavigator2 = true;
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
  if (hasNavigatorNamedRoutes) {
    return RoutingMode.navigator;
  }
  if (hasNavigator2) {
    return RoutingMode.navigator2;
  }
  return RoutingMode.unknown;
}

bool _hasNavigatorNamedRoutes(String source) {
  final bool hasApp = source.contains('MaterialApp(') ||
      source.contains('CupertinoApp(');
  if (!hasApp) {
    return false;
  }
  if (source.contains('MaterialApp.router') ||
      source.contains('CupertinoApp.router')) {
    return false;
  }
  return source.contains('routes:') || source.contains('onGenerateRoute:');
}

bool _hasNavigator2(String source) {
  if (source.contains('MaterialApp.router') ||
      source.contains('CupertinoApp.router')) {
    return true;
  }
  if (source.contains('extends RouterDelegate') ||
      source.contains('RouterDelegate<')) {
    return true;
  }
  return source.contains('pages:') && source.contains('Navigator(');
}

String routingModeLabel(RoutingMode mode) {
  switch (mode) {
    case RoutingMode.goRouter:
      return 'go_router';
    case RoutingMode.goRouterBuilder:
      return 'go_router_builder';
    case RoutingMode.autoRoute:
      return 'auto_route';
    case RoutingMode.navigator:
      return 'navigator';
    case RoutingMode.navigator2:
      return 'navigator_2';
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
