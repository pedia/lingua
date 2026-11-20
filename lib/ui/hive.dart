import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../g.dart';

class HiveFrame extends StatefulWidget {
  const HiveFrame({super.key, this.prefix});
  final String? prefix; // prefix:

  @override
  State<HiveFrame> createState() => _HiveFrameState();
}

class _HiveFrameState extends State<HiveFrame> {
  final keys = <String>[];
  @override
  void initState() {
    reload();

    super.initState();
  }

  void reload() {
    if (widget.prefix == null) {
      final Set<String> resultSet = {
        for (final key in box.keys)
          if (key is String)
            if (key.contains(':')) '${key.split(':').first}:' else key,
      };

      keys.addAll(resultSet.toList()..sort);
    } else {
      keys.addAll(
        box.keys.cast<String>().where((k) => k.startsWith(widget.prefix!)),
      );
    }

    setState(() {});
  }

  /// Displays a dialog with a text input field and returns the entered String.
  /// Returns `null` if the user cancels or dismisses the dialog.
  Future<String?> showTextInputDialog({
    required BuildContext context,
    required String title,
    String hintText = '',
    String initialText = '',
  }) async {
    final controller = TextEditingController(text: initialText);

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: hintText),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(null), // Return null on Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(controller.text), // Return input value
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          // 1. The Cupertino Sliver AppBar
          SliverAppBar(
            title: Text(
              'Hive${widget.prefix != null ? ' ${widget.prefix}:' : ''}',
            ),
            actions: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final prefix = await showTextInputDialog(
                    context: context,
                    title: 'Input delete key prefix',
                  );
                  if (prefix != null) {
                    final ks = box.keys
                        .whereType<String>()
                        .where((k) => k.startsWith(prefix))
                        .toList();
                    if (ks.isNotEmpty && mounted) {
                      await box.deleteAll(ks);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${ks.length} deleted')),
                      );

                      setState(() {});
                    }
                  }
                },
                child: Icon(CupertinoIcons.delete_simple, size: 28),
              ),
            ],
          ),

          // 2. The iOS-styled List Content
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int i) {
                final k = keys[i];
                final v = k.endsWith(':') ? null : box.get(k);
                return CupertinoListTile(
                  title: Text(k),
                  subtitle: k.endsWith(':')
                      ? Text('count: ${keys.length}')
                      : Text('value type: ${v.runtimeType}'),
                  leading: k.endsWith(':')
                      ? const Icon(CupertinoIcons.collections)
                      : const Icon(CupertinoIcons.gear),
                  trailing: k.endsWith(':') || v is! int
                      ? const CupertinoListTileChevron()
                      : Text('$v'),
                  onTap: () async {
                    final f = await Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => k.endsWith(':')
                            ? HiveFrame(prefix: k)
                            : ValueDetail(k: k, v: v),
                      ),
                    );
                    if (f != null && f) {
                      reload();
                    }
                  },
                );
              },
              childCount: keys.length, // Number of items in your list
            ),
          ),
        ],
      ),
    );
  }
}

class ValueDetail extends StatelessWidget {
  const ValueDetail({required this.k, required this.v, super.key});

  final String k;
  final dynamic v;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            title: Text(k),
            actions: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  box.delete(k);
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
