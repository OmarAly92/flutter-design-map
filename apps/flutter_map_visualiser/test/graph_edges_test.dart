import 'dart:typed_data';

import 'package:flutter_map_visualiser/models/appmap_bundle.dart';
import 'package:flutter_map_visualiser/services/flow_resolution.dart';
import 'package:flutter_map_visualiser/services/graph_edges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds observed transitions and active-flow synthetic gaps', () {
    final AppMapBundle bundle = AppMapBundle(
      manifest: _manifest,
      nodes: <AppMapNode>[
        _node('home', '/'),
        _node('details', '/details/:id'),
        _node('settings', '/settings'),
      ],
      edges: <AppMapEdge>[
        AppMapEdge(
          from: 'home',
          to: 'details',
          raw: "context.go('/details/1')",
          target: '/details/1',
        ),
      ],
      flows: <AppMapFlow>[
        AppMapFlow(
          name: 'nav-settings',
          title: 'Settings',
          route: 'settings',
          pointSize: <double>[1, 1],
          steps: <FlowStep>[
            FlowStep(action: 'open_url', url: 'demo:///'),
            FlowStep(
              action: 'tap',
              coordinate: <double>[0.5, 0.8],
              target: 'Details',
              screen: 'details',
            ),
            FlowStep(action: 'launch', screen: 'settings'),
          ],
        ),
      ],
      screenshots: <String, Uint8List>{},
    );
    final FlowResolution resolution = FlowResolution.fromBundle(bundle);

    final List<GraphEdgeInfo> edges = buildGraphEdges(
      bundle,
      resolution,
      activeFlowName: 'nav-settings',
    );

    expect(edges.map((GraphEdgeInfo edge) => edge.key), <String>[
      'details→settings',
      'home→details',
    ]);
    expect(edges.first.synthetic, isTrue);
    expect(edges.last.observed, isFalse);
    expect(edges.last.raws, <String>["context.go('/details/1')"]);
  });

  test('uses a recorded transition to pin its source gesture', () {
    final AppMapBundle bundle = AppMapBundle(
      manifest: _manifest,
      nodes: <AppMapNode>[_node('home', '/'), _node('settings', '/settings')],
      edges: <AppMapEdge>[],
      flows: <AppMapFlow>[
        AppMapFlow(
          name: 'nav-settings',
          title: 'Settings',
          route: 'settings',
          pointSize: <double>[1, 1],
          steps: <FlowStep>[
            FlowStep(action: 'open_url', url: 'demo:///'),
            FlowStep(
              action: 'tap',
              coordinate: <double>[0.25, 0.75],
              target: 'Settings',
              screen: 'settings',
            ),
          ],
        ),
      ],
      screenshots: <String, Uint8List>{},
    );
    final FlowResolution resolution = FlowResolution.fromBundle(bundle);
    final GraphEdgeInfo edge = buildGraphEdges(bundle, resolution).single;

    final FlowGesture? gesture = gestureForEdge(bundle, resolution, edge);

    expect(edge.observed, isTrue);
    expect(gesture?.type, 'tap');
    expect(gesture?.x, 0.25);
    expect(gesture?.y, 0.75);
    expect(gesture?.label, 'Settings');
  });

  test('finds the exact flow step that captured a selected state', () {
    final AppMapBundle bundle = AppMapBundle(
      manifest: _manifest,
      nodes: <AppMapNode>[
        AppMapNode(
          id: 'home',
          urlPath: '/',
          file: 'home.dart',
          slug: 'home',
          group: '',
          params: const <String>[],
          capture: const CaptureInfo(
            status: 'ok',
            needsNavigation: false,
            states: <CaptureState>[
              CaptureState(
                name: 'drawer',
                screenshot: 'screens/home--drawer.png',
              ),
            ],
          ),
        ),
      ],
      edges: const <AppMapEdge>[],
      flows: const <AppMapFlow>[
        AppMapFlow(
          name: 'open-drawer',
          title: 'Open drawer',
          route: 'home',
          steps: <FlowStep>[
            FlowStep(action: 'tap'),
            FlowStep(action: 'screenshot', capture: 'home--drawer.png'),
          ],
        ),
      ],
      screenshots: const <String, Uint8List>{},
    );

    final ({AppMapFlow flow, int step})? result = flowStepForState(
      bundle,
      'home',
      'drawer',
    );

    expect(result?.flow.name, 'open-drawer');
    expect(result?.step, 1);
  });
}

const AppMapManifest _manifest = AppMapManifest(
  formatVersion: 2,
  generator: 'test',
  appName: 'test',
  scheme: 'demo',
  platform: 'test',
  mode: 'test',
  generatedAt: null,
);

AppMapNode _node(String id, String path) => AppMapNode(
  id: id,
  urlPath: path,
  file: '$id.dart',
  slug: id,
  group: '',
  params: <String>[],
  capture: CaptureInfo(
    status: 'missing',
    needsNavigation: false,
    states: <CaptureState>[],
  ),
);
