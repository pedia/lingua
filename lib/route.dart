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
              '/shelf-mgmt',
              '/book/4',
              '/hive',
              '/setting',
              '/engine',
              '/library',
              '/prototype',
              '/sliver',
              '/error',
              '/shelf',
              '/read/4',
              '/master-detail',
            ].map(
              (e) => ListTile(
                onTap: () => context.push(e),
                title: Text('Push $e'),
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
