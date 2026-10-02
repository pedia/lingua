import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Route')),
      child: SafeArea(
        child: Column(
          children: [
            CupertinoButton(
              onPressed: () => context.go('/'),
              child: Text('Go /'),
            ),
            ...['/book/5', '/hive', '/setting', '/engine', '/library', '/protype'].map(
              (e) => CupertinoButton(
                onPressed: () => context.push(e),
                child: Text('Push $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
