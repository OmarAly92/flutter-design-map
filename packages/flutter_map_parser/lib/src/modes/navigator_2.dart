import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_map_parser/src/model.dart';
import 'package:path/path.dart' as p;

/// Result of parsing Navigator 2.0 / RouterDelegate page stacks.
class Navigator2ParseResult {
  const Navigator2ParseResult({
    required this.routes,
    required this.layouts,
    required this.routerFile,
    this.stackEdges = const <Edge>[],
  });

  final List<RouteNode> routes;
  final List<LayoutNode> layouts;
  final String? routerFile;
  final List<Edge> stackEdges;
}

/// Parses `RouterDelegate` `pages:` stacks and optional path hints from
/// `RouteInformationParser` / `ValueKey`s.
Navigator2ParseResult parseNavigator2Project(String projectRoot) {
  final List<_DartUnit> units = _loadDartUnits(projectRoot);
  final Map<String, String> widgetFiles =
      _collectWidgetFiles(units, projectRoot);
  final Map<String, String> parserPaths = <String, String>{};
  for (final _DartUnit unit in units) {
    parserPaths.addAll(_extractParserPaths(unit.unit));
  }
  final List<_PageHit> pages = <_PageHit>[];
  String? routerFile;
  for (final _DartUnit unit in units) {
    for (final ClassDeclaration declaration
        in unit.unit.declarations.whereType<ClassDeclaration>()) {
      if (!_extendsRouterDelegate(declaration)) {
        continue;
      }
      routerFile ??= _relative(projectRoot, unit.filePath);
      for (final ListLiteral list in _findPagesLists(declaration)) {
        _collectPagesFromList(
          list: list,
          pages: pages,
          unitFile: _relative(projectRoot, unit.filePath),
        );
      }
    }
    // Also accept Navigator(pages: [...]) outside a typed RouterDelegate.
    for (final ListLiteral list in _findLoosePagesLists(unit.unit)) {
      routerFile ??= _relative(projectRoot, unit.filePath);
      _collectPagesFromList(
        list: list,
        pages: pages,
        unitFile: _relative(projectRoot, unit.filePath),
      );
    }
  }
  final List<RouteNode> routes = <RouteNode>[];
  final Set<String> seenPaths = <String>{};
  final List<String> orderedIds = <String>[];
  final Map<String, String> widgetToId = <String, String>{};
  for (final _PageHit page in pages) {
    final String urlPath = _resolvePagePath(
      page: page,
      parserPaths: parserPaths,
    );
    if (!seenPaths.add(urlPath)) {
      if (page.widgetName != null) {
        widgetToId.putIfAbsent(page.widgetName!, () => _slugFromPath(urlPath));
      }
      continue;
    }
    final String id = _slugFromPath(urlPath);
    orderedIds.add(id);
    if (page.widgetName != null) {
      widgetToId[page.widgetName!] = id;
    }
    final String file = (page.widgetName != null
            ? widgetFiles[page.widgetName!]
            : null) ??
        page.fallbackFile;
    routes.add(
      RouteNode(
        id: id,
        urlPath: urlPath,
        file: file,
        slug: id,
        params: _paramsFromPath(urlPath),
        navigator: 'stack',
        layoutDir: '',
        presentation: null,
        widgetName: page.widgetName,
      ),
    );
  }
  final List<Edge> stackEdges = <Edge>[];
  if (orderedIds.isNotEmpty) {
    final String rootId = orderedIds.first;
    for (int i = 1; i < orderedIds.length; i++) {
      stackEdges.add(
        Edge(
          from: rootId,
          to: orderedIds[i],
          raw: 'pages stack',
          target: routes
              .firstWhere((RouteNode route) => route.id == orderedIds[i])
              .urlPath,
        ),
      );
    }
  }
  if (routes.isEmpty) {
    return const Navigator2ParseResult(
      routes: <RouteNode>[],
      layouts: <LayoutNode>[],
      routerFile: null,
    );
  }
  return Navigator2ParseResult(
    routes: routes,
    layouts: <LayoutNode>[
      LayoutNode(
        file: routerFile ?? '',
        dir: '',
        navigator: 'stack',
      ),
    ],
    routerFile: routerFile,
    stackEdges: stackEdges,
  );
}

class _PageHit {
  const _PageHit({
    required this.widgetName,
    required this.keyHint,
    required this.fallbackFile,
    required this.isConditional,
  });

  final String? widgetName;
  final String? keyHint;
  final String fallbackFile;
  final bool isConditional;
}

