import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../layout/graph_layout.dart';
import '../models/appmap_bundle.dart';
import '../services/graph_edges.dart';
import '../theme/visualiser_theme.dart';
import 'edge_painter.dart';
import 'node_card.dart';

class MapCanvas extends StatelessWidget {
  const MapCanvas({
    super.key,
    required this.bundle,
    required this.positions,
    required this.edges,
    required this.canvasSize,
    required this.selectedId,
    required this.pathIds,
    required this.currentNodeId,
    required this.neighbourIds,
    required this.chosenStates,
    required this.stateOverrides,
    required this.gesture,
    required this.activeEdgeKeys,
    required this.selectedEdgeKey,
    required this.onSelect,
    required this.onEdgeSelect,
    required this.onStateSelect,
    required this.controller,
    this.onPaneTap,
  });

  final AppMapBundle bundle;
  final Map<String, Offset> positions;
  final List<GraphEdgeInfo> edges;
  final Size canvasSize;
  final String? selectedId;
  final Set<String> pathIds;
  final String? currentNodeId;
  final Set<String> neighbourIds;
  final Map<String, String?> chosenStates;
  final Map<String, String> stateOverrides;
  final FlowGesture? gesture;
  final Set<String> activeEdgeKeys;
  final String? selectedEdgeKey;
  final ValueChanged<String> onSelect;
  final ValueChanged<GraphEdgeInfo> onEdgeSelect;
  final VoidCallback? onPaneTap;
  final void Function(String nodeId, String? state) onStateSelect;
  final TransformationController controller;

  @override
  Widget build(BuildContext context) {
    final bool anyFocus =
        selectedId != null ||
        pathIds.isNotEmpty ||
        currentNodeId != null ||
        selectedEdgeKey != null;
    final EdgePainter edgePainter = EdgePainter(
      edges: edges,
      positions: positions,
      activeEdgeKeys: activeEdgeKeys,
      selectedEdgeKey: selectedEdgeKey,
    );
    return InteractiveViewer(
      transformationController: controller,
      constrained: false,
      // The page positions the canvas programmatically when a flow or node is
      // focused. A finite boundary can make that transform temporarily
      // out-of-bounds; InteractiveViewer then corrects it on the first pan,
      // which looks like the whole graph snapping sideways. This is an
      // effectively unbounded workspace, and the fit button/minimap provide a
      // reliable way back to the graph.
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.2,
      maxScale: 2.8,
      panEnabled: true,
      scaleEnabled: true,
      child: SizedBox(
        width: canvasSize.width,
        height: canvasSize.height,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails details) {
                  final GraphEdgeInfo? edge = edgePainter.edgeAt(
                    details.localPosition,
                  );
                  if (edge == null) {
                    onPaneTap?.call();
                  } else {
                    onEdgeSelect(edge);
                  }
                },
              ),
            ),
            IgnorePointer(
              child: CustomPaint(size: canvasSize, painter: edgePainter),
            ),
            for (final AppMapNode node in bundle.nodes)
              if (positions[node.id] != null)
                Positioned(
                  left: positions[node.id]!.dx,
                  top: positions[node.id]!.dy,
                  child: NodeCard(
                    node: node,
                    screenshotBytes: _bytesFor(node),
                    isSelected: selectedId == node.id,
                    isCurrent: currentNodeId == node.id,
                    onPath: pathIds.contains(node.id),
                    isDimmed:
                        anyFocus &&
                        node.id != selectedId &&
                        node.id != currentNodeId &&
                        !pathIds.contains(node.id) &&
                        !neighbourIds.contains(node.id),
                    chosenState:
                        stateOverrides[node.id] ?? chosenStates[node.id],
                    gesture: currentNodeId == node.id ? gesture : null,
                    onStateSelect: currentNodeId == node.id
                        ? null
                        : (String? state) => onStateSelect(node.id, state),
                    onTap: () => onSelect(node.id),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Uint8List? _bytesFor(AppMapNode node) {
    final String? chosen = stateOverrides[node.id] ?? chosenStates[node.id];
    if (chosen != null) {
      for (final CaptureState state in node.capture.states) {
        if (state.name == chosen) {
          return bundle.screenshots[state.screenshot];
        }
      }
    }
    final String? path = node.capture.screenshot;
    if (path == null) {
      return null;
    }
    return bundle.screenshots[path];
  }
}

class NodeDetailPanel extends StatelessWidget {
  const NodeDetailPanel({
    super.key,
    required this.node,
    required this.bundle,
    required this.onClose,
  });

  final AppMapNode node;
  final AppMapBundle bundle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = node.capture.screenshot == null
        ? null
        : bundle.screenshots[node.capture.screenshot!];
    final List<AppMapEdge> outbound = bundle.edges
        .where((AppMapEdge edge) => edge.from == node.id)
        .toList();
    final List<AppMapEdge> inbound = bundle.edges
        .where((AppMapEdge edge) => edge.to == node.id)
        .toList();
    return Material(
      color: VisualiserTheme.panel,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: VisualiserTheme.panelBorder)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        node.urlPath,
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: <Widget>[
                    Center(
                      child: SizedBox(
                        width: 200,
                        child: AspectRatio(
                          aspectRatio: kPhoneAspect,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(kPhoneRadius),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Color(0xFF1D212B),
                                  Color(0xFF12151D),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(kPhoneBezel),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  kScreenRadius,
                                ),
                                child: bytes == null
                                    ? ColoredBox(
                                        color: VisualiserTheme.panelSolid,
                                        child: Center(
                                          child: Text(
                                            'No screenshot',
                                            style: GoogleFonts.inter(
                                              color: VisualiserTheme.muted,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Image.memory(bytes, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MetaRow(label: 'Route', value: node.id),
                    _MetaRow(label: 'Status', value: node.capture.status),
                    if (node.capture.note != null)
                      _MetaRow(label: 'Note', value: node.capture.note!),
                    if (node.file.isNotEmpty)
                      _MetaRow(label: 'File', value: node.file),
                    if (node.presentation != null)
                      _MetaRow(
                        label: 'Presentation',
                        value: node.presentation!,
                      ),
                    if (node.stateHints.isNotEmpty)
                      _MetaRow(
                        label: 'Runtime states',
                        value: node.stateHints
                            .map(
                              (Map<String, Object?> hint) =>
                                  hint['type']?.toString() ?? 'unknown',
                            )
                            .join(', '),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'Outbound (${outbound.length})',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: VisualiserTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...outbound.map(
                      (AppMapEdge edge) => _EdgeTile(
                        title: edge.to ?? '(unresolved)',
                        subtitle: edge.raw,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Inbound (${inbound.length})',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: VisualiserTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...inbound.map(
                      (AppMapEdge edge) =>
                          _EdgeTile(title: edge.from, subtitle: edge.raw),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: VisualiserTheme.muted,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12.5,
              color: VisualiserTheme.fg,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _EdgeTile extends StatelessWidget {
  const _EdgeTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VisualiserTheme.panelSolid,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VisualiserTheme.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10.5,
              color: VisualiserTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
