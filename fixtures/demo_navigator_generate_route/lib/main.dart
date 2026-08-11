import 'package:demo_navigator_generate_route/core/app_router.dart';
import 'package:demo_navigator_generate_route/core/routes_strings.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo Navigator generateRoute',
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: RoutesStrings.homeScreen,
      navigatorKey: AppRouter.navigationKey,
    );
  }
}
