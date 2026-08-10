import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_map_parser/src/const_strings.dart';
import 'package:flutter_map_parser/src/model.dart';
import 'package:path/path.dart' as p;

/// Result of parsing Navigator 1.0 named routes.
class NavigatorParseResult {
  const NavigatorParseResult({
    required this.routes,
    required this.layouts,
    required this.routerFile,
  });

  final List<RouteNode> routes;
  final List<LayoutNode> layouts;
  final String? routerFile;
}

/// Parses `MaterialApp` / `CupertinoApp` `routes` + `onGenerateRoute`.
NavigatorParseResult parseNavigatorProject(String projectRoot) {
  final List<_DartUnit> units = _loadDartUnits(projectRoot);
  final Map<String, String> widgetFiles =
      _collectWidgetFiles(units, projectRoot);
  final List<RouteNode> routes = <RouteNode>[];
  final Set<String> seenPaths = <String>{};
  String? routerFile;
  for (final _DartUnit unit in units) {
    final ConstStringTable constStrings = ConstStringTable.fromUnit(unit.unit);
    for (final ArgumentList args in _findAppArgumentLists(unit.unit)) {
      routerFile ??= _relative(projectRoot, unit.filePath);
      final String? initialRoute = _resolveStringArg(
        args,
        'initialRoute',
        constStrings,
      );
      final Expression? routesArg = _namedArg(args, 'routes');
      if (routesArg != null) {
        _collectRoutesMap(
          expression: routesArg,
          unit: unit,
          projectRoot: projectRoot,
          constStrings: constStrings,
          widgetFiles: widgetFiles,
          routes: routes,
          seenPaths: seenPaths,
          initialRoute: initialRoute,
        );
      }
      final Expression? onGenerate = _namedArg(args, 'onGenerateRoute');
      if (onGenerate != null) {
        _collectGeneratedRoutes(
          expression: onGenerate,
          unit: unit,
          projectRoot: projectRoot,
          constStrings: constStrings,
          widgetFiles: widgetFiles,
          routes: routes,
          seenPaths: seenPaths,
        );
      }
    }
  }
  if (routes.isEmpty) {
    return const NavigatorParseResult(
      routes: <RouteNode>[],
      layouts: <LayoutNode>[],
      routerFile: null,
    );
  }
  return NavigatorParseResult(
    routes: routes,
    layouts: <LayoutNode>[
      LayoutNode(
        file: routerFile ?? '',
        dir: '',
        navigator: 'stack',
      ),
    ],
    routerFile: routerFile,
  );
}

void _collectRoutesMap({
  required Expression expression,
  required _DartUnit unit,
  required String projectRoot,
  required ConstStringTable constStrings,
  required Map<String, String> widgetFiles,
  required List<RouteNode> routes,
  required Set<String> seenPaths,
  required String? initialRoute,
}) {
  final SetOrMapLiteral? map = _resolveMap(expression, unit.unit);
  if (map == null) {
    return;
  }
  for (final CollectionElement element in map.elements) {
    if (element is! MapLiteralEntry) {
      continue;
    }
    final String? path = constStrings.resolveExpression(element.key) ??
        _literalString(element.key);
    if (path == null || path.isEmpty) {
      continue;
    }
    final String? widgetName = _widgetFromBuilder(element.value);
    _addRoute(
      path: path,
      widgetName: widgetName,
      widgetFiles: widgetFiles,
      fallbackFile: _relative(projectRoot, unit.filePath),
      routes: routes,
      seenPaths: seenPaths,
    );
  }
}

void _collectGeneratedRoutes({
  required Expression expression,
  required _DartUnit unit,
  required String projectRoot,
  required ConstStringTable constStrings,
  required Map<String, String> widgetFiles,
  required List<RouteNode> routes,
  required Set<String> seenPaths,
}) {
  final FunctionExpression? function = _asFunction(expression, unit.unit);
  if (function == null) {
    return;
  }
  final FunctionBody body = function.body;
  if (body is BlockFunctionBody) {
    for (final Statement statement in body.block.statements) {
      _walkGenerateNode(
        node: statement,
        projectRoot: projectRoot,
        unit: unit,
        constStrings: constStrings,
        widgetFiles: widgetFiles,
        routes: routes,
        seenPaths: seenPaths,
      );
    }
  } else if (body is ExpressionFunctionBody) {
    _walkGenerateNode(
      node: body.expression,
      projectRoot: projectRoot,
      unit: unit,
      constStrings: constStrings,
      widgetFiles: widgetFiles,
      routes: routes,
      seenPaths: seenPaths,
    );
  }
}

