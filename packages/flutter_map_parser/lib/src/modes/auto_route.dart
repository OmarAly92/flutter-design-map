import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_map_parser/src/model.dart';
import 'package:path/path.dart' as p;

/// Result of parsing `@AutoRouterConfig` route tables.
class AutoRouteParseResult {
  const AutoRouteParseResult({
    required this.routes,
    required this.layouts,
    required this.routerFile,
  });

  final List<RouteNode> routes;
  final List<LayoutNode> layouts;
  final String? routerFile;
}

/// Parses auto_route `@AutoRouterConfig` routers under [projectRoot]/lib.
AutoRouteParseResult parseAutoRouteProject(String projectRoot) {
  final List<_DartUnit> units = _loadDartUnits(projectRoot);
  final Map<String, String> routePageFiles = _collectRoutePageFiles(
    projectRoot: projectRoot,
    units: units,
  );
  final List<RouteNode> routes = <RouteNode>[];
  final List<LayoutNode> layouts = <LayoutNode>[];
  String? routerFile;
  final Set<String> seenIds = <String>{};
  for (final _DartUnit unit in units) {
    for (final ClassDeclaration declaration
        in unit.unit.declarations.whereType<ClassDeclaration>()) {
      final Annotation? config = _findAnnotation(
        declaration,
        <String>{'AutoRouterConfig'},
      );
      if (config == null) {
        continue;
      }
      routerFile ??= _relative(projectRoot, unit.filePath);
      final MethodDeclaration? routesGetter = _findRoutesGetter(declaration);
      if (routesGetter == null) {
        continue;
      }
      final Expression? bodyExpression = _getterExpression(routesGetter);
      if (bodyExpression == null) {
        continue;
      }
      _walkAutoRoutes(
        expression: bodyExpression,
        parentPath: '',
        projectRoot: projectRoot,
        routePageFiles: routePageFiles,
        routes: routes,
        layouts: layouts,
        seenIds: seenIds,
        routerFile: routerFile,
      );
    }
  }
  return AutoRouteParseResult(
    routes: routes,
    layouts: layouts,
    routerFile: routerFile,
  );
}

void _walkAutoRoutes({
  required Expression expression,
  required String parentPath,
  required String projectRoot,
  required Map<String, String> routePageFiles,
  required List<RouteNode> routes,
  required List<LayoutNode> layouts,
  required Set<String> seenIds,
  required String routerFile,
}) {
  final ListLiteral? list = expression is ListLiteral ? expression : null;
  if (list == null) {
    return;
  }
  for (final CollectionElement element in list.elements) {
    if (element is! Expression) {
      continue;
    }
    final _RouteCall? call = _asRouteCall(element);
    if (call == null) {
      continue;
    }
    if (call.name == 'RedirectRoute') {
      continue;
    }
    if (call.name != 'AutoRoute') {
      continue;
    }
    final String? pageType = _pageTypeName(call.argumentList);
    final String? rawPath = _stringNamedArg(call.argumentList, 'path');
    final bool initial = _boolNamedArg(call.argumentList, 'initial') ?? false;
    final String absolutePath = _resolveAbsolutePath(
      parentPath: parentPath,
      rawPath: rawPath,
      pageType: pageType,
      initial: initial,
    );
    final String id = pageType ?? _slugFromPath(absolutePath);
    final Expression? children = _namedArg(call.argumentList, 'children');
    final bool hasChildren = children is ListLiteral && children.elements.isNotEmpty;
    if (hasChildren) {
      layouts.add(
        LayoutNode(
          file: routerFile,
          dir: absolutePath == '/' ? '' : absolutePath,
          navigator: 'stack',
        ),
      );
    }
    if (seenIds.add(id)) {
      final String file = routePageFiles[id] ??
          _guessPageFile(projectRoot, id) ??
          routerFile;
      routes.add(
        RouteNode(
          id: id,
          urlPath: absolutePath.isEmpty ? '/' : absolutePath,
          file: file,
          slug: _slugFromPath(absolutePath.isEmpty ? '/' : absolutePath),
          params: _paramsFromPath(absolutePath),
          navigator: hasChildren
              ? 'stack'
              : (layouts.isEmpty ? 'stack' : layouts.last.navigator),
          layoutDir: layouts.isEmpty ? '' : layouts.last.dir,
          presentation: _presentation(call.argumentList),
        ),
      );
    }
    if (children != null) {
      _walkAutoRoutes(
        expression: children,
        parentPath: absolutePath,
        projectRoot: projectRoot,
        routePageFiles: routePageFiles,
        routes: routes,
        layouts: layouts,
        seenIds: seenIds,
        routerFile: routerFile,
      );
    }
  }
}

String _resolveAbsolutePath({
  required String parentPath,
  required String? rawPath,
  required String? pageType,
  required bool initial,
}) {
  if (rawPath != null) {
    if (rawPath.isEmpty) {
      return parentPath.isEmpty ? '/' : parentPath;
    }
    return _joinPaths(parentPath, rawPath);
  }
  if (initial && (parentPath.isEmpty || parentPath == '/')) {
    return '/';
  }
  if (pageType != null) {
    final String leaf = _routeNameToPathLeaf(pageType);
    return _joinPaths(parentPath, leaf);
  }
  return parentPath.isEmpty ? '/' : parentPath;
}

