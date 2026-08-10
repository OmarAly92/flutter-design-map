import 'package:demo_go_router_builder/routes.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListTile(
        title: const Text('About from settings'),
        onTap: () => const AboutRoute().push(context),
      ),
    );
  }
}