void _walkGenerateNode({
  required AstNode node,
  required String projectRoot,
  required _DartUnit unit,
  required ConstStringTable constStrings,
  required Map<String, String> widgetFiles,
  required List<RouteNode> routes,
  required Set<String> seenPaths,
}) {
  if (node is IfStatement) {
    final String? path = _pathFromCondition(node.expression, constStrings);
    if (path != null) {
      final String? widgetName = _findWidgetInNode(node.thenStatement);
      _addRoute(
        path: path,
        widgetName: widgetName,
        widgetFiles: widgetFiles,
        fallbackFile: _relative(projectRoot, unit.filePath),
        routes: routes,
        seenPaths: seenPaths,
      );
    }
    if (node.elseStatement != null) {
      _walkGenerateNode(
        node: node.elseStatement!,
        projectRoot: projectRoot,
        unit: unit,
        constStrings: constStrings,
        widgetFiles: widgetFiles,
        routes: routes,
        seenPaths: seenPaths,
      );
    }
    return;
  }
  if (node is SwitchStatement) {
    for (final SwitchMember member in node.members) {
      if (member is! SwitchCase) {
        continue;
      }
      final String? path = constStrings.resolveExpression(member.expression) ??
          _literalString(member.expression);
      if (path == null) {
        continue;
      }
      final String? widgetName = _findWidgetInStatements(member.statements);
      _addRoute(
        path: path,
        widgetName: widgetName,
        widgetFiles: widgetFiles,
        fallbackFile: _relative(projectRoot, unit.filePath),
        routes: routes,
        seenPaths: seenPaths,
      );
    }
    return;
  }
  if (node is Block) {
    for (final Statement statement in node.statements) {
      _walkGenerateNode(
        node: statement,
        projectRoot: projectRoot,
        unit: unit,
        constStrings: constStrings,
        widgetFiles: widgetFiles,
        routes: routes,
        seenPaths: seenPaths,
      );
    }
  }
}

String? _pathFromCondition(
  Expression expression,
  ConstStringTable constStrings,
) {
  if (expression is BinaryExpression &&
      expression.operator.type.lexeme == '==') {
    final Expression left = expression.leftOperand;
    final Expression right = expression.rightOperand;
    if (_looksLikeSettingsName(left)) {
      return constStrings.resolveExpression(right) ?? _literalString(right);
    }
    if (_looksLikeSettingsName(right)) {
      return constStrings.resolveExpression(left) ?? _literalString(left);
    }
  }
  return null;
}

bool _looksLikeSettingsName(Expression expression) {
  if (expression is PrefixedIdentifier) {
    return expression.identifier.name == 'name';
  }
  if (expression is PropertyAccess) {
    return expression.propertyName.name == 'name';
  }
  return false;
}

String? _findWidgetInNode(AstNode node) {
  final String? direct = _findWidgetInNodeShallow(node);
  if (direct != null) {
    return direct;
  }
  return _findFirstScreenConstructor(node);
}

String? _findWidgetInNodeShallow(AstNode node) {
  if (node is Block) {
    return _findWidgetInStatements(node.statements);
  }
  if (node is ReturnStatement) {
    return _widgetFromRouteReturn(node.expression);
  }
  if (node is ExpressionStatement) {
    return _widgetFromRouteReturn(node.expression);
  }
  return null;
}

