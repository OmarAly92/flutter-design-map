import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_map_parser/src/const_strings.dart';
import 'package:test/test.dart';

void main() {
  test('resolves class static const, interpolations, and record fields', () {
    const String source = '''
abstract class Routes {
  static const home = '/';
  static const idParam = 'id';
  static const detailsBase = 'details';
  static const details = '/\$detailsBase/:\$idParam';
  static const settings = (
    root: '/settings',
    theme: 'theme',
  );
}
''';
    final CompilationUnit unit = parseString(
      content: source,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    ).unit;
    final ConstStringTable table = ConstStringTable.fromUnit(unit);
    expect(_resolve(table, 'Routes.home'), '/');
    expect(_resolve(table, 'Routes.details'), '/details/:id');
    expect(_resolve(table, 'Routes.settings.root'), '/settings');
    expect(_resolve(table, 'Routes.settings.theme'), 'theme');
  });
}

String? _resolve(ConstStringTable table, String expressionSource) {
  final CompilationUnit unit = parseString(
    content: 'var x = $expressionSource;',
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final TopLevelVariableDeclaration decl =
      unit.declarations.first as TopLevelVariableDeclaration;
  final Expression expression = decl.variables.variables.first.initializer!;
  return table.resolveExpression(expression);
}
