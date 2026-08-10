import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../layout/graph_layout.dart';
import '../models/appmap_bundle.dart';
import '../theme/visualiser_theme.dart';

class NodeCard extends StatelessWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.screenshotBytes,
    required this.isSelected,
    required this.isDimmed,
    required this.isCurrent,
    required this.onPath,
    required this.onTap,
    this.chosenState,
    this.onStateSelect,
    this.gesture,
  });

  final AppMapNode node;
  final Uint8List? screenshotBytes;
  final bool isSelected;
  final bool isDimmed;
  final bool isCurrent;
  final bool onPath;
  final VoidCallback onTap;
  final String? chosenState;
  final ValueChanged<String?>? onStateSelect;
  final FlowGesture? gesture;

  @override
  Widget build(BuildContext context) {
    final BrokenStatus? broken = BrokenStatus.forCapture(node.capture.status);
    final String? badge = _badgeText(node);
    CaptureState? activeState;
    if (chosenState != null) {
      for (final CaptureState state in node.capture.states) {
        if (state.name == chosenState) {
          activeState = state;
          break;
        }
      }
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      opacity: isDimmed ? 0.14 : 1,
      child: SizedBox(
        width: kNodeWidth,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            // Tap-only — avoid InkWell/drag recognizers fighting canvas pans.
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _PhoneFrame(
                  isSelected: isSelected || onPath,
                  isCurrent: isCurrent,
                  isBroken: broken != null && activeState == null,
                  bytes: screenshotBytes,
                  broken: activeState == null ? broken : null,
                  fixHint: _fixHint(node),
                  stateTag: activeState?.name,
                  gesture: gesture,
                ),
                const SizedBox(height: 8),
                _PathLabel(node: node),
                if (node.capture.states.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  _StateSelect(
                    states: node.capture.states,
                    value: chosenState,
                    onChanged: onStateSelect,
                  ),
                ],
                if (badge != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    badge,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: VisualiserTheme.warn,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _badgeText(AppMapNode node) {
    if (node.capture.needsNavigation) {
      return '⚠ needs navigation';
    }
    if (node.capture.status.isNotEmpty &&
        node.capture.status != 'ok' &&
        node.capture.status != 'missing') {
      return '⚠ ${node.capture.status}';
    }
    return null;
  }

  String _fixHint(AppMapNode node) {
    if (node.capture.note != null && node.capture.note!.isNotEmpty) {
      return node.capture.note!;
    }
    if (node.capture.needsNavigation) {
      return 'Reach via in-app navigation — see its flow.';
    }
    if (node.capture.status == 'loading') {
      return 'Re-capture with a longer wait or real data.';
    }
    return 'Re-run the sweep for this route.';
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({
    required this.isSelected,
    required this.isCurrent,
    required this.isBroken,
    required this.bytes,
    required this.fixHint,
    this.broken,
    this.stateTag,
    this.gesture,
  });

  final bool isSelected;
  final bool isCurrent;
  final bool isBroken;
  final Uint8List? bytes;
  final BrokenStatus? broken;
  final String fixHint;
  final String? stateTag;
  final FlowGesture? gesture;

  @override
  Widget build(BuildContext context) {
    final List<BoxShadow> shadows = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 1,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.4),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 48,
        offset: const Offset(0, 24),
      ),
    ];
    if (isCurrent) {
      shadows.addAll(<BoxShadow>[
        BoxShadow(
          color: VisualiserTheme.cyan.withValues(alpha: 0.95),
          blurRadius: 0,
          spreadRadius: 3,
        ),
        BoxShadow(
          color: VisualiserTheme.cyan.withValues(alpha: 0.5),
          blurRadius: 42,
        ),
      ]);
    } else if (isSelected) {
      shadows.addAll(<BoxShadow>[
        BoxShadow(
          color: VisualiserTheme.accentBright.withValues(alpha: 0.9),
          blurRadius: 0,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: VisualiserTheme.accent.withValues(alpha: 0.35),
          blurRadius: 28,
        ),
      ]);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: kNodeWidth,
      padding: const EdgeInsets.all(kPhoneBezel),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kPhoneRadius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1D212B), Color(0xFF12151D)],
        ),
        boxShadow: shadows,
      ),
      child: AspectRatio(
        aspectRatio: kPhoneAspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kScreenRadius),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (bytes != null)
                isBroken
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2,
                          0.2,
                          0.2,
                          0,
                          0,
                          0.2,
                          0.2,
                          0.2,
                          0,
                          0,
                          0.2,
                          0.2,
                          0.2,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: Opacity(
                          opacity: 0.45,
                          child: Image.memory(
                            bytes!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      )
                    : Image.memory(
                        bytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
              else
                CustomPaint(painter: _HatchPainter()),
              if (bytes == null)
                Center(
                  child: Text(
                    'no capture',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: VisualiserTheme.muted,
                    ),
                  ),
                ),
              if (broken != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        const Color(0xFF0A0C11).withValues(alpha: 0.25),
                        const Color(0xFF0A0C11).withValues(alpha: 0.66),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          broken!.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          broken!.label.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: VisualiserTheme.warn,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fixHint,
                          textAlign: TextAlign.center,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            height: 1.45,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (stateTag != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xC7080A0F),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: VisualiserTheme.cyan.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        stateTag!,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: VisualiserTheme.cyan,
                        ),
                      ),
                    ),
                  ),
                ),
              if (gesture != null) _GestureOverlay(gesture: gesture!),
              // Inner screen outline
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kScreenRadius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GestureOverlay extends StatelessWidget {
  const _GestureOverlay({required this.gesture});

  final FlowGesture gesture;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (gesture.type == 'tap') {
          return Stack(
            children: <Widget>[
              Positioned(
                left: gesture.x * constraints.maxWidth - 11,
                top: gesture.y * constraints.maxHeight - 11,
                child: const _TapMarker(),
              ),
            ],
          );
        }
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _SwipePainter(gesture: gesture),
        );
      },
    );
  }
}

