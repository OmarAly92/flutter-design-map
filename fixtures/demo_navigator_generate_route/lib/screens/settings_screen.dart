import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (BuildContext context) => const SizedBox(),
        ),
        child: const Text('Sheet'),
      ),
    );
  }
}
