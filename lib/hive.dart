import 'dart:convert';
import 'package:flutter/cupertino.dart';

import 'g.dart';

class HiveFrame extends StatelessWidget {
  HiveFrame({super.key});

  final roller = ScrollController();
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(brightness: Brightness.light),
      home: CupertinoPageScaffold(
        // A CustomScrollView is required for slivers to work together
        child: CustomScrollView(
          slivers: <Widget>[
            // 1. The Cupertino Sliver AppBar
            CupertinoSliverNavigationBar(
              largeTitle: Text('HiveBox Console'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: null, // Add your action here
                child: Icon(CupertinoIcons.add, size: 28),
              ),
            ),

            // 2. The iOS-styled List Content
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int i) {
                  final k = gbox.keys.skip(i).first;
                  final v = gbox.getAt(i);
                  return CupertinoListTile(
                    title: Text(k),
                    subtitle: Text('${v.runtimeType}'),
                    leading: const Icon(CupertinoIcons.gear),
                    trailing: v is int
                        ? Text('$v')
                        : const CupertinoListTileChevron(),
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => ValueFrame(k: k, v: v),
                        ),
                      );
                    },
                  );
                },
                childCount: gbox.length, // Number of items in your list
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ValueFrame extends StatelessWidget {
  const ValueFrame({required this.k, required this.v, super.key});

  final String k;
  final dynamic v;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // A CustomScrollView is required for slivers to work together
      child: CustomScrollView(
        slivers: <Widget>[
          CupertinoSliverNavigationBar(largeTitle: Text(k)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(JsonEncoder.withIndent('  ').convert(v)),
            ),
          ),
        ],
      ),
    );
  }
}
