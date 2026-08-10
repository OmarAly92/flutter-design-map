import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../demo_bundle.dart';
import '../layout/graph_layout.dart';
import '../models/appmap_bundle.dart';
import '../services/appmap_loader.dart';
import '../services/flow_resolution.dart';
import '../services/graph_edges.dart';
import '../theme/visualiser_theme.dart';
import '../widgets/flow_panel.dart';
import '../widgets/map_canvas.dart';
import '../widgets/mini_map.dart';

class VisualiserHomePage extends StatefulWidget {
  const VisualiserHomePage({super.key});

  @override
  State<VisualiserHomePage> createState() => _VisualiserHomePageState();
}

class _VisualiserHomePageState extends State<VisualiserHomePage> {
  final AppMapLoader _loader = const AppMapLoader();
  final TransformationController _transform = TransformationController();
  final FocusNode _focusNode = FocusNode();
  AppMapBundle? _bundle;
  FlowResolution? _resolution;
  List<GraphEdgeInfo> _graphEdges = <GraphEdgeInfo>[];
  Map<String, Offset> _positions = <String, Offset>{};
  Size _canvasSize = const Size(800, 600);
  String? _selectedId;
  String? _selectedFlowName;
  String? _selectedEdgeKey;
  int _step = 0;
  bool _flowsOpen = true;
  bool _neighboursMode = false;
  Map<String, String?> _chosenStates = <String, String?>{};
  String? _error;
  bool _isLoading = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBundledDemo());
  }

  Future<void> _loadBundledDemo() async {
    if (!mounted || _bundle != null) {
      return;
    }
    try {
      final Uint8List bytes = await loadDemoBundleBytes();
      if (mounted && _bundle == null) {
        _loadBytes(bytes);
      }
    } catch (err) {
      if (mounted) {
        setState(() => _error = 'Could not open the bundled demo: $err');
      }
    }
  }

  Set<String> get _pathIds {
    final GraphEdgeInfo? selectedEdge = _selectedEdge;
    if (selectedEdge != null) {
      return <String>{selectedEdge.from, selectedEdge.to};
    }
    final String? flowName = _selectedFlowName;
    final FlowResolution? resolution = _resolution;
    if (flowName == null || resolution == null) {
      return <String>{};
    }
    return resolution.paths[flowName]?.toSet() ?? <String>{};
  }

  String? get _currentNodeId {
    final GraphEdgeInfo? selectedEdge = _selectedEdge;
    if (selectedEdge != null) {
      return selectedEdge.from;
    }
    final String? flowName = _selectedFlowName;
    final FlowResolution? resolution = _resolution;
    final AppMapBundle? bundle = _bundle;
    if (flowName == null || resolution == null || bundle == null) {
      return null;
    }
    final List<String?>? at = resolution.nodeAtStep[flowName];
    if (at == null || at.isEmpty) {
      return bundle.flowByName(flowName)?.route;
    }
    final int index = _step.clamp(0, at.length - 1);
    return at[index] ?? bundle.flowByName(flowName)?.route;
  }

  Set<String> get _neighbourIds {
    if (!_neighboursMode) {
      return <String>{};
    }
    final String? subject = _selectedId ?? _currentNodeId;
    if (subject == null) {
      return <String>{};
    }
    final Set<String> ids = <String>{subject};
    for (final GraphEdgeInfo edge in _graphEdges) {
      if (edge.from == subject) {
        ids.add(edge.to);
      }
    }
    return ids;
  }

  Map<String, String> get _stateOverrides {
    final AppMapBundle? bundle = _bundle;
    final String? flowName = _selectedFlowName;
    if (bundle == null || flowName == null) {
      return <String, String>{};
    }
    final AppMapFlow? flow = bundle.flowByName(flowName);
    if (flow == null) {
      return <String, String>{};
    }
    return stateOverridesAtStep(bundle, flow, _step);
  }

  FlowGesture? get _gesture {
    final GraphEdgeInfo? selectedEdge = _selectedEdge;
    final AppMapBundle? bundle = _bundle;
    final FlowResolution? resolution = _resolution;
    if (selectedEdge != null && bundle != null && resolution != null) {
      return gestureForEdge(bundle, resolution, selectedEdge);
    }
    if (_neighboursMode) {
      return null;
    }
    final String? flowName = _selectedFlowName;
    if (bundle == null || flowName == null) {
      return null;
    }
    final AppMapFlow? flow = bundle.flowByName(flowName);
    if (flow == null) {
      return null;
    }
    return gestureForStep(flow, _step);
  }

  GraphEdgeInfo? get _selectedEdge {
    final String? key = _selectedEdgeKey;
    if (key == null) {
      return null;
    }
    for (final GraphEdgeInfo edge in _graphEdges) {
      if (edge.key == key) {
        return edge;
      }
    }
    return null;
  }

  List<GraphEdgeInfo> get _visibleEdges {
    final AppMapBundle? bundle = _bundle;
    final FlowResolution? resolution = _resolution;
    if (bundle == null || resolution == null) {
      return _graphEdges;
    }
    return buildGraphEdges(
      bundle,
      resolution,
      activeFlowName: _selectedFlowName,
    );
  }

  Set<String> get _activeEdgeKeys {
    final GraphEdgeInfo? selectedEdge = _selectedEdge;
    if (selectedEdge != null) {
      return <String>{selectedEdge.key};
    }
    if (_neighboursMode) {
      final String? subject = _selectedId ?? _currentNodeId;
      if (subject == null) {
        return <String>{};
      }
      return _graphEdges
          .where((GraphEdgeInfo edge) => edge.from == subject)
          .map((GraphEdgeInfo edge) => edge.key)
          .toSet();
    }
    final List<String> path = _selectedFlowName == null
        ? <String>[]
        : (_resolution?.paths[_selectedFlowName] ?? <String>[]);
    return <String>{
      for (int i = 0; i + 1 < path.length; i++) '${path[i]}→${path[i + 1]}',
    };
  }

  Future<void> _pickAppMap() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['appmap', 'zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final Uint8List? bytes = result.files.first.bytes;
      if (bytes == null) {
        throw const FormatException(
          'Could not read file bytes in the browser.',
        );
      }
      _loadBytes(bytes);
    } catch (err) {
      setState(() {
        _error = err.toString();
        _isLoading = false;
      });
    }
  }

  void _loadBytes(Uint8List bytes) {
    final AppMapBundle bundle = _loader.loadBytes(bytes);
    final FlowResolution resolution = FlowResolution.fromBundle(bundle);
    final List<GraphEdgeInfo> graphEdges = buildGraphEdges(bundle, resolution);
    final GraphLayout layout = GraphLayout(
      nodes: bundle.nodes,
      edges: graphEdges,
    );
    final Map<String, Offset> positions = layout.compute();
    setState(() {
      _bundle = bundle;
      _resolution = resolution;
      _graphEdges = graphEdges;
      _positions = positions;
      _canvasSize = layout.computeCanvasSize(positions);
      _selectedId = null;
      _selectedFlowName = null;
      _selectedEdgeKey = null;
      _step = 0;
      _flowsOpen = MediaQuery.sizeOf(context).width > 900;
      _neighboursMode = false;
      _chosenStates = <String, String?>{};
      _isLoading = false;
      _error = null;
      _transform.value = Matrix4.identity();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitView();
      _focusNode.requestFocus();
    });
  }

  void _fitView({String? focusNodeId}) {
    if (!mounted || _positions.isEmpty) {
      return;
    }
    final Size viewport = MediaQuery.sizeOf(context);
    if (focusNodeId != null && _positions[focusNodeId] != null) {
      final Offset pos = _positions[focusNodeId]!;
      const double zoom = 0.95;
      final double dx = viewport.width / 2 - (pos.dx + kNodeWidth / 2) * zoom;
      final double dy =
          viewport.height / 2 - (pos.dy + kNodeCardSize.height / 2) * zoom;
      _transform.value = Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1);
      return;
    }
    final double scaleX = (viewport.width - 80) / _canvasSize.width;
    final double scaleY = (viewport.height - 120) / _canvasSize.height;
    final double scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.25, 1.0);
    final double dx = (viewport.width - _canvasSize.width * scale) / 2;
    final double dy = (viewport.height - _canvasSize.height * scale) / 2 + 20;
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _fitNodes(Set<String> nodeIds) {
    final List<Offset> points = nodeIds
        .map((String id) => _positions[id])
        .whereType<Offset>()
        .toList();
    if (!mounted || points.isEmpty) {
      return;
    }
    final Size viewport = MediaQuery.sizeOf(context);
    double left = points.first.dx;
    double top = points.first.dy;
    double right = points.first.dx + kNodeWidth;
    double bottom = points.first.dy + kNodeCardSize.height;
    for (final Offset point in points.skip(1)) {
      left = math.min(left, point.dx);
      top = math.min(top, point.dy);
      right = math.max(right, point.dx + kNodeWidth);
      bottom = math.max(bottom, point.dy + kNodeCardSize.height);
    }
    final double width = right - left;
    final double height = bottom - top;
    final double scale = math
        .min((viewport.width * 0.68) / width, (viewport.height * 0.68) / height)
        .clamp(0.35, 1.15);
    final double dx = viewport.width / 2 - (left + width / 2) * scale;
    final double dy = viewport.height / 2 - (top + height / 2) * scale;
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoomBy(double factor) {
    final Size viewport = MediaQuery.sizeOf(context);
    final Offset viewportCenter = Offset(
      viewport.width / 2,
      viewport.height / 2,
    );
    final Offset sceneCenter = _transform.toScene(viewportCenter);
    final double current = _transform.value.getMaxScaleOnAxis();
    final double zoom = (current * factor).clamp(0.2, 2.8);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        viewportCenter.dx - sceneCenter.dx * zoom,
        viewportCenter.dy - sceneCenter.dy * zoom,
        0,
        1,
      )
      ..scaleByDouble(zoom, zoom, 1, 1);
  }

  void _clear() {
    setState(() {
      _bundle = null;
      _resolution = null;
      _graphEdges = <GraphEdgeInfo>[];
      _positions = <String, Offset>{};
      _selectedId = null;
      _selectedFlowName = null;
      _selectedEdgeKey = null;
      _step = 0;
      _neighboursMode = false;
      _chosenStates = <String, String?>{};
      _error = null;
      _transform.value = Matrix4.identity();
    });
  }

  void _selectFlow(String? name) {
    final AppMapBundle? bundle = _bundle;
    setState(() {
      _selectedFlowName = name;
      _selectedEdgeKey = null;
      _neighboursMode = false;
      _selectedId = null;
      if (name == null || bundle == null) {
        _step = 0;
        return;
      }
      final AppMapFlow? flow = bundle.flowByName(name);
      _step = flow == null || flow.steps.isEmpty ? 0 : flow.steps.length - 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? current = _currentNodeId;
      if (current != null) {
        _fitView(focusNodeId: current);
      }
    });
  }

  void _onSelectNode(String id) {
    final AppMapBundle? bundle = _bundle;
    if (bundle == null) {
      return;
    }
    if (_selectedId == id && _selectedFlowName == null) {
      setState(() => _selectedId = null);
      return;
    }
    final String? chosenState = _chosenStates[id];
    final ({AppMapFlow flow, int step})? stateFlow = chosenState == null
        ? null
        : flowStepForState(bundle, id, chosenState);
    final AppMapFlow? flow = stateFlow?.flow ?? flowForNode(bundle, id);
    setState(() {
      _selectedId = id;
      _selectedEdgeKey = null;
      _neighboursMode = false;
      if (flow != null) {
        _selectedFlowName = flow.name;
        _step =
            stateFlow?.step ?? (flow.steps.isEmpty ? 0 : flow.steps.length - 1);
      } else {
        _selectedFlowName = null;
        _step = 0;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitView(focusNodeId: id);
    });
  }

  void _onStepChange(int step) {
    setState(() {
      _step = step;
      _neighboursMode = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? current = _currentNodeId;
      if (current != null) {
        _fitView(focusNodeId: current);
      }
    });
  }

  void _onSelectEdge(GraphEdgeInfo edge) {
    final bool closing = _selectedEdgeKey == edge.key;
    setState(() {
      _selectedEdgeKey = closing ? null : edge.key;
      _selectedId = null;
      _selectedFlowName = null;
      _neighboursMode = false;
      _step = 0;
    });
    if (!closing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitNodes(<String>{edge.from, edge.to});
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _selectedId = null;
        _selectedFlowName = null;
        _selectedEdgeKey = null;
        _neighboursMode = false;
        _step = 0;
      });
      return KeyEventResult.handled;
    }
    final AppMapBundle? bundle = _bundle;
    final String? flowName = _selectedFlowName;
    if (bundle == null || flowName == null) {
      return KeyEventResult.ignored;
    }
    final AppMapFlow? flow = bundle.flowByName(flowName);
    if (flow == null) {
      return KeyEventResult.ignored;
    }
    final StepView view = buildStepView(flow, _step);
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _onStepChange(
        stepViewEffectiveEnd(flow, view.visibleIndexes, view.position + 1),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _onStepChange(
        stepViewEffectiveEnd(flow, view.visibleIndexes, view.position - 1),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() {
      _dragging = false;
      _isLoading = true;
      _error = null;
    });
    try {
      if (details.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final Uint8List bytes = await details.files.first.readAsBytes();
      _loadBytes(bytes);
    } catch (err) {
      setState(() {
        _error = err.toString();
        _isLoading = false;
      });
    }
  }

  AppMapNode? get _selectedNode {
    final AppMapBundle? bundle = _bundle;
    final String? id = _selectedId;
    if (bundle == null || id == null) {
      return null;
    }
    return bundle.nodeById(id);
  }

  @override
  void dispose() {
    _transform.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppMapBundle? bundle = _bundle;
    final Size viewport = MediaQuery.sizeOf(context);
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      autofocus: true,
      child: Scaffold(
        body: DropTarget(
          // Only treat file-drops on the landing screen. While a map is open,
          // DropTarget drag callbacks rebuild mid-pan and snap the canvas.
          enable: bundle == null,
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: _onDrop,
          child: Stack(
            children: <Widget>[
              const _Backdrop(),
              if (bundle == null)
                _EmptyState(
                  onOpen: _pickAppMap,
                  error: _error,
                  dragging: _dragging,
                ),
              if (bundle != null) ...<Widget>[
                Positioned.fill(
                  child: MapCanvas(
                    bundle: bundle,
                    positions: _positions,
                    edges: _visibleEdges,
                    canvasSize: _canvasSize,
                    selectedId: _selectedId,
                    pathIds: _neighboursMode ? _neighbourIds : _pathIds,
                    currentNodeId: _neighboursMode
                        ? (_selectedId ?? _currentNodeId)
                        : _currentNodeId,
                    neighbourIds: _neighboursMode ? _neighbourIds : <String>{},
                    chosenStates: _chosenStates,
                    stateOverrides: _stateOverrides,
                    gesture: _gesture,
                    activeEdgeKeys: _activeEdgeKeys,
                    selectedEdgeKey: _selectedEdgeKey,
                    controller: _transform,
                    onSelect: _onSelectNode,
                    onEdgeSelect: _onSelectEdge,
                    onPaneTap: () {
                      setState(() {
                        _selectedId = null;
                        _selectedFlowName = null;
                        _selectedEdgeKey = null;
                        _neighboursMode = false;
                        _step = 0;
                      });
                      _focusNode.requestFocus();
                    },
                    onStateSelect: (String nodeId, String? state) {
                      setState(() {
                        _chosenStates = <String, String?>{
                          ..._chosenStates,
                          nodeId: state,
                        };
                      });
                    },
                  ),
                ),
                Positioned(left: 16, top: 16, child: _HudCard(bundle: bundle)),
                Positioned(
                  right: 16,
                  top: 16,
                  child: _Toolbar(
                    onOpen: _pickAppMap,
                    onClear: _clear,
                    onFit: () => _fitView(),
                    onZoomIn: () => _zoomBy(1.2),
                    onZoomOut: () => _zoomBy(1 / 1.2),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 130,
                  child: Material(
                    color: Colors.transparent,
                    // Keep overlay gestures local so canvas pan never starts
                    // under / through the flows panel.
                    child: FlowPanel(
                      bundle: bundle,
                      selectedFlowName: _selectedFlowName,
                      step: _step,
                      flowsOpen: _flowsOpen,
                      neighboursMode: _neighboursMode,
                      onToggleOpen: () =>
                          setState(() => _flowsOpen = !_flowsOpen),
                      onSelectFlow: _selectFlow,
                      onStepChange: _onStepChange,
                      onNeighboursMode: () {
                        setState(() {
                          _neighboursMode = true;
                          _selectedId ??= _currentNodeId;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final String? id = _selectedId ?? _currentNodeId;
                          if (id != null) {
                            _fitView(focusNodeId: id);
                          }
                        });
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: GraphMiniMap(
                    positions: _positions,
                    canvasSize: _canvasSize,
                    nodes: bundle.nodes,
                    selectedId: _selectedId ?? _currentNodeId,
                    pathIds: _neighboursMode ? _neighbourIds : _pathIds,
                    controller: _transform,
                    viewportSize: viewport,
                  ),
                ),
                if (_selectedNode != null && _selectedFlowName == null)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: 360,
                    child: NodeDetailPanel(
                      node: _selectedNode!,
                      bundle: bundle,
                      onClose: () => setState(() => _selectedId = null),
                    ),
                  ),
                if (_selectedEdge != null)
                  Positioned(
                    left: math.max(16, viewport.width / 2 - 310),
                    right: math.max(16, viewport.width / 2 - 310),
                    bottom: 16,
                    child: _TransitionCard(
                      edge: _selectedEdge!,
                      from: bundle.nodeById(_selectedEdge!.from),
                      to: bundle.nodeById(_selectedEdge!.to),
                      gestureKnown: _gesture != null,
                    ),
                  ),
              ],
              if (_isLoading)
                const ColoredBox(
                  color: Color(0x880A0C11),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudCard extends StatelessWidget {
  const _HudCard({required this.bundle});

  final AppMapBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: VisualiserTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VisualiserTheme.panelBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                  gradient: SweepGradient(
                    colors: <Color>[
                      Color(0xFF818CF8),
                      Color(0xFF22D3EE),
                      Color(0xFF818CF8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bundle.manifest.appName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${bundle.manifest.mode ?? 'unknown'} · '
            '${bundle.manifest.device ?? bundle.manifest.platform ?? 'device'} · '
            '${bundle.manifest.generatedAt?.substring(0, 10) ?? ''}',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: VisualiserTheme.muted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatChip(label: '${bundle.nodes.length} screens'),
              _StatChip(label: '${bundle.capturedCount} captured'),
              _StatChip(label: '${bundle.flows.length} flows'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: VisualiserTheme.panelBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: VisualiserTheme.fg,
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onOpen,
    required this.onClear,
    required this.onFit,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onOpen;
  final VoidCallback onClear;
  final VoidCallback onFit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: VisualiserTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VisualiserTheme.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Zoom out',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove, size: 18),
          ),
          IconButton(
            tooltip: 'Zoom in',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add, size: 18),
          ),
          IconButton(
            tooltip: 'Fit view',
            onPressed: onFit,
            icon: const Icon(Icons.fit_screen, size: 18),
          ),
          IconButton(
            tooltip: 'Close map',
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Open .appmap'),
          ),
        ],
      ),
    );
  }
}

class _TransitionCard extends StatelessWidget {
  const _TransitionCard({
    required this.edge,
    required this.from,
    required this.to,
    required this.gestureKnown,
  });

  final GraphEdgeInfo edge;
  final AppMapNode? from;
  final AppMapNode? to;
  final bool gestureKnown;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      decoration: BoxDecoration(
        color: VisualiserTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VisualiserTheme.panelBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  from?.urlPath ?? edge.from,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexMono(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward, size: 16),
              ),
              Expanded(
                child: Text(
                  to?.urlPath ?? edge.to,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.ibmPlexMono(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (edge.observed) ...<Widget>[
            Text(
              'Observed during agent replay; not found by static analysis.',
              style: GoogleFonts.inter(
                color: VisualiserTheme.muted,
                fontSize: 11.5,
              ),
            ),
            if (edge.flows.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: edge.flows
                    .take(3)
                    .map((String flow) => _CodeChip(flow))
                    .toList(),
              ),
            ],
          ] else ...<Widget>[
            if (edge.raws.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: edge.raws
                    .map((String raw) => _CodeChip(raw))
                    .toList(),
              ),
            if (from?.file.isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'in ${from!.file}',
                style: GoogleFonts.ibmPlexMono(
                  color: VisualiserTheme.muted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Text(
            gestureKnown
                ? '◉ Trigger position shown on the source screen'
                : 'Trigger position not recorded — replay this transition to pin it',
            style: GoogleFonts.inter(
              color: gestureKnown
                  ? VisualiserTheme.cyan
                  : VisualiserTheme.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: VisualiserTheme.panelBorder),
      ),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.ibmPlexMono(fontSize: 10.5),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpen, required this.dragging, this.error});

  final VoidCallback onOpen;
  final bool dragging;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: dragging
          ? VisualiserTheme.accent.withValues(alpha: 0.06)
          : Colors.transparent,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.fromLTRB(36, 40, 36, 36),
          decoration: BoxDecoration(
            color: VisualiserTheme.panel,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: VisualiserTheme.panelBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 80,
                offset: const Offset(0, 32),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const SweepGradient(
                    colors: <Color>[
                      Color(0xFF818CF8),
                      Color(0xFF22D3EE),
                      Color(0xFF818CF8),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: VisualiserTheme.accent.withValues(alpha: 0.55),
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'appmap visualiser',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Drop an .appmap bundle to explore your app as a living map — every screen, every link, every agent flow.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: VisualiserTheme.muted,
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 30,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: dragging
                          ? VisualiserTheme.accent
                          : Colors.white.withValues(alpha: 0.18),
                      width: 1.5,
                    ),
                    color: dragging
                        ? VisualiserTheme.accent.withValues(alpha: 0.07)
                        : Colors.transparent,
                  ),
                  child: Text(
                    dragging
                        ? 'drop it!'
                        : 'drag a bundle here · or click to browse',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: dragging
                          ? VisualiserTheme.accentBright
                          : VisualiserTheme.muted,
                    ),
                  ),
                ),
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: VisualiserTheme.danger,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.7, -1.1),
          radius: 1.1,
          colors: <Color>[Color(0x21818CF8), Color(0x000A0C11)],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1.0, 1.2),
            radius: 0.9,
            colors: <Color>[Color(0x1222D3EE), Color(0x000A0C11)],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}
