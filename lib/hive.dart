import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'g.dart';

class HiveFrame extends StatefulWidget {
  const HiveFrame({super.key});

  @override
  State<HiveFrame> createState() => _HiveFrameState();
}

class _HiveFrameState extends State<HiveFrame> {
  final roller = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          // 1. The Cupertino Sliver AppBar
          SliverAppBar(
            title: Text('Hive Console(Debug)'),
            actions: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: null, // Add your action here
                child: Icon(CupertinoIcons.add, size: 28),
              ),
            ],
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
                  onTap: () async {
                    final f = await Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => ValueDetail(i: i, k: k, v: v),
                      ),
                    );
                    if (f != null && f) {
                      setState(() {});
                    }
                  },
                );
              },
              childCount: gbox.length, // Number of items in your list
            ),
          ),
        ],
      ),
    );
  }
}

class ValueDetail extends StatelessWidget {
  const ValueDetail({
    required this.i,
    required this.k,
    required this.v,
    super.key,
  });

  final int i;
  final String k;
  final dynamic v;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            title: Text('$i / $k'),
            actions: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  gbox.deleteAt(i);
                  Navigator.of(context).pop(true);
                }, // Add your action here
                child: Icon(CupertinoIcons.delete, size: 28),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: switch (v) {
                Uint8List() => Image.memory(v, fit: BoxFit.contain),
                _ => Text(JsonEncoder.withIndent('  ').convert(v)),
              },
            ),
          ),
        ],
      ),
    );
  }
}