String? _findFirstScreenConstructor(AstNode node) {
  if (node is InstanceCreationExpression) {
    final String name = node.constructorName.type.name2.lexeme;
    if (_looksLikeWidgetName(name)) {
      return name;
    }
  }
  if (node is MethodInvocation && node.target == null) {
    final String name = node.methodName.name;
    if (_looksLikeWidgetName(name)) {
      return name;
    }
  }
  for (final AstNode child in node.childEntities.whereType<AstNode>()) {
    final String? nested = _findFirstScreenConstructor(child);
    if (nested != null) {
      return nested;
    }
  }
  return null;
}

bool _looksLikeWidgetName(String name) {
  return name.endsWith('Screen') ||
      name.endsWith('Page') ||
      name.endsWith('View');
}

String? _findWidgetInStatements(NodeList<Statement> statements) {
  for (final Statement statement in statements) {
    final String? widget = _findWidgetInNode(statement);
    if (widget != null) {
      return widget;
    }
  }
  return null;
}

String? _widgetFromRouteReturn(Expression? expression) {
  if (expression == null) {
    return null;
  }
  ArgumentList? args;
  if (expression is InstanceCreationExpression) {
    args = expression.argumentList;
  } else if (expression is MethodInvocation) {
    args = expression.argumentList;
  }
  if (args != null) {
    final Expression? builder = _namedArg(args, 'builder');
    if (builder != null) {
      return _widgetFromBuilder(builder);
    }
  }
  return _widgetFromBuilder(expression);
}

void _addRoute({
  required String path,
  required String? widgetName,
  required Map<String, String> widgetFiles,
  required String fallbackFile,
  required List<RouteNode> routes,
  required Set<String> seenPaths,
}) {
  final String urlPath = path.startsWith('/') ? path : '/$path';
  if (!seenPaths.add(urlPath)) {
    return;
  }
  final String file =
      (widgetName != null ? widgetFiles[widgetName] : null) ?? fallbackFile;
  routes.add(
    RouteNode(
      id: _slugFromPath(urlPath),
      urlPath: urlPath,
      file: file,
      slug: _slugFromPath(urlPath),
      params: _paramsFromPath(urlPath),
      navigator: 'stack',
      layoutDir: '',
      presentation: null,
      widgetName: widgetName,
    ),
  );
}

List<ArgumentList> _findAppArgumentLists(CompilationUnit unit) {
  final List<ArgumentList> apps = <ArgumentList>[];
  void walk(AstNode node) {
    if (node is InstanceCreationExpression) {
      final String name = node.constructorName.type.name2.lexeme;
      if ((name == 'MaterialApp' || name == 'CupertinoApp') &&
          node.constructorName.name == null) {
        apps.add(node.argumentList);
      }
    }
    if (node is MethodInvocation) {
      final String name = node.methodName.name;
      if (name == 'MaterialApp' || name == 'CupertinoApp') {
        apps.add(node.argumentList);
      }
    }
    node.childEntities.whereType<AstNode>().forEach(walk);
  }

  walk(unit);
  return apps;
}

SetOrMapLiteral? _resolveMap(Expression expression, CompilationUnit unit) {
  if (expression is SetOrMapLiteral && _isRouteMapLiteral(expression)) {
    return expression;
  }
  if (expression is SimpleIdentifier) {
    return _lookupTopLevelMap(unit, expression.name);
  }
  if (expression is PrefixedIdentifier) {
    return _lookupStaticMap(
      unit,
      expression.prefix.name,
      expression.identifier.name,
    );
  }
  if (expression is PropertyAccess && expression.target is SimpleIdentifier) {
    return _lookupStaticMap(
      unit,
      (expression.target! as SimpleIdentifier).name,
      expression.propertyName.name,
    );
  }
  return null;
}

bool _isRouteMapLiteral(SetOrMapLiteral literal) {
  if (literal.isMap) {
    return true;
  }
  return literal.elements.any((CollectionElement element) {
    return element is MapLiteralEntry;
  });
}

