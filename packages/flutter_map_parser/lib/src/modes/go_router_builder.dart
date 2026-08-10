import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_map_parser/src/model.dart';
import 'package:path/path.dart' as p;

/// Result of parsing `@TypedGoRoute` / `@TypedShellRoute` trees.
class GoRouterBuilderParseResult {
  const GoRouterBuilderParseResult({
    required this.routes,
    required this.layouts,
    required this.routerFile,
  });

  final List<RouteNode> routes;
  final List<LayoutNode> layouts;
  final String? routerFile;
}

/// Parses go_router_builder typed route annotations under [projectRoot]/lib.
GoRouterBuilderParseResult parseGoRouterBuilderProject(String projectRoot) {
  final List<_DartUnit> units = _loadDartUnits(projectRoot);
  final Map<String, _RouteClassInfo> classesByName = <String, _RouteClassInfo>{};
  for (final _DartUnit unit in units) {
    for (final ClassDeclaration declaration
        in unit.unit.declarations.whereType<ClassDeclaration>()) {
      final String className = declaration.name.lexeme;
      classesByName[className] = _RouteClassInfo(
        className: className,
        filePath: unit.filePath,
        declaration: declaration,
      );
    }
  }
  final List<RouteNode> routes = <RouteNode>[];
  final List<LayoutNode> layouts = <LayoutNode>[];
  String? routerFile;
  final Set<String> seenIds = <String>{};
  for (final _RouteClassInfo info in classesByName.values) {
    final Annotation? typedGoRoute = _findAnnotation(
      info.declaration,
      <String>{'TypedGoRoute'},
    );
    final Annotation? typedShellRoute = _findAnnotation(
      info.declaration,
      <String>{'TypedShellRoute', 'TypedStatefulShellRoute'},
    );
    if (typedShellRoute != null) {
      routerFile ??= _relative(projectRoot, info.filePath);
      final String navigator =
          _annotationName(typedShellRoute) == 'TypedStatefulShellRoute'
              ? 'tabs'
              : 'shell';
      layouts.add(
        LayoutNode(
          file: _relative(projectRoot, info.filePath),
          dir: '',
          navigator: navigator,
        ),
      );
      final Expression? nested = _annotationNamedArg(typedShellRoute, 'routes');
      if (nested != null) {
        _walkTypedRoutes(
          expression: nested,
          parentPath: '',
          projectRoot: projectRoot,
          classesByName: classesByName,
          routes: routes,
          seenIds: seenIds,
          navigator: navigator,
          layoutDir: '',
        );
      }
      final Expression? branches =
          _annotationNamedArg(typedShellRoute, 'branches');
      if (branches != null) {
        _walkBranches(
          expression: branches,
          parentPath: '',
          projectRoot: projectRoot,
          classesByName: classesByName,
          routes: routes,
          seenIds: seenIds,
          navigator: navigator,
        );
      }
      continue;
    }
    if (typedGoRoute == null) {
      continue;
    }
    routerFile ??= _relative(projectRoot, info.filePath);
    final String typeName =
        _annotationTypeArgument(typedGoRoute) ?? info.className;
    _addTypedRoute(
      typeName: typeName,
      argumentList: typedGoRoute.arguments,
      parentPath: '',
      projectRoot: projectRoot,
      classesByName: classesByName,
      routes: routes,
      seenIds: seenIds,
      navigator: layouts.isEmpty ? 'stack' : layouts.last.navigator,
      layoutDir: layouts.isEmpty ? '' : layouts.last.dir,
    );
  }
  return GoRouterBuilderParseResult(
    routes: routes,
    layouts: layouts,
    routerFile: routerFile,
  );
}

void _walkBranches({
  required Expression expression,
  required String parentPath,
  required String projectRoot,
  required Map<String, _RouteClassInfo> classesByName,
  required List<RouteNode> routes,
  required Set<String> seenIds,
  required String? navigator,
}) {
  final ListLiteral? list = expression is ListLiteral ? expression : null;
  if (list == null) {
    return;
  }
  for (final CollectionElement element in list.elements) {
    if (element is! Expression) {
      continue;
    }
    final _TypedCall? call = _asTypedCall(element);
    if (call == null) {
      continue;
    }
    final Expression? nested = _namedArg(call.argumentList, 'routes');
    if (nested != null) {
      _walkTypedRoutes(
        expression: nested,
        parentPath: parentPath,
        projectRoot: projectRoot,
        classesByName: classesByName,
        routes: routes,
        seenIds: seenIds,
        navigator: navigator,
        layoutDir: '',
      );
    }
  }
}