bool _extendsRouterDelegate(ClassDeclaration declaration) {
  final ExtendsClause? extendsClause = declaration.extendsClause;
  if (extendsClause == null) {
    return false;
  }
  final NamedType superclass = extendsClause.superclass;
  final String name = superclass.name2.lexeme;
  return name == 'RouterDelegate';
}

List<ListLiteral> _findPagesLists(ClassDeclaration declaration) {
  final List<ListLiteral> lists = <ListLiteral>[];
  void walk(AstNode node) {
    if (node is NamedExpression &&
        node.name.label.name == 'pages' &&
        node.expression is ListLiteral) {
      lists.add(node.expression as ListLiteral);
    }
    node.childEntities.whereType<AstNode>().forEach(walk);
  }

  walk(declaration);
  return lists;
}

List<ListLiteral> _findLoosePagesLists(CompilationUnit unit) {
  final List<ListLiteral> lists = <ListLiteral>[];
  void walk(AstNode node) {
    if (node is InstanceCreationExpression || node is MethodInvocation) {
      final String name = node is InstanceCreationExpression
          ? node.constructorName.type.name2.lexeme
          : (node as MethodInvocation).methodName.name;
      if (name == 'Navigator') {
        final ArgumentList args = node is InstanceCreationExpression
            ? node.argumentList
            : (node as MethodInvocation).argumentList;
        for (final Expression argument in args.arguments) {
          if (argument is NamedExpression &&
              argument.name.label.name == 'pages' &&
              argument.expression is ListLiteral) {
            lists.add(argument.expression as ListLiteral);
          }
        }
      }
    }
    node.childEntities.whereType<AstNode>().forEach(walk);
  }

  walk(unit);
  return lists;
}

void _collectPagesFromList({
  required ListLiteral list,
  required List<_PageHit> pages,
  required String unitFile,
}) {
  for (final CollectionElement element in list.elements) {
    final bool conditional = element is IfElement;
    final Expression? expression = _expressionFromCollectionElement(element);
    if (expression == null) {
      continue;
    }
    for (final _PageHit hit in _pagesFromExpression(
      expression,
      fallbackFile: unitFile,
      isConditional: conditional,
    )) {
      pages.add(hit);
    }
  }
}

Expression? _expressionFromCollectionElement(CollectionElement element) {
  if (element is Expression) {
    return element;
  }
  if (element is IfElement) {
    return element.thenElement is Expression
        ? element.thenElement as Expression
        : null;
  }
  return null;
}

List<_PageHit> _pagesFromExpression(
  Expression expression, {
  required String fallbackFile,
  required bool isConditional,
}) {
  final _RouteCall? call = _asCall(expression);
  if (call == null) {
    return const <_PageHit>[];
  }
  if (_isPageType(call.name)) {
    return <_PageHit>[
      _PageHit(
        widgetName: _childWidgetName(call.argumentList),
        keyHint: _keyHint(call.argumentList),
        fallbackFile: fallbackFile,
        isConditional: isConditional,
      ),
    ];
  }
  // Custom page widgets that wrap a screen, e.g. BookDetailsPage(...).
  if (call.name.endsWith('Page')) {
    final String? child = _childWidgetName(call.argumentList);
    return <_PageHit>[
      _PageHit(
        widgetName: child ?? call.name.replaceFirst(RegExp(r'Page$'), 'Screen'),
        keyHint: _keyHint(call.argumentList) ??
            _pathFromPageClassName(call.name),
        fallbackFile: fallbackFile,
        isConditional: isConditional,
      ),
    ];
  }
  return const <_PageHit>[];
}

bool _isPageType(String name) {
  return name == 'MaterialPage' ||
      name == 'CupertinoPage' ||
      name == 'CustomTransitionPage' ||
      name == 'NoTransitionPage';
}

String? _childWidgetName(ArgumentList argumentList) {
  final Expression? child = _namedArg(argumentList, 'child');
  if (child == null) {
    return null;
  }
  return _widgetTypeName(child);
}

String? _widgetTypeName(Expression expression) {
  if (expression is InstanceCreationExpression) {
    return expression.constructorName.type.name2.lexeme;
  }
  if (expression is MethodInvocation && expression.target == null) {
    return expression.methodName.name;
  }
  return null;
}

