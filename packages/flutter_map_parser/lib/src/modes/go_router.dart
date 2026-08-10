import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_map_parser/src/const_strings.dart';
import 'package:flutter_map_parser/src/model.dart';
import 'package:path/path.dart' as p;

/// Parses imperative `GoRouter(...)` trees into route nodes and layouts.
class GoRouterParseResult {
  const GoRouterParseResult({
    required this.routes,
    required this.layouts,
    required this.routerFile,
  });

  final List<RouteNode> routes;
  final List<LayoutNode> layouts;
  final String? routerFile;
}

GoRouterParseResult parseGoRouterProject(String projectRoot) {
  final List<String> dartFiles = Directory(p.join(projectRoot, 'lib'))
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .map((File file) => file.path)
      .toList();
  for (final String filePath in dartFiles) {
    final String source = File(filePath).readAsStringSync();
    if (!source.contains('GoRouter(')) {
      continue;
    }
    final ParseStringResult parseResult = parseString(
      content: source,
      path: filePath,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    final _GoRouterCollector collector = _GoRouterCollector(
      projectRoot: projectRoot,
      filePath: filePath,
      source: source,
      unit: parseResult.unit,
      constStrings: ConstStringTable.fromUnit(parseResult.unit),
    );
    parseResult.unit.visitChildren(collector);
    if (collector.routes.isNotEmpty) {
      return GoRouterParseResult(
        routes: collector.routes,
        layouts: collector.layouts,
        routerFile: p.relative(filePath, from: projectRoot).split(r'\').join('/'),
      );
    }
  }
  return const GoRouterParseResult(
    routes: <RouteNode>[],
    layouts: <LayoutNode>[],
    routerFile: null,
  );
}

class _GoRouterCollector extends RecursiveAstVisitor<void> {
  _GoRouterCollector({
    required this.projectRoot,
    required this.filePath,
    required this.source,
    required this.unit,
    required this.constStrings,
  });

  final String projectRoot;
  final String filePath;
  final String source;
  final CompilationUnit unit;
  final ConstStringTable constStrings;
  final List<RouteNode> routes = <RouteNode>[];
  final List<LayoutNode> layouts = <LayoutNode>[];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String name = node.constructorName.type.name2.lexeme;
    _maybeCollectGoRouter(name, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String name = node.methodName.name;
    if (name == 'GoRouter' || name == 'GoRoute' || name == 'ShellRoute' ||
        name == 'StatefulShellRoute') {
      _maybeCollectGoRouter(name, node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  void _maybeCollectGoRouter(String name, ArgumentList argumentList) {
    if (name != 'GoRouter') {
      return;
    }
    if (routes.isNotEmpty) {
      return;
    }
    final Expression? routesArg = _namedArg(argumentList, 'routes');
    if (routesArg == null) {
      return;
    }
    _walkRoutes(routesArg, parentPath: '');
  }

  void _walkRoutes(Expression expression, {required String parentPath}) {
    final Expression resolved =
        _resolveRoutesExpression(expression) ?? expression;
    final ListLiteral? list = _asList(resolved);
    if (list == null) {
      return;
    }
    for (final CollectionElement element in list.elements) {
      if (element is SpreadElement) {
        _walkRoutes(element.expression, parentPath: parentPath);
        continue;
      }
      if (element is! Expression) {
        continue;
      }
      final _RouteCall? call = _asRouteCall(element);
      if (call == null) {
        continue;
      }
      if (call.name == 'ShellRoute' || call.name == 'StatefulShellRoute') {
        final String navigator =
            call.name == 'StatefulShellRoute' ? 'tabs' : 'shell';
        final String layoutFile = p
            .relative(filePath, from: projectRoot)
            .split(r'\')
            .join('/');
        layouts.add(
          LayoutNode(
            file: layoutFile,
            dir: parentPath.isEmpty ? '' : parentPath,
            navigator: navigator,
          ),
        );
        final Expression? nested = _namedArg(call.argumentList, 'routes');
        if (nested != null) {
          _walkRoutes(nested, parentPath: parentPath);
        }
        final Expression? branches = _namedArg(call.argumentList, 'branches');
        if (branches != null) {
          _walkBranches(branches, parentPath: parentPath);
        }
        continue;
      }
      if (call.name != 'GoRoute') {
        continue;
      }
      final String? rawPath = _resolveStringArg(call.argumentList, 'path');
      if (rawPath == null) {
        continue;
      }
      final String absolutePath = _joinPaths(parentPath, rawPath);
      final String? nameArg = _resolveStringArg(call.argumentList, 'name');
      final String id = nameArg ?? _slugFromPath(absolutePath);
      final List<String> params = _paramsFromPath(absolutePath);
      final String? widgetFile = _resolveBuilderFile(call.argumentList);
      final String relativeFile = widgetFile == null
          ? p.relative(filePath, from: projectRoot).split(r'\').join('/')
          : p.relative(widgetFile, from: projectRoot).split(r'\').join('/');
      final String? navigator =
          layouts.isEmpty ? 'stack' : layouts.last.navigator;
      routes.add(
        RouteNode(
          id: id,
          urlPath: absolutePath.isEmpty ? '/' : absolutePath,
          file: relativeFile,
          slug: _slugFromPath(absolutePath.isEmpty ? '/' : absolutePath),
          params: params,
          navigator: navigator,
          layoutDir: layouts.isEmpty ? '' : layouts.last.dir,
          presentation: null,
        ),
      );
      final Expression? children = _namedArg(call.argumentList, 'routes');
      if (children != null) {
        _walkRoutes(children, parentPath: absolutePath);
      }
    }
  }

  Expression? _resolveRoutesExpression(Expression expression) {
    if (expression is ListLiteral) {
      return expression;
    }
    if (expression is SimpleIdentifier) {
      return _lookupTopLevelList(expression.name);
    }
    if (expression is PrefixedIdentifier) {
      return _lookupTopLevelList(expression.identifier.name);
    }
    return null;
  }

  Expression? _lookupTopLevelList(String name) {
    for (final CompilationUnitMember member in unit.declarations) {
      if (member is FunctionDeclaration && member.name.lexeme == name) {
        final FunctionBody body = member.functionExpression.body;
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
      }
      if (member is TopLevelVariableDeclaration) {
        for (final VariableDeclaration variable in member.variables.variables) {
          if (variable.name.lexeme == name) {
            return variable.initializer;
          }
        }
      }
    }
    return null;
  }

  void _walkBranches(Expression expression, {required String parentPath}) {
    final ListLiteral? list = _asList(expression);
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
      final Expression? routesArg = _namedArg(call.argumentList, 'routes');
      if (routesArg != null) {
        _walkRoutes(routesArg, parentPath: parentPath);
      }
    }
  }

  String? _resolveBuilderFile(ArgumentList argumentList) {
    final Expression? builder = _namedArg(argumentList, 'builder') ??
        _namedArg(argumentList, 'pageBuilder');
    if (builder == null) {
      return null;
    }
    final String? typeName = _extractWidgetTypeName(builder);
    if (typeName == null) {
      return null;
    }
    return _findWidgetFile(typeName);
  }

  String? _resolveStringArg(ArgumentList argumentList, String name) {
    final Expression? expression = _namedArg(argumentList, name);
    if (expression == null) {
      return null;
    }
    return constStrings.resolveExpression(expression) ??
        (expression is SimpleStringLiteral ? expression.value : null) ??
        (expression is AdjacentStrings ? expression.stringValue : null);
  }

  String? _extractWidgetTypeName(Expression builder) {
    if (builder is FunctionExpression) {
      final FunctionBody body = builder.body;
      Expression? returned;
      if (body is ExpressionFunctionBody) {
        returned = body.expression;
      } else if (body is BlockFunctionBody) {
        for (final Statement statement in body.block.statements) {
          if (statement is ReturnStatement) {
            returned = statement.expression;
            break;
          }
        }
      }
      return _widgetTypeFromExpression(returned);
    }
    return null;
  }

  String? _widgetTypeFromExpression(Expression? expression) {
    if (expression == null) {
      return null;
    }
    if (expression is InstanceCreationExpression) {
      return expression.constructorName.type.name2.lexeme;
    }
    if (expression is MethodInvocation) {
      // Helpers like `_fadePage(context, state, HomeScreen())` or
      // `_buildPage(state, const Foo())` — take the last widget-looking arg.
      for (final Expression argument in expression.argumentList.arguments.reversed) {
        final Expression unwrapped =
            argument is NamedExpression ? argument.expression : argument;
        final String? nested = _widgetTypeFromExpression(unwrapped);
        if (nested != null &&
            nested != 'CustomTransitionPage' &&
            nested != 'MaterialPage' &&
            nested != 'CupertinoPage') {
          return nested;
        }
      }
      return expression.methodName.name;
    }
    return null;
  }

  String? _findWidgetFile(String typeName) {
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
      final String content = entity.readAsStringSync();
      if (classPattern.hasMatch(content)) {
        return entity.path;
      }
    }
    return null;
  }
}

class _RouteCall {
  const _RouteCall({
    required this.name,
    required this.argumentList,
  });

  final String name;
  final ArgumentList argumentList;
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

ListLiteral? _asList(Expression expression) {
  if (expression is ListLiteral) {
    return expression;
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