void _walkTypedRoutes({
  required Expression expression,
  required String parentPath,
  required String projectRoot,
  required Map<String, _RouteClassInfo> classesByName,
  required List<RouteNode> routes,
  required Set<String> seenIds,
  required String? navigator,
  required String layoutDir,
}) {
  final ListLiteral? list = expression is ListLiteral ? expression : null;
  if (list == null) {
    return;
  }
  for (final CollectionElement element in list.elements) {
    if (element is! Expression) {
      continue;
    }
    final _TypedCall? call = _asTypedCall(element);
    if (call == null || call.name != 'TypedGoRoute') {
      continue;
    }
    final String? typeName = call.typeName;
    if (typeName == null) {
      continue;
    }
    _addTypedRoute(
      typeName: typeName,
      argumentList: call.argumentList,
      parentPath: parentPath,
      projectRoot: projectRoot,
      classesByName: classesByName,
      routes: routes,
      seenIds: seenIds,
      navigator: navigator,
      layoutDir: layoutDir,
    );
  }
}

void _addTypedRoute({
  required String typeName,
  required ArgumentList? argumentList,
  required String parentPath,
  required String projectRoot,
  required Map<String, _RouteClassInfo> classesByName,
  required List<RouteNode> routes,
  required Set<String> seenIds,
  required String? navigator,
  required String layoutDir,
}) {
  if (argumentList == null) {
    return;
  }
  final String? rawPath = _stringNamedArg(argumentList, 'path');
  if (rawPath == null) {
    return;
  }
  final String absolutePath = _joinPaths(parentPath, rawPath);
  final String? nameArg = _stringNamedArg(argumentList, 'name');
  final String id = nameArg ?? typeName;
  if (!seenIds.add(id)) {
    return;
  }
  final _RouteClassInfo? info = classesByName[typeName];
  final String file = info == null
      ? ''
      : _resolveWidgetFile(projectRoot, info) ??
          _relative(projectRoot, info.filePath);
  routes.add(
    RouteNode(
      id: id,
      urlPath: absolutePath.isEmpty ? '/' : absolutePath,
      file: file,
      slug: _slugFromPath(absolutePath.isEmpty ? '/' : absolutePath),
      params: _paramsFromPath(absolutePath),
      navigator: navigator,
      layoutDir: layoutDir,
      presentation: null,
    ),
  );
  final Expression? children = _namedArg(argumentList, 'routes');
  if (children != null) {
    _walkTypedRoutes(
      expression: children,
      parentPath: absolutePath,
      projectRoot: projectRoot,
      classesByName: classesByName,
      routes: routes,
      seenIds: seenIds,
      navigator: navigator,
      layoutDir: layoutDir,
    );
  }
}

String? _resolveWidgetFile(String projectRoot, _RouteClassInfo info) {
  MethodDeclaration? buildMethod;
  for (final ClassMember member in info.declaration.members) {
    if (member is MethodDeclaration && member.name.lexeme == 'build') {
      buildMethod = member;
      break;
    }
  }
  if (buildMethod == null) {
    return null;
  }
  final FunctionBody body = buildMethod.body;
  if (body is ExpressionFunctionBody) {
    final String? typeName = _widgetTypeName(body.expression);
    if (typeName != null) {
      return _findWidgetFile(projectRoot, typeName);
    }
    return null;
  }
  if (body is BlockFunctionBody) {
    for (final Statement statement in body.block.statements) {
      if (statement is ReturnStatement && statement.expression != null) {
        final String? typeName = _widgetTypeName(statement.expression!);
        if (typeName != null) {
          return _findWidgetFile(projectRoot, typeName);
        }
      }
    }
  }
  return null;
}

String? _widgetTypeName(Expression expression) {
  if (expression is InstanceCreationExpression) {
    return expression.constructorName.type.name2.lexeme;
  }
  if (expression is MethodInvocation) {
    return expression.methodName.name;
  }
  return null;
}

String? _findWidgetFile(String projectRoot, String typeName) {
  final RegExp classPattern = RegExp('class\\s+$typeName\\b');
  final Directory libDirectory = Directory(p.join(projectRoot, 'lib'));
  if (!libDirectory.existsSync()) {
    return null;
  }
  for (final FileSystemEntity entity
      in libDirectory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (classPattern.hasMatch(entity.readAsStringSync())) {
      return _relative(projectRoot, entity.path);
    }
  }
  return null;
}

class _DartUnit {
  const _DartUnit({required this.filePath, required this.unit});

