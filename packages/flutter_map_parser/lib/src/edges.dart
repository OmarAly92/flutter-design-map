import 'dart:io';

import 'package:flutter_map_parser/src/model.dart';
import 'package:flutter_map_parser/src/path_index.dart';
import 'package:path/path.dart' as p;

/// Extracts navigation edges from Dart sources for known [routes].
List<Edge> extractEdges({
  required String projectRoot,
  required List<RouteNode> routes,
}) {
  final Map<String, RouteNode> byId = <String, RouteNode>{
    for (final RouteNode route in routes) route.id: route,
  };
  final Map<String, List<RouteNode>> byFile = <String, List<RouteNode>>{};
  for (final RouteNode route in routes) {
    if (route.file.isEmpty) {
      continue;
    }
    byFile.putIfAbsent(route.file, () => <RouteNode>[]).add(route);
  }
  final List<_Matcher> matchers =
      routes.map((_Matcher.new)).toList(growable: false);
  final ProjectPathIndex pathIndex = ProjectPathIndex.fromProject(projectRoot);
  final List<Edge> edges = <Edge>[];
  final Directory libDirectory = Directory(p.join(projectRoot, 'lib'));
  if (!libDirectory.existsSync()) {
    return edges;
  }
  for (final FileSystemEntity entity
      in libDirectory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.endsWith('.g.dart') || entity.path.endsWith('.gr.dart')) {
      continue;
    }
    final String relative =
        p.relative(entity.path, from: projectRoot).replaceAll(r'\', '/');
    final String source = entity.readAsStringSync();
    final Set<String> seen = <String>{};
    for (final RegExpMatch match in _pathNavPattern.allMatches(source)) {
      final RouteNode? from = _fromForMatch(
        source: source,
        offset: match.start,
        relativeFile: relative,
        byFile: byFile,
        routes: routes,
      );
      if (from == null) {
        continue;
      }
      final String rawTarget = match.group(1)!;
      final String? target = rawTarget.contains(r'$')
          ? pathIndex.resolveInterpolatedLiteral(rawTarget)
          : rawTarget;
      if (target == null) {
        continue;
      }
      _addEdge(
        edges: edges,
        seen: seen,
        fromRoute: from,
        matchers: matchers,
        raw: match.group(0)!,
        target: target,
        dedupeKey: 'path:$target',
      );
    }
    for (final RegExpMatch match in _namedNavPattern.allMatches(source)) {
      final RouteNode? from = _fromForMatch(
        source: source,
        offset: match.start,
        relativeFile: relative,
        byFile: byFile,
        routes: routes,
      );
      if (from == null) {
        continue;
      }
      final String name = match.group(1)!;
      final String key = '${from.id}:named:$name';
      if (!seen.add(key)) {
        continue;
      }
      final RouteNode? hit = byId[name];
      edges.add(
        Edge(
          from: from.id,
          to: hit?.id,
          raw: match.group(0)!.trim(),
          target: hit?.urlPath ?? name,
        ),
      );
    }
    for (final RegExpMatch match in _typedNavPattern.allMatches(source)) {
      final RouteNode? from = _fromForMatch(
        source: source,
        offset: match.start,
        relativeFile: relative,
        byFile: byFile,
        routes: routes,
      );
      if (from == null) {
        continue;
      }
      final String typeName = match.group(1)!;
      final String key = '${from.id}:typed:$typeName';
      if (!seen.add(key)) {
        continue;
      }
      final RouteNode? hit = byId[typeName];
      edges.add(
        Edge(
          from: from.id,
          to: hit?.id,
          raw: match.group(0)!.trim(),
          target: hit?.urlPath ?? typeName,
        ),
      );
    }
    for (final RegExpMatch match in _autoRouteNavPattern.allMatches(source)) {
      _addTypedRouteEdge(
        edges: edges,
        seen: seen,
        byId: byId,
        source: source,
        offset: match.start,
        relativeFile: relative,
        byFile: byFile,
        routes: routes,
        raw: match.group(0)!,
        typeName: match.group(1)!,
        kind: 'auto',
      );
    }
    for (final RegExpMatch match
        in _autoRouteReplaceAllPattern.allMatches(source)) {
      final String listBody = match.group(1) ?? '';
      for (final RegExpMatch routeMatch
          in _autoRouteTypeInListPattern.allMatches(listBody)) {
        _addTypedRouteEdge(
          edges: edges,
          seen: seen,
          byId: byId,
          source: source,
          offset: match.start + routeMatch.start,
          relativeFile: relative,
          byFile: byFile,
          routes: routes,
          raw: match.group(0)!,
          typeName: routeMatch.group(1)!,
          kind: 'auto-replaceAll',
        );
      }
    }
    for (final RegExpMatch match
        in _navigatorScreenPattern.allMatches(source)) {
      final String widgetName = match.group(1)!;
      final String routeId = _widgetNameToRouteId(widgetName);
      final RouteNode? hit = byId[routeId] ?? byId[widgetName];
      if (hit == null) {
        continue;
      }
      final RouteNode? from = _fromForMatch(
        source: source,
        offset: match.start,
        relativeFile: relative,
        byFile: byFile,
        routes: routes,
      );
      if (from == null) {
        continue;
      }
      final String key = '${from.id}:navigator:$routeId';
      if (!seen.add(key)) {
        continue;
      }
      edges.add(
        Edge(
          from: from.id,
          to: hit.id,
          raw: match.group(0)!.trim().replaceAll(RegExp(r'\s+'), ' '),
          target: hit.urlPath,
        ),
      );
    }
    for (final RegExpMatch match in _helperNavPattern.allMatches(source)) {
      final RouteNode? from = _fromForMatch(
        source: source,
        offset: match.start,
        relativeFile: relative,
        byFile: byFile,
        routes: routes,
      );
      if (from == null) {
        continue;
      }
      final String raw = match.group(0)!;
      final String? reference = match.group(1) ??
          (match.group(2) != null && match.group(3) != null
              ? '${match.group(2)}.${match.group(3)}'
              : null);
      if (reference == null) {
        continue;
      }
      final String? resolved = pathIndex.resolveReference(reference);
      if (resolved == null) {
        continue;
      }
      _addEdge(
        edges: edges,
        seen: seen,
        fromRoute: from,
        matchers: matchers,
        raw: raw,
        target: resolved,
        dedupeKey: '${from.id}:helper:$reference',
      );
    }
  }
  return edges;
}

