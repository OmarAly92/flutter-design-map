import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:test/test.dart';

void main() {
  test('extracts sheet snap points and draggable extents', () {
    final List<StateHint> literal = extractStateHintsFromSource('''
      showModalBottomSheet(context: context, builder: (_) => Sheet());
      final snapPoints = ['25%', '50%', '90%'];
    ''');
    final List<StateHint> draggable = extractStateHintsFromSource('''
      DraggableScrollableSheet(
        minChildSize: 0.25,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
      );
    ''');

    expect(literal.single.snapPoints, <String>['25%', '50%', '90%']);
    expect(draggable.single.snapPoints, <String>['25%', '50%', '90%']);
  });
}
