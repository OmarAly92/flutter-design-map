import 'dart:io';

import 'package:flutter_map_parser/src/model.dart';
import 'package:path/path.dart' as p;

/// Extracts navigation edges from Dart sources for known [routes].
List<Edge> extractEdges({
  required String projectRoot,
  required List<RouteNode> routes,
}) {
  final Map<String, RouteNode> byId = <String, RouteNode>{
    for (final RouteNode route in routes) route.id: route,
  };
  final Map<String, RouteNode> byFile = <String, RouteNode>{
    for (final RouteNode route in routes) route.file: route,
  };
  final List<_Matcher> matchers =
      routes.map((_Matcher.new)).toList(growable: false);
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
    final String relative =
        p.relative(entity.path, from: projectRoot).replaceAll(r'\', '/');
    final RouteNode? fromRoute = byFile[relative];
    if (fromRoute == null) {
      continue;
    }
    final String source = entity.readAsStringSync();
    final Set<String> seen = <String>{};
    for (final RegExpMatch match in _pathNavPattern.allMatches(source)) {
      final String raw = match.group(0)!;
      final String target = match.group(1)!;
      if (_isExternal(target)) {
        continue;
      }
      final String normalized = _normalizeTarget(target, fromRoute.urlPath);
      final String key = 'path:$raw|$normalized';
      if (!seen.add(key)) {
        continue;
      }
      final RouteNode? hit = _matchRoute(matchers, normalized);
      edges.add(
        Edge(
          from: fromRoute.id,
          to: hit?.id,
          raw: raw,
          target: normalized,
        ),
      );
    }
    for (final RegExpMatch match in _namedNavPattern.allMatches(source)) {
      final String raw = match.group(0)!;
      final String name = match.group(1)!;
      final String key = 'named:$name';
      if (!seen.add(key)) {
        continue;
      }
      final RouteNode? hit = byId[name];
      edges.add(
        Edge(
          from: fromRoute.id,
          to: hit?.id,
          raw: raw,
          target: hit?.urlPath ?? name,
        ),
      );
    }
    for (final RegExpMatch match in _typedNavPattern.allMatches(source)) {
      final String raw = match.group(0)!;
      final String typeName = match.group(1)!;
      final String key = 'typed:$typeName';
      if (!seen.add(key)) {
        continue;
      }
      final RouteNode? hit = byId[typeName];
      edges.add(
        Edge(
          from: fromRoute.id,
          to: hit?.id,
          raw: raw.trim(),
          target: hit?.urlPath ?? typeName,
        ),
      );
    }
    for (final RegExpMatch match in _autoRouteNavPattern.allMatches(source)) {
      final String raw = match.group(0)!;
      final String typeName = match.group(1)!;
      final String key = 'auto:$typeName';
      if (!seen.add(key)) {
        continue;
      }
      final RouteNode? hit = byId[typeName];
      edges.add(
        Edge(
          from: fromRoute.id,
          to: hit?.id,
          raw: raw.trim(),
          target: hit?.urlPath ?? typeName,
        ),
      );
    }
  }
  return edges;
}

final RegExp _pathNavPattern = RegExp(
  r"""(?:context|(?:GoRouter\.of\(\s*context\s*\)))\.(?:go|push|replace)\(\s*['"]([^'"]+)['"]\s*\)""",
);

final RegExp _namedNavPattern = RegExp(
  r"""(?:context|(?:GoRouter\.of\(\s*context\s*\)))\.(?:goNamed|pushNamed|replaceNamed)\(\s*['"]([^'"]+)['"]""",
);

final RegExp _typedNavPattern = RegExp(
  r'''(?:const\s+)?([A-Z][A-Za-z0-9_]*)\s*\([^)]*\)\s*\.\s*(?:go|push|replace)\(\s*context\s*\)''',
);

final RegExp _autoRouteNavPattern = RegExp(
  r'''(?:context\.router|context)\.(?:push|navigate|replace|popAndPush|pushRoute|navigateTo|replaceRoute)\(\s*(?:const\s+)?([A-Z][A-Za-z0-9_]*)\s*\(''',
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
  final String normalizedProbe = probe.replaceAll(RegExp(r'\$\{[^}]*\}'), 'X');
  for (final _Matcher matcher in matchers) {
    if (matcher.pattern.hasMatch(normalizedProbe)) {
      return matcher.route;
    }
  }
  return null;
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
