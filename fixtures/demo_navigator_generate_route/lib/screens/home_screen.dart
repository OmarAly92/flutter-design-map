import 'package:demo_navigator_generate_route/core/routes_strings.dart';
import 'package:demo_navigator_generate_route/widgets/promo_card.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const PromoCard(),
          TextButton(
            onPressed: () => Navigator.pushNamed(
              context,
              RoutesStrings.settingsScreen,
            ),
            child: const Text('Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(
              RoutesStrings.addTransactionScreen,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
