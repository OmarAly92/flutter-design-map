/// Graph models matching expo-map's working `graph.json` contract.
library;

class StateHint {
  const StateHint({
    required this.type,
    this.lib,
    this.snapPoints,
    this.presentation,
  });

  final String type;
  final String? lib;
  final List<String>? snapPoints;
  final String? presentation;

  Map<String, Object?> toJson() {
    final Map<String, Object?> json = <String, Object?>{'type': type};
    if (lib != null) {
      json['lib'] = lib;
    }
    if (snapPoints != null) {
      json['snapPoints'] = snapPoints;
    }
    if (presentation != null) {
      json['presentation'] = presentation;
    }
    return json;
  }
}

class RouteNode {
  RouteNode({
    required this.id,
    required this.urlPath,
    required this.file,
    required this.slug,
    required this.params,
    this.navigator,
    this.layoutDir,
    this.presentation,
    this.widgetName,
    List<StateHint>? stateHints,
  }) : stateHints = stateHints ?? <StateHint>[];

  final String id;
  final String urlPath;
  final String file;
  final String slug;
  final List<String> params;
  final String? navigator;
  final String? layoutDir;
  final String? presentation;
  final String? widgetName;
  final List<StateHint> stateHints;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'file': file,
      'urlPath': urlPath,
      'slug': slug,
      'params': params,
      'navigator': navigator,
      'layoutDir': layoutDir,
      'presentation': presentation,
      if (widgetName != null) 'widgetName': widgetName,
      'stateHints': stateHints.map((StateHint hint) => hint.toJson()).toList(),
    };
  }
}

class LayoutNode {
  const LayoutNode({
    required this.file,
    required this.dir,
    this.navigator,
  });

  final String file;
  final String dir;
  final String? navigator;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'file': file,
      'dir': dir,
      'navigator': navigator,
    };
  }
}

class Edge {
  const Edge({
    required this.from,
    required this.to,
    required this.raw,
    required this.target,
  });

  final String from;
  final String? to;
  final String raw;
  final String target;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'from': from,
      'to': to,
      'raw': raw,
      'target': target,
    };
  }
}

class RouteGraph {
  RouteGraph({
    required this.generatedAt,
    required this.projectRoot,
    required this.scheme,
    required this.deepLinkTemplates,
    required this.mode,
    required this.layouts,
    required this.routes,
    required this.edges,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};

  final String generatedAt;
  final String projectRoot;
  final String? scheme;
  final Map<String, String?> deepLinkTemplates;
  final String mode;
  final List<LayoutNode> layouts;
  final List<RouteNode> routes;
  final List<Edge> edges;
  final Map<String, Object?> extras;

  Map<String, Object?> get summary {
    return <String, Object?>{
      'mode': mode,
      'routes': routes.length,
      'layouts': layouts.length,
      'edges': edges.length,
      'unresolvedEdges': edges.where((Edge edge) => edge.to == null).length,
      'routesWithStateHints':
          routes.where((RouteNode route) => route.stateHints.isNotEmpty).length,
      'routesNeedingParams':
          routes.where((RouteNode route) => route.params.isNotEmpty).length,
    };
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'generatedAt': generatedAt,
      'projectRoot': projectRoot,
      'scheme': scheme,
      'deepLinkTemplates': deepLinkTemplates,
      'mode': mode,
      ...extras,
      'layouts': layouts.map((LayoutNode layout) => layout.toJson()).toList(),
      'routes': routes.map((RouteNode route) => route.toJson()).toList(),
      'edges': edges.map((Edge edge) => edge.toJson()).toList(),
      'summary': summary,
    };
  }
}
