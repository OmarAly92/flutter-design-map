import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_map_visualiser/models/appmap_bundle.dart';
import 'package:flutter_map_visualiser/services/appmap_loader.dart';
import 'package:flutter_map_visualiser/services/flow_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads the bundled Bluesky .appmap fixture', () {
    final File file = File('assets/bluesky-demo.appmap');
    final AppMapBundle bundle = const AppMapLoader().loadBytes(
      Uint8List.fromList(file.readAsBytesSync()),
    );
    expect(bundle.manifest.appName, 'bluesky');
    expect(bundle.nodes, hasLength(70));
    expect(bundle.edges, hasLength(56));
    expect(bundle.screenshots, isNotEmpty);
    expect(bundle.flows, isNotEmpty);
    expect(bundle.flows.first.steps, isNotEmpty);
    final FlowResolution resolution = FlowResolution.fromBundle(bundle);
    expect(resolution.paths, isNotEmpty);
  });
}
