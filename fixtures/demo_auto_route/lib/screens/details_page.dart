import 'package:demo_auto_route/app_router.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DetailsPage extends StatelessWidget {
  const DetailsPage({required this.id, super.key});

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
              onPressed: () => context.router.push(const HomeRoute()),
              child: const Text('Back home'),
            ),
          ],
        ),
      ),
    );
  }
}

class RoutePage {
  const RoutePage();
}

extension on BuildContext {
  _Router get router => const _Router();
}

class _Router {
  const _Router();
  void push(Object route) {}
}
