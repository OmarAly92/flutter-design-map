import '../models/appmap_bundle.dart';

/// Resolves flow deep-links and screen hops onto node ids.
class FlowResolution {
  const FlowResolution({required this.paths, required this.nodeAtStep});

  final Map<String, List<String>> paths;
  final Map<String, List<String?>> nodeAtStep;

  factory FlowResolution.fromBundle(AppMapBundle bundle) {
    final List<_Matcher> matchers = bundle.nodes
        .map((AppMapNode n) => _Matcher(n.id, _matcherFor(n.urlPath)))
        .toList();
    final Set<String> nodeIds = bundle.nodes
        .map((AppMapNode n) => n.id)
        .toSet();
    String? resolveUrl(String url) {
      String path = url.replaceFirst(
        RegExp(r'^[a-z+.-]+:/+', caseSensitive: false),
        '',
      );
      path = '/${path.replaceFirst(RegExp(r'^/+'), '')}';
      path = path.split(RegExp(r'[?#]')).first;
      final String normalized = path.isEmpty ? '/' : path;
      for (final _Matcher matcher in matchers) {
        if (matcher.re.hasMatch(normalized)) {
          return matcher.id;
        }
      }
      return null;
    }

    final Map<String, List<String>> paths = <String, List<String>>{};
    final Map<String, List<String?>> nodeAtStep = <String, List<String?>>{};
    for (final AppMapFlow flow in bundle.flows) {
      final List<String> nodes = <String>[];
      final List<String?> perStep = <String?>[];
      String? current;
      for (final FlowStep step in flow.steps) {
        if (step.action == 'open_url' && step.url != null) {
          current = resolveUrl(step.url!) ?? current;
        }
        if (step.screen != null && nodeIds.contains(step.screen)) {
          current = step.screen;
        }
        if (current != null && (nodes.isEmpty || nodes.last != current)) {
          nodes.add(current);
        }
        perStep.add(current);
      }
      if (flow.route != null && !nodes.contains(flow.route)) {
        nodes.add(flow.route!);
      }
      paths[flow.name] = nodes;
      nodeAtStep[flow.name] = perStep
          .map(
            (String? id) =>
                id ?? flow.route ?? (nodes.isEmpty ? null : nodes.first),
          )
          .toList();
    }
    return FlowResolution(paths: paths, nodeAtStep: nodeAtStep);
  }
}

class _Matcher {
  const _Matcher(this.id, this.re);
  final String id;
  final RegExp re;
}

RegExp _matcherFor(String urlPath) {
  final String re = urlPath
      .split('/')
      .map((String seg) {
        if (seg.startsWith('[...')) {
          return '.+';
        }
        if (seg.startsWith('[') || seg.startsWith(':')) {
          return '[^/]+';
        }
        return RegExp.escape(seg);
      })
      .join('/');
  return RegExp('^$re/?\$');
}

/// Best flow for arriving at a node.
AppMapFlow? flowForNode(AppMapBundle bundle, String nodeId) {
  final List<AppMapFlow> candidates = bundle.flows
      .where((AppMapFlow f) => f.route == nodeId)
      .toList();
  if (candidates.isEmpty) {
    return null;
  }
  for (final AppMapFlow flow in candidates) {
    if (flow.name.startsWith('nav-')) {
      return flow;
    }
  }
  final AppMapNode? node = bundle.nodeById(nodeId);
  final List<AppMapFlow> interactive = candidates
      .where((AppMapFlow f) => f.isInteractive)
      .toList();
  if (node?.capture.needsNavigation == true && interactive.isNotEmpty) {
    return interactive.first;
  }
  for (final AppMapFlow flow in candidates) {
    if (!flow.isInteractive) {
      return flow;
    }
  }
  return candidates.first;
}

({AppMapFlow flow, int step})? flowStepForState(
  AppMapBundle bundle,
  String nodeId,
  String stateName,
) {
  final AppMapNode? node = bundle.nodeById(nodeId);
  if (node == null) {
    return null;
  }
  CaptureState? state;
  for (final CaptureState candidate in node.capture.states) {
    if (candidate.name == stateName) {
      state = candidate;
      break;
    }
  }
  if (state == null) {
    return null;
  }
  for (final AppMapFlow flow in bundle.flows) {
    for (int i = 0; i < flow.steps.length; i++) {
      final FlowStep step = flow.steps[i];
      if (step.action != 'screenshot' || step.capture == null) {
        continue;
      }
      final String capture = step.capture!.startsWith('screens/')
          ? step.capture!
          : 'screens/${step.capture}';
      if (capture == state.screenshot) {
        return (flow: flow, step: i);
      }
    }
  }
  return null;
}

