import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map_visualiser/models/appmap_bundle.dart';
import 'package:flutter_map_visualiser/services/graph_edges.dart';
import 'package:flutter_map_visualiser/widgets/map_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'first pan continues from a programmatic transform without snapping',
    (WidgetTester tester) async {
      final TransformationController controller = TransformationController(
        Matrix4.identity()..translateByDouble(900, 0, 0, 1),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: MapCanvas(
                bundle: _emptyBundle,
                positions: const <String, Offset>{},
                edges: const <GraphEdgeInfo>[],
                canvasSize: const Size(2200, 1200),
                selectedId: null,
                pathIds: const <String>{},
                currentNodeId: null,
                neighbourIds: const <String>{},
                chosenStates: const <String, String?>{},
                stateOverrides: const <String, String>{},
                gesture: null,
                activeEdgeKeys: const <String>{},
                selectedEdgeKey: null,
                onSelect: (_) {},
                onEdgeSelect: (_) {},
                onStateSelect: (_, _) {},
                controller: controller,
              ),
            ),
          ),
        ),
      );

      final TestGesture drag = await tester.startGesture(
        const Offset(400, 300),
      );
      await drag.moveBy(const Offset(30, 0));
      await tester.pump();
      await drag.up();

      expect(controller.value.getTranslation().x, closeTo(930, 0.01));
    },
  );
}

const AppMapBundle _emptyBundle = AppMapBundle(
  manifest: AppMapManifest(
    formatVersion: 2,
    generator: 'test',
    appName: 'test',
    scheme: null,
    platform: null,
    mode: null,
    generatedAt: null,
  ),
  nodes: <AppMapNode>[],
  edges: <AppMapEdge>[],
  flows: <AppMapFlow>[],
  screenshots: <String, Uint8List>{},
);
