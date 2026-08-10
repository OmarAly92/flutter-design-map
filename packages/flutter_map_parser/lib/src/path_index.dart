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

  /// Resolves an interpolated string body such as
  /// `${Routes.settings.root}/${Routes.settings.subscription}` or
  /// `${Routes.tutorials}/$contentId` into a concrete/templated path.
  String? resolveInterpolatedLiteral(String literal) {
    final String trimmed = literal.trim();
    if (!trimmed.contains(r'$')) {
      return trimmed;
    }
    final StringBuffer buffer = StringBuffer();
    int index = 0;
    while (index < trimmed.length) {
      final int dollar = trimmed.indexOf(r'$', index);
      if (dollar < 0) {
        buffer.write(trimmed.substring(index));
        break;
      }
      buffer.write(trimmed.substring(index, dollar));
      if (dollar + 1 < trimmed.length && trimmed[dollar + 1] == '{') {
        final int end = trimmed.indexOf('}', dollar + 2);
        if (end < 0) {
          return null;
        }
        final String expression = trimmed.substring(dollar + 2, end);
        final String? piece = _resolveInterpolationExpression(expression);
        if (piece == null) {
          return null;
        }
        buffer.write(piece);
        index = end + 1;
        continue;
      }
      final RegExpMatch? ident = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*')
          .firstMatch(trimmed.substring(dollar + 1));
      if (ident == null) {
        return null;
      }
      final String name = ident.group(0)!;
      final String piece = resolveReference(name) ?? _dynamicParam(name);
      buffer.write(piece);
      index = dollar + 1 + name.length;
    }
    final String resolved = buffer.toString();
    if (resolved.contains(r'$')) {
      return null;
    }
    return resolved;
  }

  String? _resolveInterpolationExpression(String expression) {
    final String trimmed = expression.trim();
    final String? reference = resolveReference(trimmed);
    if (reference != null) {
      return reference;
    }
    // `item.id`, `_event.id`, `activity.id` → `:id`
    final List<String> parts = trimmed.split('.');
    if (parts.length >= 2 &&
        RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(parts.last)) {
      return _dynamicParam(parts.last);
    }
    if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(trimmed)) {
      return _dynamicParam(trimmed);
    }
    return null;
  }

  String _dynamicParam(String name) {
    final String cleaned =
        name.startsWith('_') ? name.substring(1) : name;
    return ':$cleaned';
  }
}

class _PendingHelper {
  const _PendingHelper({
    required this.className,
    required this.name,
    required this.expression,
    required this.parameters,
  });

  final String className;
  final String name;
  final Expression expression;
  final FormalParameterList? parameters;
}

Map<String, String> _extractHelpers(
  CompilationUnit unit,
  ConstStringTable table,
) {
  final List<_PendingHelper> pending = <_PendingHelper>[];
  for (final CompilationUnitMember member in unit.declarations) {
    if (member is! ClassDeclaration) {
      continue;
    }
    final String className = member.name.lexeme;
    for (final ClassMember classMember in member.members) {
      if (classMember is! MethodDeclaration || !classMember.isStatic) {
        continue;
      }
      if (!classMember.isGetter && classMember.parameters == null) {
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
      pending.add(
        _PendingHelper(
          className: className,
          name: classMember.name.lexeme,
          expression: expression,
          parameters: classMember.isGetter ? null : classMember.parameters,
        ),
      );
    }
  }
  final Map<String, String> known = Map<String, String>.of(table.values);
  final Map<String, String> helpers = <String, String>{};
  bool progressed = true;
  final Set<String> remaining = <String>{
    for (final _PendingHelper helper in pending)
      '${helper.className}.${helper.name}',
  };
  while (progressed && remaining.isNotEmpty) {
    progressed = false;
    for (final _PendingHelper helper in pending) {
      final String key = '${helper.className}.${helper.name}';
      if (!remaining.contains(key)) {
        continue;
      }
      final String? template = _templateFromExpression(
        helper.expression,
        known: known,
        className: helper.className,
        parameters: helper.parameters,
      );
      if (template == null || !template.startsWith('/')) {
        continue;
      }
      helpers[key] = template;
      helpers.putIfAbsent(helper.name, () => template);
      known[key] = template;
      known.putIfAbsent(helper.name, () => template);
      remaining.remove(key);
      progressed = true;
    }
  }
  return helpers;
}

String? _templateFromExpression(
  Expression expression, {
  required Map<String, String> known,
  required String className,
  required FormalParameterList? parameters,
}) {
  final Set<String> paramNames = <String>{
    if (parameters != null)
      for (final FormalParameter parameter in parameters.parameters)
        parameter.name?.lexeme ?? '',
  }..remove('');
  return _renderTemplate(
    expression,
    known: known,
    className: className,
    paramNames: paramNames,
  );
}

String? _renderTemplate(
  Expression expression, {
  required Map<String, String> known,
  required String className,
  required Set<String> paramNames,
}) {
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
        final String? piece = _renderTemplate(
          element.expression,
          known: known,
          className: className,
          paramNames: paramNames,
        );
        if (piece == null) {
          return null;
        }
        buffer.write(piece);
      }
    }
    return buffer.toString();
  }
  if (expression is PrefixedIdentifier) {
    return _lookup(
      '${expression.prefix.name}.${expression.identifier.name}',
      known: known,
      className: className,
    );
  }
  if (expression is PropertyAccess) {
    final String? key = _propertyAccessKey(expression);
    if (key == null) {
      return null;
    }
    return _lookup(key, known: known, className: className);
  }
  if (expression is SimpleIdentifier) {
    if (paramNames.contains(expression.name)) {
      return ':${expression.name}';
    }
    return _lookup(expression.name, known: known, className: className);
  }
  return null;
}

String? _lookup(
  String reference, {
  required Map<String, String> known,
  required String className,
}) {
  if (known.containsKey(reference)) {
    return known[reference];
  }
  final String qualified = '$className.$reference';
  if (known.containsKey(qualified)) {
    return known[qualified];
  }
  return null;
}

String? _propertyAccessKey(PropertyAccess expression) {
  final List<String> parts = <String>[expression.propertyName.name];
  Expression? current = expression.target;
  while (current != null) {
    if (current is SimpleIdentifier) {
      parts.add(current.name);
      break;
    }
    if (current is PrefixedIdentifier) {
      parts
        ..add(current.identifier.name)
        ..add(current.prefix.name);
      break;
    }
    if (current is PropertyAccess) {
      parts.add(current.propertyName.name);
      current = current.target;
      continue;
    }
    return null;
  }
  return parts.reversed.join('.');
}
