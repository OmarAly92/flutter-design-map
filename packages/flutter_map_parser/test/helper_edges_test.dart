import 'dart:io';

import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flutter_map_edges_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('resolves AppPaths const and helper navigation edges', () {
    final String lib = p.join(tempDir.path, 'lib');
    Directory(p.join(lib, 'screens')).createSync(recursive: true);
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: paths_app
environment:
  sdk: ^3.5.0
dependencies:
  go_router: ^14.0.0
''');
    File(p.join(lib, 'router.dart')).writeAsStringSync(r'''
import 'package:go_router/go_router.dart';

abstract class _RouteString {
  static const home = '/';
  static const detailsBase = 'details';
  static const detailsRoute = '$detailsBase/:id';
}

abstract class AppPaths {
  static const home = _RouteString.home;
  static String details(String id) => '/${_RouteString.detailsBase}/$id';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: _RouteString.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: _RouteString.detailsRoute,
      builder: (context, state) => DetailsScreen(id: state.pathParameters['id']!),
    ),
  ],
);
''');
    File(p.join(lib, 'screens', 'home_screen.dart')).writeAsStringSync('''
import '../router.dart';

class HomeScreen {
  const HomeScreen();

  void openDetails(dynamic context) {
    context.go(AppPaths.details('42'));
  }

  void openHome(dynamic context) {
    context.go(AppPaths.home);
  }
}

class DetailsScreen {
  const DetailsScreen({required this.id});
  final String id;
}
''');
    // Point builders at screen file via class discovery.
    File(p.join(lib, 'router.dart')).writeAsStringSync(r'''
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';

abstract class _RouteString {
  static const home = '/';
  static const detailsBase = 'details';
  static const detailsRoute = '$detailsBase/:id';
}

abstract class AppPaths {
  static const home = _RouteString.home;
  static String details(String id) => '/${_RouteString.detailsBase}/$id';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: _RouteString.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: _RouteString.detailsRoute,
      builder: (context, state) => DetailsScreen(id: state.pathParameters['id']!),
    ),
  ],
);
''');
    final RouteGraph graph = parseProject(tempDir.path);
    expect(graph.routes, hasLength(2));
    expect(graph.edges.length, greaterThanOrEqualTo(2));
    expect(
      graph.edges.any(
        (Edge edge) =>
            edge.from == 'index' &&
            edge.to == 'details_id' &&
            edge.target.contains('details'),
      ),
      isTrue,
    );
    expect(
      graph.edges.any(
        (Edge edge) => edge.from == 'index' && edge.target == '/',
      ),
      isTrue,
    );
  });
}
