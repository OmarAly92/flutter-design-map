import 'dart:io';

import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flutter_map_live_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('resolves path constants and extracted route lists', () {
    final String lib = p.join(tempDir.path, 'lib');
    Directory(lib).createSync(recursive: true);
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: const_routes_app
environment:
  sdk: ^3.5.0
dependencies:
  go_router: ^14.0.0
''');
    File(p.join(lib, 'router.dart')).writeAsStringSync(r'''
import 'package:go_router/go_router.dart';

abstract class Routes {
  static const home = '/';
  static const settingsRoot = '/settings';
  static const theme = 'theme';
}

List<RouteBase> get _settingsRoutes => [
  GoRoute(
    path: Routes.settingsRoot,
    builder: (context, state) => const SettingsScreen(),
    routes: [
      GoRoute(
        path: Routes.theme,
        builder: (context, state) => const ThemeScreen(),
      ),
    ],
  ),
];

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => child,
      routes: _settingsRoutes,
    ),
  ],
);

class HomeScreen {
  const HomeScreen();
}

class SettingsScreen {
  const SettingsScreen();
}

class ThemeScreen {
  const ThemeScreen();
}
''');
    final RouteGraph graph = parseProject(tempDir.path);
    expect(graph.mode, 'go_router');
    expect(
      graph.routes.map((RouteNode route) => route.urlPath).toSet(),
      equals(<String>{'/', '/settings', '/settings/theme'}),
    );
  });

  test('ignores http(s) when detecting deep-link scheme', () {
    final String lib = p.join(tempDir.path, 'lib');
    Directory(lib).createSync(recursive: true);
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: noscheme_app
environment:
  sdk: ^3.5.0
dependencies:
  go_router: ^14.0.0
''');
    File(p.join(lib, 'main.dart')).writeAsStringSync('''
import 'package:go_router/go_router.dart';

final docs = 'https://example.com/docs';
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
  ],
);

class HomeScreen {
  const HomeScreen();
}
''');
    final RouteGraph graph = parseProject(tempDir.path);
    expect(graph.scheme, isNull);
  });
}
