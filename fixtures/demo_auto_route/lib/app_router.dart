@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
        AutoRoute(
          path: '/',
          page: HomeRoute.page,
          initial: true,
          children: <AutoRoute>[
            AutoRoute(path: 'details/:id', page: DetailsRoute.page),
          ],
        ),
        AutoRoute(path: '/about', page: AboutRoute.page),
        AutoRoute(path: '/settings', page: SettingsRoute.page),
      ];
}

// Stand-ins so the fixture reads like auto_route without generated .gr.dart.
class RootStackRouter {
  const RootStackRouter();
}

class AutoRouterConfig {
  const AutoRouterConfig({this.replaceInRouteName});
  final String? replaceInRouteName;
}

class AutoRoute {
  const AutoRoute({
    this.path,
    this.page,
    this.initial = false,
    this.children,
    this.fullscreenDialog = false,
  });

  final String? path;
  final Object? page;
  final bool initial;
  final List<AutoRoute>? children;
  final bool fullscreenDialog;
}

class HomeRoute {
  const HomeRoute();
  static const Object page = Object();
}

class DetailsRoute {
  const DetailsRoute({required this.id});
  final String id;
  static const Object page = Object();
}

class AboutRoute {
  const AboutRoute();
  static const Object page = Object();
}

class SettingsRoute {
  const SettingsRoute();
  static const Object page = Object();
}
