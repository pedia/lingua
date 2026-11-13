import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Global or controller provider
final radio = StreamController<int>.broadcast();

final streamControllerProvider = Provider<StreamController<int>>((ref) {
  ref.onDispose(() {
    radio.close();
  });

  return radio;
});

void sink() {
  radio.add(2);
}

// 2. StreamProvider.autoDispose consuming the stream
final myStreamProvider = StreamProvider.autoDispose<int>((ref) {
  final controller = ref.read(streamControllerProvider);
  return controller.stream;
});

class StuckScreen extends ConsumerStatefulWidget {
  const StuckScreen({super.key});

  @override
  ConsumerState<StuckScreen> createState() => _StuckScreenState();
}

class _StuckScreenState extends ConsumerState<StuckScreen> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();

    // Listening to the stream controller
    final controller = ref.read(streamControllerProvider);
    _subscription = controller.stream.listen((event) {
      print('Listener received: $event');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  int n = 0;

  @override
  Widget build(BuildContext context) {
    // Watching the StreamProvider.autoDispose
    final streamValue = ref.watch(myStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('StreamProvider Stuck Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            streamValue.when(
              data: (val) => Text('Value: $val'),
              loading: () => const Text('Loading...'),
              error: (e, st) => Text('Error: $e'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Clicking this button triggers the controller add,
                // which immediately invokes the blocking listener above.
                ref.read(streamControllerProvider).add(n);
                n += 1;

                // streamValue.when((data) {});
              },
              child: const Text('Trigger Stream Add'),
            ),
          ],
        ),
      ),
    );
  }
}
