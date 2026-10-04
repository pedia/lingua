import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ui/shelf.dart';

class RouteScreen extends ConsumerWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Route')),
      child: SafeArea(
        child: Column(
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
              '/silver',
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