  final String filePath;
  final CompilationUnit unit;
}

class _RouteClassInfo {
  const _RouteClassInfo({
    required this.className,
    required this.filePath,
    required this.declaration,
  });

  final String className;
  final String filePath;
  final ClassDeclaration declaration;
}

class _TypedCall {
  const _TypedCall({
    required this.name,
    required this.typeName,
    required this.argumentList,
  });

  final String name;
  final String? typeName;
  final ArgumentList argumentList;
}

List<_DartUnit> _loadDartUnits(String projectRoot) {
  final Directory libDirectory = Directory(p.join(projectRoot, 'lib'));
  if (!libDirectory.existsSync()) {
    return <_DartUnit>[];
  }
  final List<_DartUnit> units = <_DartUnit>[];
  for (final FileSystemEntity entity
      in libDirectory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.endsWith('.g.dart')) {
      continue;
    }
    final String source = entity.readAsStringSync();
    final ParseStringResult parseResult = parseString(
      content: source,
      path: entity.path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    units.add(_DartUnit(filePath: entity.path, unit: parseResult.unit));
  }
  return units;
}

Annotation? _findAnnotation(
  ClassDeclaration declaration,
  Set<String> names,
) {
  for (final Annotation annotation in declaration.metadata) {
    if (names.contains(_annotationName(annotation))) {
      return annotation;
    }
  }
  return null;
}

String _annotationName(Annotation annotation) {
  final Identifier name = annotation.name;
  if (name is PrefixedIdentifier) {
    return name.identifier.name;
  }
  return name.name;
}

String? _annotationTypeArgument(Annotation annotation) {
  final TypeArgumentList? typeArguments = annotation.typeArguments;
  if (typeArguments == null || typeArguments.arguments.isEmpty) {
    return null;
  }
  final TypeAnnotation first = typeArguments.arguments.first;
  if (first is NamedType) {
    return first.name2.lexeme;
  }
  return null;
}

Expression? _annotationNamedArg(Annotation annotation, String name) {
  final ArgumentList? arguments = annotation.arguments;
  if (arguments == null) {
    return null;
  }
  return _namedArg(arguments, name);
}

_TypedCall? _asTypedCall(Expression expression) {
  if (expression is InstanceCreationExpression) {
    return _TypedCall(
      name: expression.constructorName.type.name2.lexeme,
      typeName: _firstTypeArgumentName(expression.constructorName.type.typeArguments),
      argumentList: expression.argumentList,
    );
  }
  if (expression is MethodInvocation) {
    return _TypedCall(
      name: expression.methodName.name,
      typeName: _firstTypeArgumentName(expression.typeArguments),
      argumentList: expression.argumentList,
    );
  }
  return null;
}

String? _firstTypeArgumentName(TypeArgumentList? typeArguments) {
  if (typeArguments == null || typeArguments.arguments.isEmpty) {
    return null;
  }
  final TypeAnnotation first = typeArguments.arguments.first;
  if (first is NamedType) {
    return first.name2.lexeme;
  }
  return null;
}

Expression? _namedArg(ArgumentList argumentList, String name) {
  for (final Expression argument in argumentList.arguments) {
    if (argument is NamedExpression && argument.name.label.name == name) {
      return argument.expression;
    }
  }
  return null;
}

String? _stringNamedArg(ArgumentList argumentList, String name) {
  final Expression? expression = _namedArg(argumentList, name);
  if (expression is SimpleStringLiteral) {
    return expression.value;
  }
  if (expression is AdjacentStrings) {
    return expression.stringValue;
  }
  return null;
}

String _joinPaths(String parent, String child) {
  if (child.startsWith('/')) {
    return child == '/' ? '/' : child;
  }
  if (parent.isEmpty || parent == '/') {
    return '/$child';
  }
  final String normalizedParent =
      parent.endsWith('/') ? parent.substring(0, parent.length - 1) : parent;
  return '$normalizedParent/$child';
}

List<String> _paramsFromPath(String urlPath) {
  return urlPath
      .split('/')
      .where((String segment) => segment.startsWith(':'))
      .map((String segment) => segment.substring(1))
      .toList();
}

String _slugFromPath(String urlPath) {
  if (urlPath == '/' || urlPath.isEmpty) {
    return 'index';
  }
  return urlPath
      .replaceAll(RegExp(r'^/+'), '')
      .replaceAll(':', '')
      .replaceAll('/', '_');
}

String _relative(String projectRoot, String filePath) {
  return p.relative(filePath, from: projectRoot).replaceAll(r'\', '/');
}