import 'package:demo_auto_route/app_router.dart';
import 'package:flutter/material.dart';

@RoutePage()
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: const Text('Open details'),
            onTap: () => context.router.push(const DetailsRoute(id: '42')),
          ),
          ListTile(
            title: const Text('About'),
            onTap: () => context.router.push(const AboutRoute()),
          ),
          ListTile(
            title: const Text('Settings'),
            onTap: () => context.router.navigate(const SettingsRoute()),
          ),
        ],
      ),
    );
  }
}

class RoutePage {
  const RoutePage();
}

extension on BuildContext {
  _Router get router => const _Router();
}

class _Router {
  const _Router();
  void push(Object route) {}
  void navigate(Object route) {}
}
