import 'package:demo_auto_route/app_router.dart';
import 'package:flutter/material.dart';

@RoutePage()
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListTile(
        title: const Text('About from settings'),
        onTap: () => context.router.push(const AboutRoute()),
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
}
