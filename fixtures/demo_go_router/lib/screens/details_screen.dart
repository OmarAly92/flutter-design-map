import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DetailsScreen extends StatelessWidget {
  const DetailsScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Details $id')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Item $id'),
            FilledButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: Text('Details sheet')),
                    );
                  },
                );
              },
              child: const Text('Open sheet'),
            ),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Back home'),
            ),
          ],
        ),
      ),
    );
  }
}
