import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
            onTap: () => context.go('/details/42'),
          ),
          ListTile(
            title: const Text('About'),
            onTap: () => context.push('/about'),
          ),
          ListTile(
            title: const Text('Settings'),
            onTap: () => context.goNamed('settings'),
          ),
        ],
      ),
    );
  }
}