String _routeNameToPathLeaf(String routeTypeName) {
  String name = routeTypeName;
  if (name.endsWith('Route')) {
    name = name.substring(0, name.length - 'Route'.length);
  }
  if (name.isEmpty) {
    return '/';
  }
  final StringBuffer buffer = StringBuffer()
    ..write(name[0].toLowerCase())
    ..write(name.substring(1));
  return buffer.toString().replaceAllMapped(
        RegExp(r'[A-Z]'),
        (Match match) => '-${match.group(0)!.toLowerCase()}',
      );
}

String? _presentation(ArgumentList argumentList) {
  final bool? fullscreenDialog =
      _boolNamedArg(argumentList, 'fullscreenDialog');
  if (fullscreenDialog == true) {
    return 'modal';
  }
  return null;
}

String? _pageTypeName(ArgumentList argumentList) {
  final Expression? page = _namedArg(argumentList, 'page');
  if (page == null) {
    return null;
  }
  if (page is PrefixedIdentifier) {
    return page.prefix.name;
  }
  if (page is PropertyAccess) {
    final Expression target = page.target!;
    if (target is SimpleIdentifier) {
      return target.name;
    }
    if (target is PrefixedIdentifier) {
      return target.identifier.name;
    }
  }
  if (page is SimpleIdentifier) {
    return page.name;
  }
  return null;
}

MethodDeclaration? _findRoutesGetter(ClassDeclaration declaration) {
  for (final ClassMember member in declaration.members) {
    if (member is MethodDeclaration &&
        member.isGetter &&
        member.name.lexeme == 'routes') {
      return member;
    }
  }
  return null;
}

Expression? _getterExpression(MethodDeclaration getter) {
  final FunctionBody body = getter.body;
  if (body is ExpressionFunctionBody) {
    return body.expression;
  }
  if (body is BlockFunctionBody) {
    for (final Statement statement in body.block.statements) {
      if (statement is ReturnStatement) {
        return statement.expression;
      }
    }
  }
  return null;
}

Map<String, String> _collectRoutePageFiles({
  required String projectRoot,
  required List<_DartUnit> units,
}) {
  final Map<String, String> files = <String, String>{};
  for (final _DartUnit unit in units) {
    for (final ClassDeclaration declaration
        in unit.unit.declarations.whereType<ClassDeclaration>()) {
      final Annotation? routePage = _findAnnotation(
        declaration,
        <String>{'RoutePage'},
      );
      if (routePage == null) {
        continue;
      }
      final String className = declaration.name.lexeme;
      final String routeId = _pageClassToRouteId(className);
      files[routeId] = _relative(projectRoot, unit.filePath);
      files[className] = _relative(projectRoot, unit.filePath);
    }
  }
  return files;
}

String _pageClassToRouteId(String className) {
  if (className.endsWith('Page')) {
    return '${className.substring(0, className.length - 'Page'.length)}Route';
  }
  if (className.endsWith('Screen')) {
    return '${className.substring(0, className.length - 'Screen'.length)}Route';
  }
  if (className.endsWith('Route')) {
    return className;
  }
  return '${className}Route';
}

String? _guessPageFile(String projectRoot, String routeId) {
  String base = routeId;
  if (base.endsWith('Route')) {
    base = base.substring(0, base.length - 'Route'.length);
  }
  final List<String> candidates = <String>[
    '${base}Page',
    '${base}Screen',
    base,
  ];
  final Directory libDirectory = Directory(p.join(projectRoot, 'lib'));
  if (!libDirectory.existsSync()) {
    return null;
  }
  for (final String candidate in candidates) {
    final RegExp classPattern = RegExp('class\\s+$candidate\\b');
    for (final FileSystemEntity entity
        in libDirectory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.endsWith('.gr.dart')) {
        continue;
      }
      if (classPattern.hasMatch(entity.readAsStringSync())) {
        return _relative(projectRoot, entity.path);
      }
    }
  }
  return null;
}

class _DartUnit {
  const _DartUnit({required this.filePath, required this.unit});

  final String filePath;
  final CompilationUnit unit;
}

class _RouteCall {
  const _RouteCall({
    required this.name,
    required this.argumentList,
  });

  final String name;
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
    if (entity.path.endsWith('.gr.dart') || entity.path.endsWith('.g.dart')) {
      continue;
    }
    final ParseStringResult parseResult = parseString(
      content: entity.readAsStringSync(),
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
    final Identifier name = annotation.name;
    final String simple = name is PrefixedIdentifier
        ? name.identifier.name
        : name.name;
    if (names.contains(simple)) {
      return annotation;
    }
  }
  return null;
}

_RouteCall? _asRouteCall(Expression expression) {
  if (expression is InstanceCreationExpression) {
    return _RouteCall(
      name: expression.constructorName.type.name2.lexeme,
      argumentList: expression.argumentList,
    );
  }
  if (expression is MethodInvocation) {
    return _RouteCall(
      name: expression.methodName.name,
      argumentList: expression.argumentList,
    );
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

bool? _boolNamedArg(ArgumentList argumentList, String name) {
  final Expression? expression = _namedArg(argumentList, name);
  if (expression is BooleanLiteral) {
    return expression.value;
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
