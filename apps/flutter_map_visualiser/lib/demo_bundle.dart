import 'package:flutter/services.dart';

const String demoBundleAsset = 'assets/bluesky-demo.appmap';

/// Loads the full captured Bluesky demo bundled with the visualizer.
Future<Uint8List> loadDemoBundleBytes() async {
  final ByteData data = await rootBundle.load(demoBundleAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
