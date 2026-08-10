import 'dart:math' as math;
import 'dart:ui';

import '../models/appmap_bundle.dart';
import '../services/graph_edges.dart';

/// Matches expo-map visualiser node metrics.
const double kNodeWidth = 168;
const double kPhoneBezel = 5;
const double kPhoneRadius = 26;
const double kScreenRadius = 21;

/// 402/874 device aspect inside the bezel.
const double kPhoneAspect = 402 / 874;
const double kLabelBlock = 52;
const Size kNodeCardSize = Size(
  kNodeWidth,
  kNodeWidth / kPhoneAspect + kPhoneBezel * 2 + kLabelBlock,
);

/// Layered top-down layout (ELK-like) with isolated nodes in a grid below.
class GraphLayout {
  GraphLayout({required this.nodes, required this.edges});

  final List<AppMapNode> nodes;
  final List<GraphEdgeInfo> edges;

  static const double _layerGap = 110;
  static const double _nodeGap = 56;
  static const double _isolatedGapY = 180;
  static const double _padding = 64;

  Map<String, Offset> compute() {
    if (nodes.isEmpty) {
      return <String, Offset>{};
    }
    final Set<String> connectedIds = <String>{};
    for (final GraphEdgeInfo edge in edges) {
      if (edge.from == edge.to) {
        continue;
      }
      connectedIds.add(edge.from);
      connectedIds.add(edge.to);
    }
    final List<AppMapNode> connected = nodes
        .where((AppMapNode n) => connectedIds.contains(n.id))
        .toList();
    final List<AppMapNode> isolated =
        nodes.where((AppMapNode n) => !connectedIds.contains(n.id)).toList()
          ..sort((AppMapNode a, AppMapNode b) {
            final int byGroup = a.group.compareTo(b.group);
            if (byGroup != 0) {
              return byGroup;
            }
            return a.id.compareTo(b.id);
          });
    final Map<String, Offset> positions = _layoutConnected(connected);
    if (connected.isNotEmpty) {
      AppMapNode? root;
      for (final AppMapNode node in connected) {
        if (node.urlPath == '/') {
          root = node;
          break;
        }
      }
      if (root != null && positions[root.id] != null) {
        final List<double> xs = connected
            .where((AppMapNode n) => n.id != root!.id)
            .map((AppMapNode n) => positions[n.id]!.dx)
            .toList();
        if (xs.isNotEmpty) {
          positions[root.id] = Offset(
            (xs.reduce(math.min) + xs.reduce(math.max)) / 2,
            positions[root.id]!.dy,
          );
        }
      }
    }
    final Iterable<Offset> placed = positions.values;
    final double maxY = placed.isEmpty
        ? 0
        : placed.map((Offset o) => o.dy).reduce(math.max) +
              kNodeCardSize.height;
    final double minX = placed.isEmpty
        ? _padding
        : placed.map((Offset o) => o.dx).reduce(math.min);
    final int cols = math.max(4, (math.sqrt(isolated.length * 2.2)).ceil());
    for (int i = 0; i < isolated.length; i++) {
      positions[isolated[i].id] = Offset(
        minX + (i % cols) * (kNodeWidth + _nodeGap),
        maxY + _isolatedGapY + (i ~/ cols) * (kNodeCardSize.height + 90),
      );
    }
    return positions;
  }

  Size computeCanvasSize(Map<String, Offset> positions) {
    if (positions.isEmpty) {
      return const Size(800, 600);
    }
    double maxX = 0;
    double maxY = 0;
    for (final Offset offset in positions.values) {
      maxX = math.max(maxX, offset.dx + kNodeCardSize.width);
      maxY = math.max(maxY, offset.dy + kNodeCardSize.height);
    }
    return Size(maxX + _padding, maxY + _padding);
  }

