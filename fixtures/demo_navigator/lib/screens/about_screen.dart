import 'package:demo_navigator/main.dart';
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.home),
          child: const Text('Home'),
        ),
      ),
    );
  }
}