void _addEdge({
  required List<Edge> edges,
  required Set<String> seen,
  required RouteNode fromRoute,
  required List<_Matcher> matchers,
  required String raw,
  required String target,
  required String dedupeKey,
}) {
  if (_isExternal(target)) {
    return;
  }
  final String normalized = _normalizeTarget(target, fromRoute.urlPath);
  final String key = '$dedupeKey:$normalized';
  if (!seen.add(key)) {
    return;
  }
  final RouteNode? hit = _matchRoute(matchers, normalized);
  edges.add(
    Edge(
      from: fromRoute.id,
      to: hit?.id,
      raw: raw.trim(),
      target: normalized,
    ),
  );
}

void _addTypedRouteEdge({
  required List<Edge> edges,
  required Set<String> seen,
  required Map<String, RouteNode> byId,
  required String source,
  required int offset,
  required String relativeFile,
  required Map<String, List<RouteNode>> byFile,
  required List<RouteNode> routes,
  required String raw,
  required String typeName,
  required String kind,
}) {
  final RouteNode? from = _fromForMatch(
        source: source,
        offset: offset,
        relativeFile: relativeFile,
        byFile: byFile,
        routes: routes,
      ) ??
      _fallbackFromRoute(routes);
  if (from == null) {
    return;
  }
  final String key = '${from.id}:$kind:$typeName';
  if (!seen.add(key)) {
    return;
  }
  final RouteNode? hit = byId[typeName];
  edges.add(
    Edge(
      from: from.id,
      to: hit?.id,
      raw: raw.trim().replaceAll(RegExp(r'\s+'), ' '),
      target: hit?.urlPath ?? typeName,
    ),
  );
}

RouteNode? _fallbackFromRoute(List<RouteNode> routes) {
  for (final RouteNode route in routes) {
    if (route.urlPath == '/home') {
      return route;
    }
  }
  for (final RouteNode route in routes) {
    if (route.urlPath == '/') {
      return route;
    }
  }
  return routes.isEmpty ? null : routes.first;
}

