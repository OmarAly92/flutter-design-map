import 'package:demo_navigator/main.dart';
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
            title: const Text('About'),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
          ),
          ListTile(
            title: const Text('Settings'),
            onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
          ListTile(
            title: const Text('Details'),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.details,
              arguments: '42',
            ),
          ),
        ],
      ),
    );
  }
}
