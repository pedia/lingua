import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/book.dart';
import '../hw.dart';

class ProviderScreen extends ConsumerWidget {
  final int id;

  const ProviderScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('provider screen build');
    return Scaffold(
      appBar: AppBar(title: Text('Reading $id')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('current: ${ref.watch(linep)}'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () =>
                ref.read(linep.notifier).update(Random().nextInt(30)),
            child: const Text('Line random'),
          ),
          ElevatedButton(
            onPressed: () {
              final c = ref.read(linep);
              print('current line: $c');
              ref.read(linep.notifier).update((c ?? 0) + 1);
            },
            child: const Text('line +1'),
          ),
          ElevatedButton(
            onPressed: () {
              final c = ref.read(linep);
              print('current line: $c');
              ref.read(linep.notifier).update(c ?? 0 + 1); // <- bug
            },
            child: const Text('line +1(bug)'),
          ),
          ElevatedButton(
            onPressed: () => ref.read(linep.notifier).update(0),
            child: const Text('line -> 0'),
          ),
          ElevatedButton(
            onPressed: () => ref.read(linep.notifier).update(null),
            child: const Text('line -> null'),
          ),
          const Divider(height: 2),
          Text('read ci: ${ref.watch(isp(id).select((p) => p.read.ci))}'),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () =>
                ref.read(isp(id).notifier).updateRead(chapterIndex: 4),
            child: const Text('ci: 4'),
          ),
          Text('read li: ${ref.watch(isp(id).select((p) => p.read.li))}'),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () =>
                ref.read(isp(id).notifier).updateRead(lineIndex: 5),
            child: const Text('li: 5'),
          ),
        ],
      ),
    );
  }
}