final RegExp _pathNavPattern = RegExp(
  r"""(?:context|mainRouter|(?:GoRouter\.of\(\s*context\s*\)))\.(?:go|push|replace)\(\s*['"]([^'"]+)['"]""",
);

final RegExp _namedNavPattern = RegExp(
  r"""(?:context|mainRouter|(?:GoRouter\.of\(\s*context\s*\)))\.(?:goNamed|pushNamed|replaceNamed)\(\s*['"]([^'"]+)['"]""",
);

final RegExp _typedNavPattern = RegExp(
  r'''(?:const\s+)?([A-Z][A-Za-z0-9_]*)\s*\([^)]*\)\s*\.\s*(?:go|push|replace)\(\s*context\s*\)''',
);

/// AutoRoute typed navigation:
/// `context.router.push(FooRoute(`, `context.pushRoute(FooRoute(`,
/// `AutoRouter.of(context).push(FooRoute(`, `_appRouter?.push(FooRoute(`.
final RegExp _autoRouteNavPattern = RegExp(
  r'''(?:'''
  r'''AutoRouter\.of\(\s*context\s*\)'''
  r'''|context\.router'''
  r'''|context'''
  r'''|[A-Za-z_][A-Za-z0-9_]*\??'''
  r''')\.(?:push|navigate|replace|popAndPush|pushRoute|navigateTo|replaceRoute)'''
  r'''\(\s*(?:const\s+)?([A-Z][A-Za-z0-9_]*Route)\s*\(''',
);

final RegExp _autoRouteReplaceAllPattern = RegExp(
  r'''(?:AutoRouter\.of\(\s*context\s*\)|context\.router|context|[A-Za-z_][A-Za-z0-9_]*\??)'''
  r'''\.replaceAll\(\s*\[([^\]]*)\]''',
);

final RegExp _autoRouteTypeInListPattern = RegExp(
  r'''(?:const\s+)?([A-Z][A-Za-z0-9_]*Route)\s*\(''',
);

/// `Navigator.of(context).push(... CreateInvoiceScreen(` within a short window.
final RegExp _navigatorScreenPattern = RegExp(
  r'''Navigator\.of\(\s*context[^)]*\)\.push\([\s\S]{0,500}?(?:const\s+)?([A-Z][A-Za-z0-9_]*(?:Screen|Page))\s*\(''',
);

/// `context.go(AppPaths.eventHub)` / `context.push(AppPaths.foo(id))` /
/// `context.go(Routes.settings.root)` / `mainRouter.go(Routes.home)`.
final RegExp _helperNavPattern = RegExp(
  r'''(?:context|mainRouter|(?:GoRouter\.of\(\s*context\s*\)))\.(?:go|push|replace)\(\s*'''
  r'''(?:'''
  r'''([A-Z][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*){1,3})\s*(?=[,)])'''
  r'''|'''
  r'''([A-Z][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*\('''
  r''')''',
);

class _Matcher {
  _Matcher(this.route) : pattern = _routeMatcher(route.urlPath);

  final RouteNode route;
  final RegExp pattern;
}

RegExp _routeMatcher(String urlPath) {
  final String re = urlPath
      .split('/')
      .map((String segment) {
        if (segment.startsWith(':')) {
          return '[^/]+';
        }
        return RegExp.escape(segment);
      })
      .join('/');
  return RegExp('^$re/?\$');
}

RouteNode? _matchRoute(List<_Matcher> matchers, String probe) {
  final String concreteProbe = probe.replaceAllMapped(
    RegExp(r':([A-Za-z_][A-Za-z0-9_]*)'),
    (Match match) => 'X',
  );
  // Prefer exact pattern match against route templates.
  for (final _Matcher matcher in matchers) {
    if (matcher.pattern.hasMatch(probe) ||
        matcher.pattern.hasMatch(concreteProbe)) {
      return matcher.route;
    }
  }
  // Helper templates already use :param — match by comparing templates.
  for (final _Matcher matcher in matchers) {
    if (matcher.route.urlPath == probe) {
      return matcher.route;
    }
  }
  return null;
}

