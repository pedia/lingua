import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/book.dart';
import '../hw.dart';

class ProviderScreen extends ConsumerStatefulWidget {
  final int id;

  const ProviderScreen({super.key, required this.id});

  @override
  ConsumerState<ProviderScreen> createState() => _ProviderScreenState();
}

class _ProviderScreenState extends ConsumerState<ProviderScreen> {
  @override
  void dispose() {
    // Avoid using ref in State.dispose.
    // Ref is already disposed when State.dispose is called.
    // ref.read(isp(widget.id));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('provider screen build');
    return Scaffold(
      appBar: AppBar(title: Text('Reading ${widget.id}')),
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
          Text(
            'read ci: ${ref.watch(isp(widget.id).select((p) => p.readChapterIndex))}',
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () =>
                ref.read(isp(widget.id).notifier).update(readChapterIndex: 4),
            child: const Text('ci: 4'),
          ),
          Text(
            'read ci: ${ref.watch(isp(widget.id).select((p) => p.readChapterIndex))}',
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () =>
                ref.read(isp(widget.id).notifier).update(offset: 5.0),
            child: const Text('offset: 5'),
          ),
        ],
      ),
    );
  }
}
