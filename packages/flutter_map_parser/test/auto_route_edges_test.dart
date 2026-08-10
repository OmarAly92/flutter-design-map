import 'dart:io';

import 'package:flutter_map_parser/flutter_map_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flutter_map_auto_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('resolves RoutePage wrappers and AutoRoute nav variants', () {
    final String lib = p.join(tempDir.path, 'lib');
    Directory(p.join(lib, 'features', 'today', 'presentation', 'screens'))
        .createSync(recursive: true);
    Directory(p.join(lib, 'features', 'today', 'presentation', 'widgets'))
        .createSync(recursive: true);
    Directory(p.join(lib, 'core', 'routes')).createSync(recursive: true);
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: maple_like
environment:
  sdk: ^3.5.0
dependencies:
  auto_route: ^9.0.0
''');
    File(p.join(lib, 'features', 'today', 'presentation', 'screens', 'today_screen.dart'))
        .writeAsStringSync(r'''
class TodayScreen {
  const TodayScreen();

  void openInvoice(dynamic context) {
    context.router.push(InvoicePreviewRoute(invoiceId: '1'));
  }

  void openCreate(dynamic context) {
    Navigator.of(context).push(
      CupertinoSheetRoute(
        builder: (_) => const CreateInvoiceScreen(),
      ),
    );
  }

  void finishOnboarding(dynamic context) {
    AutoRouter.of(context).replaceAll([const HomeRoute()]);
  }
}

class InvoicePreviewRoute {
  InvoicePreviewRoute({required this.invoiceId});
  final String invoiceId;
}

class CreateInvoiceScreen {
  const CreateInvoiceScreen();
}

class HomeRoute {
  const HomeRoute();
}

class AutoRouter {
  static _R of(dynamic context) => const _R();
}

class _R {
  const _R();
  void replaceAll(List<dynamic> routes) {}
}

class Navigator {
  static _Nav of(dynamic context) => const _Nav();
}

class _Nav {
  const _Nav();
  void push(dynamic route) {}
}

class CupertinoSheetRoute {
  CupertinoSheetRoute({required this.builder});
  final Object builder;
}
''');
    File(p.join(lib, 'features', 'today', 'presentation', 'widgets', 'tile.dart'))
        .writeAsStringSync(r'''
class TodayTile {
  void open(dynamic context) {
    context.pushRoute(const CreateInvoiceRoute());
  }
}

class CreateInvoiceRoute {
  const CreateInvoiceRoute();
}
''');
    File(p.join(lib, 'core', 'routes', 'app_router.dart')).writeAsStringSync(r'''
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(path: '/', page: TodayRoute.page, initial: true),
        AutoRoute(path: '/invoice/:id', page: InvoicePreviewRoute.page),
        AutoRoute(path: '/create-invoice', page: CreateInvoiceRoute.page),
        AutoRoute(path: '/home', page: HomeRoute.page),
      ];
}

@RoutePage()
class TodayPage {
  const TodayPage();
  Widget build() => const TodayScreen();
}

@RoutePage()
class InvoicePreviewPage {
  const InvoicePreviewPage();
  Widget build() => const InvoicePreviewBody();
}

@RoutePage()
class CreateInvoicePage {
  const CreateInvoicePage();
  Widget build() => const CreateInvoiceBody();
}

@RoutePage()
class HomePage {
  const HomePage();
}

class TodayScreen {
  const TodayScreen();
}

class InvoicePreviewBody {
  const InvoicePreviewBody();
}

class CreateInvoiceBody {
  const CreateInvoiceBody();
}

class Widget {
  const Widget();
}

class RootStackRouter {}
class AutoRouterConfig {
  const AutoRouterConfig();
}
class RoutePage {
  const RoutePage();
}
class AutoRoute {
  const AutoRoute({this.path, this.page, this.initial = false});
  final String? path;
  final Object? page;
  final bool initial;
}
class TodayRoute {
  static const Object page = Object();
}
class InvoicePreviewRoute {
  static const Object page = Object();
}
class CreateInvoiceRoute {
  static const Object page = Object();
}
class HomeRoute {
  static const Object page = Object();
}
''');
    // Separate screen files so wrapper resolution can leave router.dart.
    File(p.join(lib, 'features', 'invoices', 'invoice_preview_body.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('class InvoicePreviewBody { const InvoicePreviewBody(); }\n');
    File(p.join(lib, 'features', 'invoices', 'create_invoice_body.dart'))
        .writeAsStringSync(
      'class CreateInvoiceBody { const CreateInvoiceBody(); }\n',
    );
    final RouteGraph graph = parseProject(tempDir.path);
    expect(graph.mode, 'auto_route');
    final RouteNode today = graph.routes.firstWhere(
      (RouteNode route) => route.id == 'TodayRoute',
    );
    expect(today.file, contains('today_screen.dart'));
    expect(today.widgetName, 'TodayScreen');
    expect(
      graph.edges.any(
        (Edge edge) =>
            edge.from == 'TodayRoute' && edge.to == 'InvoicePreviewRoute',
      ),
      isTrue,
    );
    expect(
      graph.edges.any(
        (Edge edge) =>
            edge.from == 'TodayRoute' && edge.to == 'CreateInvoiceRoute',
      ),
      isTrue,
    );
    expect(
      graph.edges.any(
        (Edge edge) => edge.to == 'HomeRoute' && edge.raw.contains('replaceAll'),
      ),
      isTrue,
    );
  });
}
