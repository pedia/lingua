import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ui/shelf.dart';

class RouteScreen extends ConsumerWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Route')),
      body: SafeArea(
        child: ListView(
          children: [
            CupertinoButton(
              onPressed: () => context.go('/'),
              child: Text('Go /'),
            ),
            ...[
              '/book/5',
              '/hive',
              '/setting',
              '/engine',
              '/library',
              '/prototype',
              '/sliver',
              '/error',
              '/shelf',
              '/read/5',
            ].map(
              (e) => CupertinoButton(
                onPressed: () => context.push(e),
                child: Text('Push $e'),
              ),
            ),

            //
            CupertinoButton(onPressed: () => scan(ref), child: Text('Scan')),
          ],
        ),
      ),
    );
  }
}