  Map<String, Offset> _layoutConnected(List<AppMapNode> connected) {
    if (connected.isEmpty) {
      return <String, Offset>{};
    }
    final Map<String, List<String>> outgoing = <String, List<String>>{};
    final Map<String, List<String>> incoming = <String, List<String>>{};
    final Map<String, int> indegree = <String, int>{
      for (final AppMapNode n in connected) n.id: 0,
    };
    for (final GraphEdgeInfo edge in edges) {
      if (edge.from == edge.to) {
        continue;
      }
      if (!indegree.containsKey(edge.from) || !indegree.containsKey(edge.to)) {
        continue;
      }
      outgoing.putIfAbsent(edge.from, () => <String>[]).add(edge.to);
      incoming.putIfAbsent(edge.to, () => <String>[]).add(edge.from);
      indegree[edge.to] = (indegree[edge.to] ?? 0) + 1;
    }
    final Map<String, int> layer = <String, int>{};
    final Map<String, int> remainingIndegree = Map<String, int>.from(indegree);
    final List<String> queue = connected
        .where((AppMapNode n) => (indegree[n.id] ?? 0) == 0)
        .map((AppMapNode n) => n.id)
        .toList();
    for (final String id in queue) {
      layer[id] = 1;
    }
    // Root path gets its own first layer.
    for (final AppMapNode n in connected) {
      if (n.urlPath == '/') {
        layer[n.id] = 0;
        if (!queue.contains(n.id)) {
          queue.insert(0, n.id);
        }
      }
    }
    if (queue.isEmpty) {
      queue.add(connected.first.id);
      layer[connected.first.id] = connected.first.urlPath == '/' ? 0 : 1;
    }
    final Set<String> processed = <String>{};
    while (queue.isNotEmpty) {
      final String id = queue.removeAt(0);
      if (!processed.add(id)) {
        continue;
      }
      final int current = layer[id] ?? 0;
      for (final String next in outgoing[id] ?? <String>[]) {
        if (connected.any(
          (AppMapNode node) => node.id == next && node.urlPath == '/',
        )) {
          continue;
        }
        final int proposed = current + 1;
        if (!layer.containsKey(next) || layer[next]! < proposed) {
          layer[next] = proposed;
        }
        remainingIndegree[next] = (remainingIndegree[next] ?? 1) - 1;
        if (remainingIndegree[next]! <= 0) {
          queue.add(next);
        }
      }
    }
    for (final AppMapNode n in connected) {
      layer.putIfAbsent(n.id, () {
        final Iterable<int> parentLayers = (incoming[n.id] ?? <String>[])
            .map((String id) => layer[id])
            .whereType<int>();
        return parentLayers.isEmpty ? 1 : parentLayers.reduce(math.max) + 1;
      });
    }
    final Map<int, List<AppMapNode>> byLayer = <int, List<AppMapNode>>{};
    for (final AppMapNode n in connected) {
      byLayer.putIfAbsent(layer[n.id]!, () => <AppMapNode>[]).add(n);
    }
    final List<int> layers = byLayer.keys.toList()..sort();
    for (final List<AppMapNode> row in byLayer.values) {
      row.sort((AppMapNode a, AppMapNode b) => a.urlPath.compareTo(b.urlPath));
    }
    // Repeated barycentric sweeps provide ELK-like crossing reduction while
    // keeping this renderer dependency-free on every Flutter platform.
    for (int pass = 0; pass < 4; pass++) {
      Map<String, int> order = _orderIndex(byLayer, layers);
      for (final int layerIndex in layers.skip(1)) {
        _sortByNeighbourOrder(byLayer[layerIndex]!, incoming, order);
        order = _orderIndex(byLayer, layers);
      }
      for (final int layerIndex in layers.reversed.skip(1)) {
        _sortByNeighbourOrder(byLayer[layerIndex]!, outgoing, order);
        order = _orderIndex(byLayer, layers);
      }
    }
    final Map<String, Offset> positions = <String, Offset>{};
    for (final int layerIndex in layers) {
      final List<AppMapNode> row = byLayer[layerIndex]!;
      final double totalWidth =
          row.length * kNodeWidth + (row.length - 1) * _nodeGap;
      double x = _padding + math.max(0, (1200 - totalWidth) / 2);
      final double y =
          _padding + layerIndex * (kNodeCardSize.height + _layerGap);
      for (final AppMapNode node in row) {
        positions[node.id] = Offset(x, y);
        x += kNodeWidth + _nodeGap;
      }
    }
    return positions;
  }

  Map<String, int> _orderIndex(
    Map<int, List<AppMapNode>> byLayer,
    List<int> layers,
  ) {
    final Map<String, int> order = <String, int>{};
    for (final int layer in layers) {
      final List<AppMapNode> row = byLayer[layer]!;
      for (int i = 0; i < row.length; i++) {
        order[row[i].id] = i;
      }
    }
    return order;
  }

  void _sortByNeighbourOrder(
    List<AppMapNode> row,
    Map<String, List<String>> neighbours,
    Map<String, int> order,
  ) {
    double score(AppMapNode node) {
      final List<int> indexes = (neighbours[node.id] ?? <String>[])
          .map((String id) => order[id])
          .whereType<int>()
          .toList();
      if (indexes.isEmpty) {
        return order[node.id]?.toDouble() ?? 0;
      }
      return indexes.reduce((int a, int b) => a + b) / indexes.length;
    }

    row.sort((AppMapNode a, AppMapNode b) {
      final int byScore = score(a).compareTo(score(b));
      return byScore != 0 ? byScore : a.urlPath.compareTo(b.urlPath);
    });
  }
}