class StepView {
  const StepView({required this.visibleIndexes, required this.position});

  final List<int> visibleIndexes;
  final int position;

  int get length => visibleIndexes.length;
}

StepView buildStepView(AppMapFlow flow, int step) {
  final List<int> visible = <int>[];
  for (int i = 0; i < flow.steps.length; i++) {
    if (!flow.steps[i].isHidden) {
      visible.add(i);
    }
  }
  if (visible.isEmpty && flow.steps.isNotEmpty) {
    visible.add(0);
  }
  int pos = 0;
  for (int i = 0; i < visible.length; i++) {
    if (visible[i] <= step) {
      pos = i;
    }
  }
  return StepView(visibleIndexes: visible, position: pos);
}

int stepViewEffectiveEnd(AppMapFlow flow, List<int> visible, int visiblePos) {
  if (visible.isEmpty) {
    return 0;
  }
  final int clamped = visiblePos.clamp(0, visible.length - 1);
  if (clamped + 1 < visible.length) {
    return visible[clamped + 1] - 1;
  }
  return flow.steps.isEmpty ? 0 : flow.steps.length - 1;
}

FlowGesture? gestureForStep(AppMapFlow flow, int step) {
  const Set<String> hidden = <String>{'wait', 'screenshot'};
  int next = step + 1;
  while (next < flow.steps.length && hidden.contains(flow.steps[next].action)) {
    next++;
  }
  if (next >= flow.steps.length) {
    return null;
  }
  final FlowStep st = flow.steps[next];
  final List<double> pt = flow.pointSize;
  if (st.action == 'tap' &&
      st.coordinate != null &&
      st.coordinate!.length >= 2) {
    return FlowGesture.tap(
      x: st.coordinate![0] / pt[0],
      y: st.coordinate![1] / pt[1],
      label: st.target,
    );
  }
  if (st.action == 'swipe' &&
      st.from != null &&
      st.to != null &&
      st.from!.length >= 2 &&
      st.to!.length >= 2) {
    return FlowGesture.swipe(
      x: st.from![0] / pt[0],
      y: st.from![1] / pt[1],
      endX: st.to![0] / pt[0],
      endY: st.to![1] / pt[1],
    );
  }
  return null;
}

/// State capture overrides implied by screenshots up to [step].
Map<String, String> stateOverridesAtStep(
  AppMapBundle bundle,
  AppMapFlow flow,
  int step,
) {
  final Map<String, String> overrides = <String, String>{};
  final int end = step.clamp(0, flow.steps.isEmpty ? 0 : flow.steps.length - 1);
  for (int i = 0; i <= end && i < flow.steps.length; i++) {
    final FlowStep st = flow.steps[i];
    if (st.action != 'screenshot' || st.capture == null) {
      continue;
    }
    final String file = st.capture!.startsWith('screens/')
        ? st.capture!
        : 'screens/${st.capture}';
    for (final AppMapNode node in bundle.nodes) {
      for (final CaptureState state in node.capture.states) {
        if (state.screenshot == file) {
          overrides[node.id] = state.name;
        }
      }
    }
  }
  return overrides;
}

String describeStep(FlowStep step) {
  switch (step.action) {
    case 'open_url':
      return 'deep link ${step.url ?? ''}';
    case 'tap':
      return 'tap ${step.target ?? step.coordinate?.join(',') ?? ''}';
    case 'swipe':
      return 'swipe';
    case 'type':
      return 'type ${step.text ?? ''}';
    case 'launch':
      return 'launch';
    default:
      return step.action;
  }
}

String replayCommand(AppMapFlow flow, String appName) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('# $appName · replay flow "${flow.name}" — ${flow.title}')
    ..writeln('# run from the app project root')
    ..writeln(
      'npx @swmansion/argent flow run .flutter-map/flows/${flow.name}.yaml',
    );
  if (!flow.isInteractive) {
    final List<FlowStep> links = flow.steps
        .where((FlowStep s) => s.action == 'open_url' && s.url != null)
        .toList();
    if (links.isNotEmpty) {
      buffer
        ..writeln('#')
        ..writeln('# no-tooling fallback (plain deep link):');
      for (final FlowStep step in links) {
        buffer.writeln('# xcrun simctl openurl booted "${step.url}"');
      }
    }
  }
  return buffer.toString();
}
