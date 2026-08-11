import 'package:demo_navigator_generate_route/core/routes_strings.dart';
import 'package:demo_navigator_generate_route/screens/add_transaction_screen.dart';
import 'package:demo_navigator_generate_route/screens/home_screen.dart';
import 'package:demo_navigator_generate_route/screens/login_screen.dart';
import 'package:demo_navigator_generate_route/screens/settings_screen.dart';
import 'package:flutter/material.dart';

sealed class AppRouter {
  static final GlobalKey<NavigatorState> navigationKey =
      GlobalKey<NavigatorState>();

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RoutesStrings.homeScreen:
        return MaterialPageRoute<void>(
          builder: (BuildContext context) => const HomeScreen(),
        );
      case RoutesStrings.loginScreen:
        return MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return const LoginScreen();
          },
        );
      case RoutesStrings.settingsScreen:
        return MaterialPageRoute<void>(
          builder: (BuildContext context) => const SettingsScreen(),
        );
      case RoutesStrings.addTransactionScreen:
        return MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (BuildContext context) => const AddTransactionScreen(),
        );
    }
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => const Scaffold(),
    );
  }
}
