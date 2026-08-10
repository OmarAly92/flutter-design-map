import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../layout/graph_layout.dart';
import '../models/appmap_bundle.dart';
import '../theme/visualiser_theme.dart';

class GraphMiniMap extends StatelessWidget {
  const GraphMiniMap({
    super.key,
    required this.positions,
    required this.canvasSize,
    required this.nodes,
    required this.selectedId,
    required this.pathIds,
    required this.controller,
    required this.viewportSize,
  });

  final Map<String, Offset> positions;
  final Size canvasSize;
  final List<AppMapNode> nodes;
  final String? selectedId;
  final Set<String> pathIds;
  final TransformationController controller;
  final Size viewportSize;

  static const Size _size = Size(168, 112);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE60E1117),
      borderRadius: BorderRadius.circular(14),
      child: Listener(
        onPointerSignal: (PointerSignalEvent event) {
          if (event is! PointerScrollEvent) {
            return;
          }
          _centerAt(
            event.localPosition,
            zoomFactor: event.scrollDelta.dy > 0 ? 0.9 : 1.1,
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails details) =>
              _centerAt(details.localPosition),
          onPanStart: (DragStartDetails details) =>
              _centerAt(details.localPosition),
          onPanUpdate: (DragUpdateDetails details) =>
              _centerAt(details.localPosition),
          child: Container(
            width: _size.width,
            height: _size.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: VisualiserTheme.panelBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedBuilder(
              animation: controller,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: _MiniMapPainter(
                    positions: positions,
                    canvasSize: canvasSize,
                    nodes: nodes,
                    selectedId: selectedId,
                    pathIds: pathIds,
                    transform: controller.value,
                    viewportSize: viewportSize,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _centerAt(Offset localPosition, {double zoomFactor = 1}) {
    final double scaleX = canvasSize.width / _size.width;
    final double scaleY = canvasSize.height / _size.height;
    final double canvasX = localPosition.dx * scaleX;
    final double canvasY = localPosition.dy * scaleY;
    final double zoom = (controller.value.getMaxScaleOnAxis() * zoomFactor)
        .clamp(0.2, 2.8);
    final double dx = viewportSize.width / 2 - canvasX * zoom;
    final double dy = viewportSize.height / 2 - canvasY * zoom;
    controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(zoom, zoom, 1, 1);
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.positions,
    required this.canvasSize,
    required this.nodes,
    required this.selectedId,
    required this.pathIds,
    required this.transform,
    required this.viewportSize,
  });

  final Map<String, Offset> positions;
  final Size canvasSize;
  final List<AppMapNode> nodes;
  final String? selectedId;
  final Set<String> pathIds;
  final Matrix4 transform;
  final Size viewportSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      return;
    }
    final double sx = size.width / canvasSize.width;
    final double sy = size.height / canvasSize.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0E1117),
    );
    for (final AppMapNode node in nodes) {
      final Offset? pos = positions[node.id];
      if (pos == null) {
        continue;
      }
      final Rect rect = Rect.fromLTWH(
        pos.dx * sx,
        pos.dy * sy,
        kNodeWidth * sx,
        (kNodeCardSize.height - 20) * sy,
      );
      final bool hot = node.id == selectedId || pathIds.contains(node.id);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..color = hot
              ? VisualiserTheme.groupColor(node.group)
              : VisualiserTheme.groupColor(node.group).withValues(alpha: 0.35),
      );
    }
    final Matrix4 inverse = Matrix4.inverted(transform);
    final Offset topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
    final Offset bottomRight = MatrixUtils.transformPoint(
      inverse,
      Offset(viewportSize.width, viewportSize.height),
    );
    final Rect view = Rect.fromPoints(
      Offset(topLeft.dx * sx, topLeft.dy * sy),
      Offset(bottomRight.dx * sx, bottomRight.dy * sy),
    ).intersect(Offset.zero & size);
    canvas.drawRect(
      view,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      view,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.pathIds != pathIds;
  }
}
