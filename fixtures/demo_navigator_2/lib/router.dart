import 'package:demo_navigator_2/screens/about_screen.dart';
import 'package:demo_navigator_2/screens/details_screen.dart';
import 'package:demo_navigator_2/screens/home_screen.dart';
import 'package:demo_navigator_2/screens/settings_screen.dart';
import 'package:flutter/material.dart';

class AppRoutePath {
  const AppRoutePath.home()
      : id = null,
        isAbout = false,
        isSettings = false;
  const AppRoutePath.about()
      : id = null,
        isAbout = true,
        isSettings = false;
  const AppRoutePath.settings()
      : id = null,
        isAbout = false,
        isSettings = true;
  const AppRoutePath.details(this.id)
      : isAbout = false,
        isSettings = false;

  final String? id;
  final bool isAbout;
  final bool isSettings;
}

class AppRouteParser extends RouteInformationParser<AppRoutePath> {
  @override
  Future<AppRoutePath> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final Uri uri = Uri.parse(routeInformation.location ?? '/');
    if (uri.pathSegments.isEmpty) {
      return const AppRoutePath.home();
    }
    if (uri.pathSegments.first == 'about') {
      return const AppRoutePath.about();
    }
    if (uri.pathSegments.first == 'settings') {
      return const AppRoutePath.settings();
    }
    if (uri.pathSegments.first == 'details' && uri.pathSegments.length >= 2) {
      return AppRoutePath.details(uri.pathSegments[1]);
    }
    return const AppRoutePath.home();
  }

  @override
  RouteInformation? restoreRouteInformation(AppRoutePath configuration) {
    if (configuration.isAbout) {
      return const RouteInformation(location: '/about');
    }
    if (configuration.isSettings) {
      return const RouteInformation(location: '/settings');
    }
    if (configuration.id != null) {
      return RouteInformation(location: '/details/${configuration.id}');
    }
    return const RouteInformation(location: '/');
  }
}

class AppRouterDelegate extends RouterDelegate<AppRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoutePath> {
  AppRouterDelegate() : navigatorKey = GlobalKey<NavigatorState>();

  @override
  final GlobalKey<NavigatorState> navigatorKey;

  String? _selectedId;
  bool _showAbout = false;
  bool _showSettings = false;

  void openAbout() {
    _showAbout = true;
    _showSettings = false;
    _selectedId = null;
    notifyListeners();
  }

  void openSettings() {
    _showSettings = true;
    _showAbout = false;
    _selectedId = null;
    notifyListeners();
  }

  void openDetails(String id) {
    _selectedId = id;
    _showAbout = false;
    _showSettings = false;
    notifyListeners();
  }

  void goHome() {
    _selectedId = null;
    _showAbout = false;
    _showSettings = false;
    notifyListeners();
  }

  @override
  AppRoutePath get currentConfiguration {
    if (_showAbout) {
      return const AppRoutePath.about();
    }
    if (_showSettings) {
      return const AppRoutePath.settings();
    }
    if (_selectedId != null) {
      return AppRoutePath.details(_selectedId);
    }
    return const AppRoutePath.home();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: <Page<void>>[
        MaterialPage<void>(
          key: const ValueKey<String>('home'),
          child: HomeScreen(
            onOpenAbout: openAbout,
            onOpenSettings: openSettings,
            onOpenDetails: openDetails,
          ),
        ),
        if (_showAbout)
          MaterialPage<void>(
            key: const ValueKey<String>('about'),
            child: AboutScreen(onHome: goHome),
          ),
        if (_showSettings)
          const MaterialPage<void>(
            key: ValueKey<String>('settings'),
            child: SettingsScreen(),
          ),
        if (_selectedId != null)
          MaterialPage<void>(
            key: ValueKey<String>('details-$_selectedId'),
            child: DetailsScreen(id: _selectedId!),
          ),
      ],
      onPopPage: (Route<dynamic> route, dynamic result) {
        if (!route.didPop(result)) {
          return false;
        }
        goHome();
        return true;
      },
    );
  }

  @override
  Future<void> setNewRoutePath(AppRoutePath configuration) async {
    _showAbout = configuration.isAbout;
    _showSettings = configuration.isSettings;
    _selectedId = configuration.id;
  }
}
