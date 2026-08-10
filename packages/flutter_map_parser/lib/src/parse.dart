import 'package:flutter_map_parser/src/detect.dart';
import 'package:flutter_map_parser/src/edges.dart';
import 'package:flutter_map_parser/src/hints.dart';
import 'package:flutter_map_parser/src/model.dart';
import 'package:flutter_map_parser/src/modes/go_router.dart';
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
  if (mode == RoutingMode.goRouterBuilder || mode == RoutingMode.autoRoute) {
    throw UnsupportedError(
      'Routing mode ${routingModeLabel(mode)} is planned but not implemented yet. '
      'Use imperative GoRouter for v1.',
    );
  }
  final GoRouterParseResult parsed = parseGoRouterProject(resolvedRoot);
  if (parsed.routes.isEmpty) {
    throw StateError('GoRouter was detected but no GoRoute entries were found.');
  }
  applyHintsToRoutes(routes: parsed.routes, projectRoot: resolvedRoot);
  final List<Edge> edges = extractEdges(
    projectRoot: resolvedRoot,
    routes: parsed.routes,
  );
  final String? scheme = readDeepLinkScheme(resolvedRoot);
  return RouteGraph(
    generatedAt: DateTime.now().toUtc().toIso8601String(),
    projectRoot: resolvedRoot,
    scheme: scheme,
    deepLinkTemplates: buildDeepLinkTemplates(scheme),
    mode: routingModeLabel(mode),
    layouts: parsed.layouts,
    routes: parsed.routes,
    edges: edges,
    extras: <String, Object?>{
      if (parsed.routerFile != null) 'routerFile': parsed.routerFile,
    },
  );
}