RouteNode? _fromForMatch({
  required String source,
  required int offset,
  required String relativeFile,
  required Map<String, List<RouteNode>> byFile,
  required List<RouteNode> routes,
}) {
  final String? className = _enclosingClassName(source, offset);
  if (className != null) {
    for (final RouteNode route in routes) {
      if (route.widgetName == className) {
        return route;
      }
    }
  }
  final List<RouteNode>? fileRoutes = byFile[relativeFile];
  if (fileRoutes != null && fileRoutes.length == 1) {
    return fileRoutes.first;
  }
  if (fileRoutes != null && fileRoutes.length > 1) {
    if (className != null) {
      for (final RouteNode route in fileRoutes) {
        if (route.widgetName == className) {
          return route;
        }
      }
    }
    return fileRoutes.first;
  }
  return _inferFromRoute(relativeFile, byFile, routes);
}

String? _enclosingClassName(String source, int offset) {
  final Iterable<RegExpMatch> matches =
      RegExp(r'class\s+([A-Za-z_][A-Za-z0-9_]*)').allMatches(source);
  String? name;
  for (final RegExpMatch match in matches) {
    if (match.start > offset) {
      break;
    }
    name = match.group(1);
  }
  return name;
}

RouteNode? _inferFromRoute(
  String relativeFile,
  Map<String, List<RouteNode>> byFile,
  List<RouteNode> routes,
) {
  final RouteNode? screenMatch = _scoreDirectoryMatch(
    relativeFile: relativeFile,
    routes: routes,
    skipSharedRouter: true,
  );
  if (screenMatch != null) {
    return screenMatch;
  }
  // Global handlers (repositories, scaffolds) — last-resort attribution.
  return _scoreDirectoryMatch(
    relativeFile: relativeFile,
    routes: routes,
    skipSharedRouter: false,
  );
}

RouteNode? _scoreDirectoryMatch({
  required String relativeFile,
  required List<RouteNode> routes,
  required bool skipSharedRouter,
}) {
  RouteNode? best;
  int bestScore = -1;
  final String fileDir = p.posix.dirname(relativeFile);
  final String? fileFeature = _featureRoot(relativeFile);
  for (final RouteNode route in routes) {
    if (route.file.isEmpty) {
      continue;
    }
    if (skipSharedRouter && _isSharedRouterFile(route.file)) {
      continue;
    }
    final String routeDir = p.posix.dirname(route.file);
    int score = -1;
    if (fileDir == routeDir || fileDir.startsWith('$routeDir/')) {
      score = routeDir.length * 10;
    } else {
      final String? routeFeature = _featureRoot(route.file);
      if (fileFeature != null &&
          routeFeature != null &&
          fileFeature == routeFeature) {
        score = routeFeature.length * 5;
      }
    }
    if (score > bestScore) {
      best = route;
      bestScore = score;
    }
  }
  return best;
}

String? _featureRoot(String relativeFile) {
  final List<String> parts = p.posix.split(relativeFile);
  final int featuresIndex = parts.indexOf('features');
  if (featuresIndex < 0 || featuresIndex + 1 >= parts.length) {
    return null;
  }
  return p.posix.joinAll(parts.sublist(0, featuresIndex + 2));
}

bool _isSharedRouterFile(String relativeFile) {
  final String base = p.posix.basename(relativeFile);
  return base == 'router.dart' ||
      base == 'routes.dart' ||
      base == 'app_router.dart';
}

String _widgetNameToRouteId(String widgetName) {
  if (widgetName.endsWith('Page')) {
    return '${widgetName.substring(0, widgetName.length - 'Page'.length)}Route';
  }
  if (widgetName.endsWith('Screen')) {
    return '${widgetName.substring(0, widgetName.length - 'Screen'.length)}Route';
  }
  if (widgetName.endsWith('Route')) {
    return widgetName;
  }
  return '${widgetName}Route';
}

bool _isExternal(String target) {
  return RegExp(r'^(https?|mailto|tel):').hasMatch(target);
}

String _normalizeTarget(String raw, String fromPath) {
  String target = raw.split(RegExp(r'[?#]')).first;
  if (target.isEmpty) {
    return '/';
  }
  if (!target.startsWith('/')) {
    final String parent = fromPath == '/' ? '' : p.posix.dirname(fromPath);
    target = p.posix.normalize('$parent/$target');
    if (!target.startsWith('/')) {
      target = '/$target';
    }
  }
  return target;
}