class _TapMarker extends StatefulWidget {
  const _TapMarker();

  @override
  State<_TapMarker> createState() => _TapMarkerState();
}

class _TapMarkerState extends State<_TapMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOut.transform(_controller.value);
        return SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Transform.scale(
                scale: 1 + t * 1.4,
                child: Opacity(
                  opacity: 1 - t,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: VisualiserTheme.cyan.withValues(alpha: 0.8),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VisualiserTheme.cyan.withValues(alpha: 0.35),
                  border: Border.all(color: VisualiserTheme.cyan, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: VisualiserTheme.cyan.withValues(alpha: 0.7),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwipePainter extends CustomPainter {
  _SwipePainter({required this.gesture});

  final FlowGesture gesture;

  @override
  void paint(Canvas canvas, Size size) {
    if (gesture.x2 == null || gesture.y2 == null) {
      return;
    }
    final Offset a = Offset(gesture.x * size.width, gesture.y * size.height);
    final Offset b = Offset(
      gesture.x2! * size.width,
      gesture.y2! * size.height,
    );
    final Paint paint = Paint()
      ..color = VisualiserTheme.cyan
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, paint);
    final double angle = (b - a).direction;
    final Path head = Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo(
        b.dx - 8 * math.cos(angle - 0.4),
        b.dy - 8 * math.sin(angle - 0.4),
      )
      ..moveTo(b.dx, b.dy)
      ..lineTo(
        b.dx - 8 * math.cos(angle + 0.4),
        b.dy - 8 * math.sin(angle + 0.4),
      );
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant _SwipePainter oldDelegate) {
    return oldDelegate.gesture != gesture;
  }
}

class _PathLabel extends StatelessWidget {
  const _PathLabel({required this.node});

  final AppMapNode node;

  @override
  Widget build(BuildContext context) {
    final Color dot = VisualiserTheme.groupColor(node.group);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dot,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(color: dot.withValues(alpha: 0.6), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            node.urlPath,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10.5,
              color: VisualiserTheme.fg,
            ),
          ),
        ),
      ],
    );
  }
}

class _StateSelect extends StatelessWidget {
  const _StateSelect({
    required this.states,
    required this.value,
    required this.onChanged,
  });

  final List<CaptureState> states;
  final String? value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xB3080A0F),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: VisualiserTheme.cyan.withValues(alpha: 0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          isExpanded: true,
          dropdownColor: VisualiserTheme.panelSolid,
          iconEnabledColor: VisualiserTheme.cyan,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFA5F3FC),
          ),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'base screen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...states.map(
              (CaptureState state) => DropdownMenuItem<String?>(
                value: state.name,
                child: Text(
                  state.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF12151D),
    );
    final Paint hatch = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (double i = -size.height; i < size.width; i += 11) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        hatch,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