String? _keyHint(ArgumentList argumentList) {
  final Expression? key = _namedArg(argumentList, 'key');
  if (key == null) {
    return null;
  }
  final _RouteCall? call = _asCall(key);
  if (call == null) {
    return null;
  }
  if (call.name != 'ValueKey' && call.name != 'ObjectKey') {
    return null;
  }
  if (call.argumentList.arguments.isEmpty) {
    return null;
  }
  Expression first = call.argumentList.arguments.first;
  if (first is NamedExpression) {
    first = first.expression;
  }
  if (first is SimpleStringLiteral) {
    return first.value;
  }
  if (first is AdjacentStrings) {
    return first.stringValue;
  }
  // ValueKey('details-$_selectedId') string interpolation.
  if (first is StringInterpolation) {
    final StringBuffer buffer = StringBuffer();
    for (final InterpolationElement element in first.elements) {
      if (element is InterpolationString) {
        buffer.write(element.value);
      } else {
        buffer.write(':id');
      }
    }
    return buffer.toString();
  }
  return null;
}

String _resolvePagePath({
  required _PageHit page,
  required Map<String, String> parserPaths,
}) {
  if (page.keyHint != null) {
    final String hint = page.keyHint!;
    if (hint.startsWith('/')) {
      return hint;
    }
    if (parserPaths.containsKey(hint)) {
      return parserPaths[hint]!;
    }
    // 'details-$id' / 'details-$_selectedId' → /details/:id
    if (hint.startsWith('details')) {
      return '/details/:id';
    }
    return '/${_slugifyKey(hint)}';
  }
  if (page.widgetName != null && parserPaths.containsKey(page.widgetName)) {
    return parserPaths[page.widgetName!]!;
  }
  if (page.widgetName != null) {
    return _pathFromWidgetName(page.widgetName!);
  }
  return '/page';
}

String _pathFromWidgetName(String widgetName) {
  String name = widgetName;
  if (name.endsWith('Screen')) {
    name = name.substring(0, name.length - 'Screen'.length);
  } else if (name.endsWith('Page')) {
    name = name.substring(0, name.length - 'Page'.length);
  } else if (name.endsWith('View')) {
    name = name.substring(0, name.length - 'View'.length);
  }
  if (name.isEmpty || name.toLowerCase() == 'home') {
    return '/';
  }
  return '/${_slugifyKey(name)}';
}

String _pathFromPageClassName(String pageClassName) {
  String name = pageClassName;
  if (name.endsWith('Page')) {
    name = name.substring(0, name.length - 'Page'.length);
  }
  return _slugifyKey(name);
}

String _slugifyKey(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return 'page';
  }
  // Strip interpolation leftovers: details-$_selectedId
  final String withoutInterp =
      trimmed.replaceAll(RegExp(r'\$\{?[^}]+\}?'), ':id');
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < withoutInterp.length; i++) {
    final String ch = withoutInterp[i];
    final bool isUpper = ch.toUpperCase() == ch &&
        ch.toLowerCase() != ch &&
        RegExp(r'[A-Za-z]').hasMatch(ch);
    if (i > 0 && isUpper) {
      buffer.write('-');
    }
    if (ch == '_' || ch == ' ') {
      buffer.write('-');
      continue;
    }
    buffer.write(ch.toLowerCase());
  }
  return buffer.toString().replaceAll(RegExp(r'-+'), '-');
}

Map<String, String> _extractParserPaths(CompilationUnit unit) {
  final Map<String, String> paths = <String, String>{};
  for (final ClassDeclaration declaration
      in unit.declarations.whereType<ClassDeclaration>()) {
    if (!_extendsRouteInformationParser(declaration)) {
      continue;
    }
    final String source = declaration.toSource();
    for (final RegExpMatch match in RegExp(
      r"""['"]/(about|settings|details|home|[^'"]+)['"]""",
    ).allMatches(source)) {
      final String path = '/${match.group(1)}';
      final String leaf = match.group(1)!;
      paths[leaf] = path.startsWith('//') ? path.substring(1) : path;
      paths[_capitalize(leaf)] = paths[leaf]!;
      paths['${_capitalize(leaf)}Screen'] = paths[leaf]!;
    }
    // '/details/${...}' style
    if (source.contains('/details/')) {
      paths['details'] = '/details/:id';
      paths['DetailsScreen'] = '/details/:id';
    }
    if (source.contains("location: '/'") ||
        source.contains('location: "/"') ||
        source.contains("location: '/'")) {
      paths['home'] = '/';
      paths['HomeScreen'] = '/';
    }
  }
  return paths;
}

bool _extendsRouteInformationParser(ClassDeclaration declaration) {
  final ExtendsClause? extendsClause = declaration.extendsClause;
  if (extendsClause == null) {
    return false;
  }
  return extendsClause.superclass.name2.lexeme == 'RouteInformationParser';
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

class _RouteCall {
  const _RouteCall({
    required this.name,
    required this.argumentList,
  });

  final String name;
  final ArgumentList argumentList;
}

_RouteCall? _asCall(Expression expression) {
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
