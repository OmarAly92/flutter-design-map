import 'package:demo_go_router/screens/about_screen.dart';
import 'package:demo_go_router/screens/details_screen.dart';
import 'package:demo_go_router/screens/home_screen.dart';
import 'package:demo_go_router/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter createDemoRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen();
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'details/:id',
            name: 'details',
            builder: (BuildContext context, GoRouterState state) {
              return DetailsScreen(id: state.pathParameters['id'] ?? '');
            },
          ),
        ],
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (BuildContext context, GoRouterState state) {
          return const AboutScreen();
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsScreen();
        },
      ),
    ],
  );
}
