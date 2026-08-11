import 'package:flutter_map_visualiser/main.dart';
import 'package:flutter_map_visualiser/startup_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows empty state brand', (WidgetTester tester) async {
    await tester.pumpWidget(const FlutterMapVisualiserApp());
    expect(find.text('appmap visualiser'), findsOneWidget);
    expect(find.textContaining('drag a bundle'), findsOneWidget);
  });

  testWidgets('stays on the drop zone when no bundle is served', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FlutterMapVisualiserApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('drag a bundle'), findsOneWidget);
    expect(find.text('bluesky'), findsNothing);
  });

  test('startup target defaults to app.appmap and has no demo fallback', () {
    expect(defaultBundleName, 'app.appmap');
    expect(bundleQueryParam, 'map');
    expect(hasExplicitBundleTarget, isFalse);
    expect(startupBundleUri(), isNull);
  });
}
