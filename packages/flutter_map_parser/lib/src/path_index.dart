import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_map_parser/src/const_strings.dart';
import 'package:path/path.dart' as p;

/// Project-wide path constants and static path-builder helpers.
class ProjectPathIndex {
  ProjectPathIndex({
    required this.constants,
    required this.helpers,
  });

  final Map<String, String> constants;
  final Map<String, String> helpers;

  static ProjectPathIndex fromProject(String projectRoot) {
    final Map<String, String> constants = <String, String>{};
    final Map<String, String> helpers = <String, String>{};
    final Directory libDirectory = Directory(p.join(projectRoot, 'lib'));
    if (!libDirectory.existsSync()) {
      return ProjectPathIndex(constants: constants, helpers: helpers);
    }
    for (final FileSystemEntity entity
        in libDirectory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.endsWith('.g.dart') || entity.path.endsWith('.gr.dart')) {
        continue;
      }
      final CompilationUnit unit = parseString(
        content: entity.readAsStringSync(),
        path: entity.path,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      ).unit;
      final ConstStringTable table = ConstStringTable.fromUnit(unit);
      constants.addAll(table.values);
      helpers.addAll(_extractHelpers(unit, table));
    }
    return ProjectPathIndex(constants: constants, helpers: helpers);
  }

  /// Resolves `AppPaths.eventHub`, `Routes.settings.root`, or
  /// `AppPaths.hostDashboardScreen(...)` into a concrete/templated path.
  String? resolveReference(String reference) {
    final String trimmed = reference.trim();
    if (helpers.containsKey(trimmed)) {
      return helpers[trimmed];
    }
    if (constants.containsKey(trimmed)) {
      return constants[trimmed];
    }
    return null;
  }
}

Map<String, String> _extractHelpers(
  CompilationUnit unit,
  ConstStringTable table,
) {
  final Map<String, String> helpers = <String, String>{};
  for (final CompilationUnitMember member in unit.declarations) {
    if (member is! ClassDeclaration) {
      continue;
    }
    final String className = member.name.lexeme;
    for (final ClassMember classMember in member.members) {
      if (classMember is! MethodDeclaration || !classMember.isStatic) {
        continue;
      }
      final FunctionBody body = classMember.body;
      Expression? expression;
      if (body is ExpressionFunctionBody) {
        expression = body.expression;
      } else if (body is BlockFunctionBody) {
        for (final Statement statement in body.block.statements) {
          if (statement is ReturnStatement) {
            expression = statement.expression;
            break;
          }
        }
      }
      if (expression == null) {
        continue;
      }
      final String? template = _templateFromExpression(
        expression,
        table,
        classMember.parameters,
      );
      if (template == null || !template.startsWith('/')) {
        continue;
      }
      helpers['$className.${classMember.name.lexeme}'] = template;
    }
  }
  return helpers;
}

String? _templateFromExpression(
  Expression expression,
  ConstStringTable table,
  FormalParameterList? parameters,
) {
  final Set<String> paramNames = <String>{
    if (parameters != null)
      for (final FormalParameter parameter in parameters.parameters)
        parameter.name?.lexeme ?? '',
  }..remove('');
  return _renderTemplate(expression, table, paramNames);
}

String? _renderTemplate(
  Expression expression,
  ConstStringTable table,
  Set<String> paramNames,
) {
  final String? constant = table.resolveExpression(expression);
  if (constant != null) {
    return constant;
  }
  if (expression is SimpleStringLiteral) {
    return expression.value;
  }
  if (expression is StringInterpolation) {
    final StringBuffer buffer = StringBuffer();
    for (final InterpolationElement element in expression.elements) {
      if (element is InterpolationString) {
        buffer.write(element.value);
        continue;
      }
      if (element is InterpolationExpression) {
        final String? piece =
            _renderTemplate(element.expression, table, paramNames);
        if (piece == null) {
          return null;
        }
        buffer.write(piece);
      }
    }
    return buffer.toString();
  }
  if (expression is PrefixedIdentifier || expression is PropertyAccess) {
    return table.resolveExpression(expression);
  }
  if (expression is SimpleIdentifier) {
    if (paramNames.contains(expression.name)) {
      return ':${expression.name}';
    }
    return table.resolveExpression(expression);
  }
  return null;
}
