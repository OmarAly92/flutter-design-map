import 'package:demo_navigator_generate_route/core/routes_strings.dart';
import 'package:flutter/material.dart';

/// Lives outside the home screen's directory and is used only by HomeScreen,
/// so the edge below can only be attributed by walking widget composition.
class PromoCard extends StatelessWidget {
  const PromoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.pushNamed(RoutesStrings.loginScreen),
      child: const Text('Sign in'),
    );
  }
}

extension Navigation on BuildContext {
  Future<dynamic> pushNamed(String routeName) {
    return Navigator.of(this, rootNavigator: true).pushNamed(routeName);
  }
}
