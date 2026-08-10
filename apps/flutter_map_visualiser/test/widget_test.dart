import 'package:flutter_map_visualiser/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows empty state brand', (WidgetTester tester) async {
    await tester.pumpWidget(const FlutterMapVisualiserApp());
    expect(find.text('appmap visualiser'), findsOneWidget);
    expect(find.textContaining('drag a bundle'), findsOneWidget);
  });

  testWidgets('opens the bundled demo after startup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FlutterMapVisualiserApp());
    await tester.pumpAndSettle();

    expect(find.text('bluesky'), findsOneWidget);
    expect(find.textContaining('screens'), findsWidgets);
  });
}
