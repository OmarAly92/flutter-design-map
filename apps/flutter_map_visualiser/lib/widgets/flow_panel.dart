import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/appmap_bundle.dart';
import '../services/flow_resolution.dart';
import '../theme/visualiser_theme.dart';

class FlowPanel extends StatelessWidget {
  const FlowPanel({
    super.key,
    required this.bundle,
    required this.selectedFlowName,
    required this.step,
    required this.flowsOpen,
    required this.onToggleOpen,
    required this.onSelectFlow,
    required this.onStepChange,
    required this.neighboursMode,
    required this.onNeighboursMode,
  });

  final AppMapBundle bundle;
  final String? selectedFlowName;
  final int step;
  final bool flowsOpen;
  final VoidCallback onToggleOpen;
  final ValueChanged<String?> onSelectFlow;
  final ValueChanged<int> onStepChange;
  final bool neighboursMode;
  final VoidCallback onNeighboursMode;

  @override
  Widget build(BuildContext context) {
    final AppMapFlow? flow = selectedFlowName == null
        ? null
        : bundle.flowByName(selectedFlowName!);
    final List<AppMapFlow> interactive = bundle.flows
        .where((AppMapFlow f) => f.isInteractive)
        .toList();
    final List<AppMapFlow> listed = interactive.isNotEmpty
        ? interactive
        : bundle.flows;
    final Duration panelMotion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    final Duration stateMotion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140);
    return AnimatedSize(
      duration: panelMotion,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 520),
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
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: onToggleOpen,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: <Widget>[
                    Text(
                      'Agent flows',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${bundle.flows.length}',
                      style: GoogleFonts.inter(
                        color: VisualiserTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: flowsOpen ? 0.5 : 0,
                      duration: panelMotion,
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.expand_more,
                        size: 18,
                        color: VisualiserTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (flowsOpen)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: listed.length,
                  itemBuilder: (BuildContext context, int index) {
                    final AppMapFlow item = listed[index];
                    final bool active = item.name == selectedFlowName;
                    return InkWell(
                      onTap: () => onSelectFlow(active ? null : item.name),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: stateMotion,
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? VisualiserTheme.accent.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? VisualiserTheme.accent.withValues(alpha: 0.35)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Text(
                              item.isInteractive ? '✦' : '◎',
                              style: TextStyle(
                                color: item.isInteractive
                                    ? VisualiserTheme.cyan
                                    : VisualiserTheme.muted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (flow != null)
              _PlaybackBar(
                bundle: bundle,
                flow: flow,
                step: step,
                neighboursMode: neighboursMode,
                onStepChange: onStepChange,
                onNeighboursMode: onNeighboursMode,
                onSelectFlow: onSelectFlow,
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackBar extends StatelessWidget {
  const _PlaybackBar({
    required this.bundle,
    required this.flow,
    required this.step,
    required this.neighboursMode,
    required this.onStepChange,
    required this.onNeighboursMode,
    required this.onSelectFlow,
  });

  final AppMapBundle bundle;
  final AppMapFlow flow;
  final int step;
  final bool neighboursMode;
  final ValueChanged<int> onStepChange;
  final VoidCallback onNeighboursMode;
  final ValueChanged<String?> onSelectFlow;

  @override
  Widget build(BuildContext context) {
    final StepView view = buildStepView(flow, step);
    AppMapFlow? nav;
    AppMapFlow? visit;
    for (final AppMapFlow candidate in bundle.flows) {
      if (candidate.route != flow.route) {
        continue;
      }
      if (nav == null && candidate.name.startsWith('nav-')) {
        nav = candidate;
      }
      if (visit == null &&
          (candidate.name.startsWith('visit-') ||
              candidate.name.startsWith('deeplink-'))) {
        visit = candidate;
      }
    }
    final bool isVisit =
        flow.name.startsWith('visit-') || flow.name.startsWith('deeplink-');
    String caption;
    if (neighboursMode) {
      caption = 'Neighbourhood mode';
    } else if (view.visibleIndexes.isEmpty) {
      caption = flow.title;
    } else {
      final int nextVisible = view.position + 1 < view.length
          ? view.visibleIndexes[view.position + 1]
          : view.visibleIndexes[view.position];
      final FlowStep vis = flow.steps[view.visibleIndexes[view.position]];
      final FlowStep? next = view.position + 1 < view.length
          ? flow.steps[nextVisible]
          : null;
      caption = next == null
          ? 'arrived — ${describeStep(vis)}'
          : describeStep(next);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: VisualiserTheme.panelBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            neighboursMode
                ? 'Neighbours of ${flow.route ?? flow.name}'
                : flow.title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              if (nav != null || !isVisit)
                _ModeChip(
                  label: 'navigate',
                  active: !isVisit && !neighboursMode,
                  onTap: nav == null
                      ? null
                      : () {
                          final AppMapFlow selected = nav!;
                          onSelectFlow(selected.name);
                          onStepChange(
                            selected.steps.isEmpty
                                ? 0
                                : selected.steps.length - 1,
                          );
                        },
                ),
              if (visit != null)
                _ModeChip(
                  label: 'deep link',
                  active: isVisit && !neighboursMode,
                  onTap: () {
                    final AppMapFlow selected = visit!;
                    onSelectFlow(selected.name);
                    onStepChange(
                      selected.steps.isEmpty ? 0 : selected.steps.length - 1,
                    );
                  },
                ),
              _ModeChip(
                label: 'neighbours',
                active: neighboursMode,
                onTap: onNeighboursMode,
              ),
              if (!neighboursMode)
                Text(
                  '${view.position + 1} / ${view.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: VisualiserTheme.muted,
                  ),
                ),
            ],
          ),
          if (!neighboursMode) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _IconBtn(
                  icon: Icons.replay,
                  enabled: view.position > 0,
                  onTap: () => onStepChange(
                    stepViewEffectiveEnd(flow, view.visibleIndexes, 0),
                  ),
                ),
                _IconBtn(
                  icon: Icons.chevron_left,
                  enabled: view.position > 0,
                  onTap: () => onStepChange(
                    stepViewEffectiveEnd(
                      flow,
                      view.visibleIndexes,
                      view.position - 1,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      for (int k = 0; k < view.visibleIndexes.length; k++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 1.5,
                            ),
                            child: InkWell(
                              onTap: () => onStepChange(
                                stepViewEffectiveEnd(
                                  flow,
                                  view.visibleIndexes,
                                  k,
                                ),
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                height: 6,
                                decoration: BoxDecoration(
                                  color: k <= view.position
                                      ? VisualiserTheme.accentBright
                                      : Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _IconBtn(
                  icon: Icons.chevron_right,
                  enabled: view.position < view.length - 1,
                  onTap: () => onStepChange(
                    stepViewEffectiveEnd(
                      flow,
                      view.visibleIndexes,
                      view.position + 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 10.5,
                color: VisualiserTheme.muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  final String cmd = replayCommand(
                    flow,
                    bundle.manifest.appName,
                  );
                  await Clipboard.setData(ClipboardData(text: cmd));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied replay · ${flow.name}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Copy replay'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? VisualiserTheme.accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active
                ? VisualiserTheme.accent.withValues(alpha: 0.45)
                : VisualiserTheme.panelBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active
                ? VisualiserTheme.accentBright
                : VisualiserTheme.muted,
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 18),
    );
  }
}