SetOrMapLiteral? _lookupTopLevelMap(CompilationUnit unit, String name) {
  for (final CompilationUnitMember member in unit.declarations) {
    if (member is TopLevelVariableDeclaration) {
      for (final VariableDeclaration variable in member.variables.variables) {
        if (variable.name.lexeme == name &&
            variable.initializer is SetOrMapLiteral &&
            _isRouteMapLiteral(variable.initializer! as SetOrMapLiteral)) {
          return variable.initializer! as SetOrMapLiteral;
        }
      }
    }
    if (member is FunctionDeclaration && member.name.lexeme == name) {
      final FunctionBody body = member.functionExpression.body;
      if (body is ExpressionFunctionBody &&
          body.expression is SetOrMapLiteral &&
          _isRouteMapLiteral(body.expression as SetOrMapLiteral)) {
        return body.expression as SetOrMapLiteral;
      }
    }
  }
  return null;
}

SetOrMapLiteral? _lookupStaticMap(
  CompilationUnit unit,
  String className,
  String fieldName,
) {
  for (final CompilationUnitMember member in unit.declarations) {
    if (member is! ClassDeclaration || member.name.lexeme != className) {
      continue;
    }
    for (final ClassMember classMember in member.members) {
      if (classMember is FieldDeclaration) {
        for (final VariableDeclaration variable
            in classMember.fields.variables) {
          if (variable.name.lexeme == fieldName &&
              variable.initializer is SetOrMapLiteral &&
              _isRouteMapLiteral(variable.initializer! as SetOrMapLiteral)) {
            return variable.initializer! as SetOrMapLiteral;
          }
        }
      }
      if (classMember is MethodDeclaration &&
          classMember.isGetter &&
          classMember.name.lexeme == fieldName) {
        final FunctionBody body = classMember.body;
        if (body is ExpressionFunctionBody &&
            body.expression is SetOrMapLiteral &&
            _isRouteMapLiteral(body.expression as SetOrMapLiteral)) {
          return body.expression as SetOrMapLiteral;
        }
      }
    }
  }
  return null;
}

FunctionExpression? _asFunction(Expression expression, CompilationUnit unit) {
  if (expression is FunctionExpression) {
    return expression;
  }
  if (expression is SimpleIdentifier) {
    for (final CompilationUnitMember member in unit.declarations) {
      if (member is FunctionDeclaration &&
          member.name.lexeme == expression.name) {
        return member.functionExpression;
      }
    }
  }
  return null;
}

String? _widgetFromBuilder(Expression expression) {
  Expression? body = expression;
  if (expression is FunctionExpression) {
    final FunctionBody functionBody = expression.body;
    if (functionBody is ExpressionFunctionBody) {
      body = functionBody.expression;
    } else if (functionBody is BlockFunctionBody) {
      for (final Statement statement in functionBody.block.statements) {
        if (statement is ReturnStatement) {
          body = statement.expression;
          break;
        }
      }
    }
  }
  if (body is InstanceCreationExpression) {
    return body.constructorName.type.name2.lexeme;
  }
  if (body is MethodInvocation && body.target == null) {
    return body.methodName.name;
  }
  return null;
}

String? _resolveStringArg(
  ArgumentList argumentList,
  String name,
  ConstStringTable constStrings,
) {
  final Expression? expression = _namedArg(argumentList, name);
  if (expression == null) {
    return null;
  }
  return constStrings.resolveExpression(expression) ??
      _literalString(expression);
}

String? _literalString(Expression expression) {
  if (expression is SimpleStringLiteral) {
    return expression.value;
  }
  if (expression is AdjacentStrings) {
    return expression.stringValue;
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

Map<String, String> _collectWidgetFiles(
  List<_DartUnit> units,
  String projectRoot,
) {
  final Map<String, String> files = <String, String>{};
  for (final _DartUnit unit in units) {
    for (final ClassDeclaration declaration
        in unit.unit.declarations.whereType<ClassDeclaration>()) {
      files[declaration.name.lexeme] =
          _relative(projectRoot, unit.filePath);
    }
  }
  return files;
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
    if (entity.path.endsWith('.g.dart') || entity.path.endsWith('.gr.dart')) {
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

class _DartUnit {
  const _DartUnit({required this.filePath, required this.unit});

  final String filePath;
  final CompilationUnit unit;
}

String _relative(String projectRoot, String filePath) {
  return p.relative(filePath, from: projectRoot).replaceAll(r'\', '/');
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
