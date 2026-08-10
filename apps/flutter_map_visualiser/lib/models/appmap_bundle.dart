import 'dart:typed_data';

/// Parsed v2 `.appmap` bundle ready for the visualiser.
class AppMapBundle {
  const AppMapBundle({
    required this.manifest,
    required this.nodes,
    required this.edges,
    required this.flows,
    required this.screenshots,
  });

  final AppMapManifest manifest;
  final List<AppMapNode> nodes;
  final List<AppMapEdge> edges;
  final List<AppMapFlow> flows;
  final Map<String, Uint8List> screenshots;

  int get capturedCount => nodes
      .where(
        (AppMapNode node) =>
            node.capture.status == 'ok' || node.capture.status == 'empty-state',
      )
      .length;

  AppMapNode? nodeById(String id) {
    for (final AppMapNode node in nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }

  AppMapFlow? flowByName(String name) {
    for (final AppMapFlow flow in flows) {
      if (flow.name == name) {
        return flow;
      }
    }
    return null;
  }
}

class AppMapManifest {
  const AppMapManifest({
    required this.formatVersion,
    required this.generator,
    required this.appName,
    required this.scheme,
    required this.platform,
    required this.mode,
    required this.generatedAt,
    this.device,
    this.flowFormat,
  });

  factory AppMapManifest.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> app = Map<String, Object?>.from(
      json['app'] as Map? ?? <String, Object?>{},
    );
    return AppMapManifest(
      formatVersion: (json['formatVersion'] as num?)?.toInt() ?? 1,
      generator: json['generator'] as String? ?? 'unknown',
      appName: app['name'] as String? ?? 'app',
      scheme: app['scheme'] as String?,
      platform: app['platform'] as String?,
      mode: app['mode'] as String?,
      generatedAt: json['generatedAt'] as String?,
      device: app['device'] as String?,
      flowFormat: json['flowFormat'] as String?,
    );
  }

  final int formatVersion;
  final String generator;
  final String appName;
  final String? scheme;
  final String? platform;
  final String? mode;
  final String? generatedAt;
  final String? device;
  final String? flowFormat;
}

class AppMapNode {
  const AppMapNode({
    required this.id,
    required this.urlPath,
    required this.file,
    required this.slug,
    required this.group,
    required this.params,
    required this.capture,
    this.navigator,
    this.presentation,
    this.stateHints = const <Map<String, Object?>>[],
  });

  factory AppMapNode.fromJson(Map<String, Object?> json) {
    return AppMapNode(
      id: json['id'] as String? ?? '',
      urlPath: json['urlPath'] as String? ?? '/',
      file: json['file'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      group: json['group'] as String? ?? '',
      navigator: json['navigator'] as String?,
      presentation: json['presentation'] as String?,
      stateHints: ((json['stateHints'] as List<Object?>?) ?? <Object?>[])
          .whereType<Map>()
          .map((Map raw) => Map<String, Object?>.from(raw))
          .toList(),
      params: ((json['params'] as List<Object?>?) ?? <Object?>[])
          .map((Object? item) => item.toString())
          .toList(),
      capture: CaptureInfo.fromJson(
        Map<String, Object?>.from(
          json['capture'] as Map? ?? <String, Object?>{},
        ),
      ),
    );
  }

  final String id;
  final String urlPath;
  final String file;
  final String slug;
  final String group;
  final String? navigator;
  final String? presentation;
  final List<Map<String, Object?>> stateHints;
  final List<String> params;
  final CaptureInfo capture;
}

class CaptureInfo {
  const CaptureInfo({
    required this.status,
    required this.needsNavigation,
    required this.states,
    this.note,
    this.screenshot,
  });

  factory CaptureInfo.fromJson(Map<String, Object?> json) {
    final List<Object?> states =
        (json['states'] as List<Object?>?) ?? <Object?>[];
    return CaptureInfo(
      status: json['status'] as String? ?? 'missing',
      note: json['note'] as String?,
      needsNavigation: json['needsNavigation'] as bool? ?? false,
      screenshot: json['screenshot'] as String?,
      states: states
          .whereType<Map>()
          .map(
            (Map raw) => CaptureState.fromJson(Map<String, Object?>.from(raw)),
          )
          .toList(),
    );
  }

  final String status;
  final String? note;
  final bool needsNavigation;
  final String? screenshot;
  final List<CaptureState> states;
}

class CaptureState {
  const CaptureState({required this.name, required this.screenshot});

  factory CaptureState.fromJson(Map<String, Object?> json) {
    return CaptureState(
      name: json['name'] as String? ?? '',
      screenshot: json['screenshot'] as String? ?? '',
    );
  }

  final String name;
  final String screenshot;
}

class AppMapEdge {
  const AppMapEdge({
    required this.from,
    required this.raw,
    required this.target,
    this.to,
  });

  factory AppMapEdge.fromJson(Map<String, Object?> json) {
    return AppMapEdge(
      from: json['from'] as String? ?? '',
      to: json['to'] as String?,
      raw: json['raw'] as String? ?? '',
      target: json['target'] as String? ?? '',
    );
  }

  final String from;
  final String? to;
  final String raw;
  final String target;

  bool get isResolved => to != null && to!.isNotEmpty;
}

class AppMapFlow {
  const AppMapFlow({
    required this.name,
    required this.title,
    required this.steps,
    this.route,
    this.device,
    this.result,
    this.pointSize = const <double>[1, 1],
  });

  final String name;
  final String title;
  final String? route;
  final String? device;
  final String? result;
  final List<double> pointSize;
  final List<FlowStep> steps;

  bool get isInteractive => steps.any(
    (FlowStep step) =>
        step.action == 'tap' ||
        step.action == 'swipe' ||
        step.action == 'type' ||
        step.action == 'touch_path',
  );
}

class FlowStep {
  const FlowStep({
    required this.action,
    this.url,
    this.target,
    this.screen,
    this.note,
    this.capture,
    this.coordinate,
    this.from,
    this.to,
    this.text,
    this.seconds,
  });

  final String action;
  final String? url;
  final String? target;
  final String? screen;
  final String? note;
  final String? capture;
  final List<double>? coordinate;
  final List<double>? from;
  final List<double>? to;
  final String? text;
  final double? seconds;

  bool get isHidden => action == 'wait' || action == 'screenshot';
}

class FlowGesture {
  const FlowGesture.tap({required this.x, required this.y, this.label})
    : type = 'tap',
      x2 = null,
      y2 = null;

  const FlowGesture.swipe({
    required this.x,
    required this.y,
    required double endX,
    required double endY,
  }) : type = 'swipe',
       x2 = endX,
       y2 = endY,
       label = null;

  final String type;
  final double x;
  final double y;
  final double? x2;
  final double? y2;
  final String? label;
}
