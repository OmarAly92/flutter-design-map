import 'package:flutter/material.dart';

import 'pages/visualiser_home_page.dart';
import 'theme/visualiser_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlutterMapVisualiserApp());
}

class FlutterMapVisualiserApp extends StatelessWidget {
  const FlutterMapVisualiserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter-map visualiser',
      debugShowCheckedModeBanner: false,
      theme: VisualiserTheme.build(),
      home: const VisualiserHomePage(),
    );
  }
}
