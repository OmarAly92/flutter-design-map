import 'package:demo_navigator/screens/about_screen.dart';
import 'package:demo_navigator/screens/details_screen.dart';
import 'package:demo_navigator/screens/home_screen.dart';
import 'package:demo_navigator/screens/settings_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo Navigator',
      initialRoute: AppRoutes.home,
      routes: AppRoutes.table,
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == AppRoutes.details) {
          final Object? args = settings.arguments;
          final String id = args is String ? args : '0';
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) => DetailsScreen(id: id),
          );
        }
        return null;
      },
    );
  }
}

abstract final class AppRoutes {
  static const String home = '/';
  static const String about = '/about';
  static const String settings = '/settings';
  static const String details = '/details';

  static final Map<String, WidgetBuilder> table = <String, WidgetBuilder>{
    home: (BuildContext context) => const HomeScreen(),
    about: (BuildContext context) => const AboutScreen(),
    settings: (BuildContext context) => const SettingsScreen(),
  };
}
