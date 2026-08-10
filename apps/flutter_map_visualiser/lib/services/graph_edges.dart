import '../models/appmap_bundle.dart';
import 'flow_resolution.dart';

/// A transition ready for layout and rendering.
///
/// Static parser edges are collapsed by route pair. Agent-observed transitions
/// are added when a recorded tap/swipe reaches a screen that static analysis
/// did not connect. Synthetic edges are temporary gaps in the active flow.
class GraphEdgeInfo {
  const GraphEdgeInfo({
    required this.from,
    required this.to,
    this.raws = const <String>[],
    this.flows = const <String>[],
    this.observed = false,
    this.synthetic = false,
  });

  final String from;
  final String to;
  final List<String> raws;
  final List<String> flows;
  final bool observed;
  final bool synthetic;

  String get key => '$from→$to';
}

List<GraphEdgeInfo> buildGraphEdges(
  AppMapBundle bundle,
  FlowResolution resolution, {
  String? activeFlowName,
}) {
  final Map<String, _MutableGraphEdge> edges = <String, _MutableGraphEdge>{};

  for (final AppMapEdge edge in bundle.edges) {
    final String? to = edge.to;
    if (to == null || to.isEmpty || edge.from == to) {
      continue;
    }
    final String key = '${edge.from}→$to';
    final _MutableGraphEdge info = edges.putIfAbsent(
      key,
      () => _MutableGraphEdge(from: edge.from, to: to),
    );
    if (edge.raw.isNotEmpty && !info.raws.contains(edge.raw)) {
      info.raws.add(edge.raw);
    }
  }

  for (final AppMapFlow flow in bundle.flows) {
    final List<String?> at = resolution.nodeAtStep[flow.name] ?? <String?>[];
    for (int i = 0; i < flow.steps.length; i++) {
      final FlowStep step = flow.steps[i];
      if (step.action != 'tap' && step.action != 'swipe') {
        continue;
      }
      final String? to = step.screen;
      final String? from = i > 0 && i - 1 < at.length ? at[i - 1] : flow.route;
      if (from == null || to == null || from == to) {
        continue;
      }
      final String key = '$from→$to';
      final _MutableGraphEdge? existing = edges[key];
      if (existing != null) {
        continue;
      }
      final _MutableGraphEdge observed = edges.putIfAbsent(
        key,
        () => _MutableGraphEdge(from: from, to: to, observed: true),
      );
      if (!observed.flows.contains(flow.name)) {
        observed.flows.add(flow.name);
      }
    }
  }

  if (activeFlowName != null) {
    final List<String> path = resolution.paths[activeFlowName] ?? <String>[];
    for (int i = 0; i + 1 < path.length; i++) {
      final String from = path[i];
      final String to = path[i + 1];
      if (from == to) {
        continue;
      }
      edges.putIfAbsent(
        '$from→$to',
        () => _MutableGraphEdge(from: from, to: to, synthetic: true),
      );
    }
  }

  final List<GraphEdgeInfo> result =
      edges.values.map((_MutableGraphEdge edge) => edge.freeze()).toList()
        ..sort((GraphEdgeInfo a, GraphEdgeInfo b) => a.key.compareTo(b.key));
  return result;
}

FlowGesture? gestureForEdge(
  AppMapBundle bundle,
  FlowResolution resolution,
  GraphEdgeInfo edge,
) {
  for (final AppMapFlow flow in bundle.flows) {
    final List<String?> at = resolution.nodeAtStep[flow.name] ?? <String?>[];
    for (int i = 0; i < flow.steps.length; i++) {
      final FlowStep step = flow.steps[i];
      final String? from = i > 0 && i - 1 < at.length ? at[i - 1] : flow.route;
      if (from != edge.from || step.screen != edge.to) {
        continue;
      }
      final List<double> pointSize = flow.pointSize;
      if (step.action == 'tap' &&
          step.coordinate != null &&
          step.coordinate!.length >= 2) {
        return FlowGesture.tap(
          x: step.coordinate![0] / pointSize[0],
          y: step.coordinate![1] / pointSize[1],
          label: step.target,
        );
      }
      if (step.action == 'swipe' &&
          step.from != null &&
          step.to != null &&
          step.from!.length >= 2 &&
          step.to!.length >= 2) {
        return FlowGesture.swipe(
          x: step.from![0] / pointSize[0],
          y: step.from![1] / pointSize[1],
          endX: step.to![0] / pointSize[0],
          endY: step.to![1] / pointSize[1],
        );
      }
    }
  }
  return null;
}

class _MutableGraphEdge {
  _MutableGraphEdge({
    required this.from,
    required this.to,
    this.observed = false,
    this.synthetic = false,
  });

  final String from;
  final String to;
  final List<String> raws = <String>[];
  final List<String> flows = <String>[];
  final bool observed;
  final bool synthetic;

  GraphEdgeInfo freeze() => GraphEdgeInfo(
    from: from,
    to: to,
    raws: List<String>.unmodifiable(raws),
    flows: List<String>.unmodifiable(flows),
    observed: observed,
    synthetic: synthetic,
  );
}
