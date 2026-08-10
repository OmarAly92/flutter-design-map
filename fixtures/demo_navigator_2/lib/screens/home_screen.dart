import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenAbout,
    required this.onOpenSettings,
    required this.onOpenDetails,
  });

  final VoidCallback onOpenAbout;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        children: <Widget>[
          ListTile(title: const Text('About'), onTap: onOpenAbout),
          ListTile(title: const Text('Settings'), onTap: onOpenSettings),
          ListTile(
            title: const Text('Details'),
            onTap: () => onOpenDetails('42'),
          ),
        ],
      ),
    );
  }
}
