import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';

import '../layout/graph_layout.dart';
import '../services/graph_edges.dart';
import '../theme/visualiser_theme.dart';

class EdgePainter extends CustomPainter {
  EdgePainter({
    required this.edges,
    required this.positions,
    required this.activeEdgeKeys,
    required this.selectedEdgeKey,
  });

  final List<GraphEdgeInfo> edges;
  final Map<String, Offset> positions;
  final Set<String> activeEdgeKeys;
  final String? selectedEdgeKey;

  @override
  void paint(Canvas canvas, Size size) {
    final bool anySelection =
        activeEdgeKeys.isNotEmpty || selectedEdgeKey != null;
    for (final GraphEdgeInfo edge in edges) {
      final _EdgeGeometry? geometry = _geometryFor(edge);
      if (geometry == null) {
        continue;
      }
      final bool onPath =
          activeEdgeKeys.contains(edge.key) || selectedEdgeKey == edge.key;
      final bool faded = anySelection && !onPath;
      final Color color = onPath
          ? VisualiserTheme.accentBright
          : faded
          ? Colors.white.withValues(alpha: 0.045)
          : Colors.white.withValues(alpha: 0.13);
      final Paint paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = onPath ? 2.4 : 1.4
        ..strokeCap = StrokeCap.round;
      if (edge.observed || edge.synthetic) {
        _drawDashedPath(canvas, geometry.path, paint);
      } else {
        canvas.drawPath(geometry.path, paint);
      }
      _drawArrow(
        canvas,
        geometry.end,
        geometry.beforeEnd,
        color,
        onPath ? 2.4 : 1.4,
      );
    }
  }

  GraphEdgeInfo? edgeAt(Offset position, {double tolerance = 10}) {
    GraphEdgeInfo? closest;
    double closestDistance = tolerance;
    for (final GraphEdgeInfo edge in edges.reversed) {
      if (edge.synthetic) {
        continue;
      }
      final _EdgeGeometry? geometry = _geometryFor(edge);
      if (geometry == null) {
        continue;
      }
      for (final PathMetric metric in geometry.path.computeMetrics()) {
        for (double distance = 0; distance <= metric.length; distance += 8) {
          final Tangent? tangent = metric.getTangentForOffset(distance);
          if (tangent == null) {
            continue;
          }
          final double candidate = (tangent.position - position).distance;
          if (candidate < closestDistance) {
            closestDistance = candidate;
            closest = edge;
          }
        }
      }
    }
    return closest;
  }

  _EdgeGeometry? _geometryFor(GraphEdgeInfo edge) {
    final Offset? from = positions[edge.from];
    final Offset? to = positions[edge.to];
    if (from == null || to == null) {
      return null;
    }
    final Offset start = Offset(
      from.dx + kNodeWidth / 2,
      from.dy + (kNodeWidth / kPhoneAspect) + kPhoneBezel * 2,
    );
    final Offset end = Offset(to.dx + kNodeWidth / 2, to.dy);
    final double midY = (start.dy + end.dy) / 2;
    final Path path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);
    final Offset beforeEnd = Offset(end.dx, end.dy - 12);
    return _EdgeGeometry(path: path, end: end, beforeEnd: beforeEnd);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dash = 8;
    const double gap = 6;
    for (final PathMetric metric in path.computeMetrics()) {
      double start = 0;
      while (start < metric.length) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + dash, metric.length)),
          paint,
        );
        start += dash + gap;
      }
    }
  }

  void _drawArrow(
    Canvas canvas,
    Offset tip,
    Offset from,
    Color color,
    double stroke,
  ) {
    final double angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    const double size = 8;
    final Path arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - size * math.cos(angle - 0.45),
        tip.dy - size * math.sin(angle - 0.45),
      )
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - size * math.cos(angle + 0.45),
        tip.dy - size * math.sin(angle + 0.45),
      );
    canvas.drawPath(
      arrow,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant EdgePainter oldDelegate) {
    return oldDelegate.selectedEdgeKey != selectedEdgeKey ||
        oldDelegate.edges != edges ||
        oldDelegate.positions != positions ||
        oldDelegate.activeEdgeKeys != activeEdgeKeys;
  }
}

class _EdgeGeometry {
  const _EdgeGeometry({
    required this.path,
    required this.end,
    required this.beforeEnd,
  });

  final Path path;
  final Offset end;
  final Offset beforeEnd;
}
