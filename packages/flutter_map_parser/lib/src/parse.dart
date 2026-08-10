import 'package:flutter_map_parser/src/detect.dart';
import 'package:flutter_map_parser/src/edges.dart';
import 'package:flutter_map_parser/src/hints.dart';
import 'package:flutter_map_parser/src/model.dart';
import 'package:flutter_map_parser/src/modes/go_router.dart';
import 'package:flutter_map_parser/src/modes/go_router_builder.dart';
import 'package:flutter_map_parser/src/scheme.dart';
import 'package:path/path.dart' as p;

/// Parses a Flutter project into an expo-map-compatible [RouteGraph].
RouteGraph parseProject(String projectRoot) {
  final String resolvedRoot = p.normalize(p.absolute(projectRoot));
  final RoutingMode mode = detectRoutingMode(resolvedRoot);
  if (mode == RoutingMode.unknown) {
    throw StateError(
      'No supported Flutter router found in $resolvedRoot '
      '(looked for GoRouter / go_router_builder / auto_route).',
    );
  }
  if (mode == RoutingMode.autoRoute) {
    throw UnsupportedError(
      'Routing mode ${routingModeLabel(mode)} is planned but not implemented yet.',
    );
  }
  final List<RouteNode> routes;
  final List<LayoutNode> layouts;
  final String? routerFile;
  if (mode == RoutingMode.goRouterBuilder) {
    final GoRouterBuilderParseResult parsed =
        parseGoRouterBuilderProject(resolvedRoot);
    routes = parsed.routes;
    layouts = parsed.layouts;
    routerFile = parsed.routerFile;
    if (routes.isEmpty) {
      throw StateError(
        'go_router_builder was detected but no @TypedGoRoute entries were found.',
      );
    }
  } else {
    final GoRouterParseResult parsed = parseGoRouterProject(resolvedRoot);
    routes = parsed.routes;
    layouts = parsed.layouts;
    routerFile = parsed.routerFile;
    if (routes.isEmpty) {
      throw StateError('GoRouter was detected but no GoRoute entries were found.');
    }
  }
  applyHintsToRoutes(routes: routes, projectRoot: resolvedRoot);
  final List<Edge> edges = extractEdges(
    projectRoot: resolvedRoot,
    routes: routes,
  );
  final String? scheme = readDeepLinkScheme(resolvedRoot);
  return RouteGraph(
    generatedAt: DateTime.now().toUtc().toIso8601String(),
    projectRoot: resolvedRoot,
    scheme: scheme,
    deepLinkTemplates: buildDeepLinkTemplates(scheme),
    mode: routingModeLabel(mode),
    layouts: layouts,
    routes: routes,
    edges: edges,
    extras: <String, Object?>{
      if (routerFile != null) 'routerFile': routerFile,
    },
  );
}
