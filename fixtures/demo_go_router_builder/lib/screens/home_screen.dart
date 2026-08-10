import 'package:demo_go_router_builder/routes.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: const Text('Open details'),
            onTap: () => const DetailsRoute(id: '42').go(context),
          ),
          ListTile(
            title: const Text('About'),
            onTap: () => const AboutRoute().push(context),
          ),
          ListTile(
            title: const Text('Settings'),
            onTap: () => const SettingsRoute().go(context),
          ),
        ],
      ),
    );
  }
}
