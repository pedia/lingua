import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BigWidget(),
    );
  }
}

// ==========================================
// 1. DATA MODELS
// ==========================================
// NOTE: Overriding `==` and `hashCode` is REQUIRED for `.select()` to work
// properly with custom classes. You can also use the `equatable` or `freezed` packages.

@immutable
class B {
  final int c;
  final int other; // Added to show we can change B without changing B.c

  const B({required this.c, required this.other});

  B copyWith({int? c, int? other}) {
    return B(c: c ?? this.c, other: other ?? this.other);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is B && other.c == c && other.other == this.other);

  @override
  int get hashCode => Object.hash(c, other);
}

@immutable
class D {
  final int value;
  const D(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is D && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

@immutable
class E {
  final int value;
  const E(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is E && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

@immutable
class BigState {
  final int a;
  final B b;
  final List<D> listD;
  final Map<String, E> mapE;

  const BigState({
    required this.a,
    required this.b,
    required this.listD,
    required this.mapE,
  });

  BigState copyWith({int? a, B? b, List<D>? listD, Map<String, E>? mapE}) {
    return BigState(
      a: a ?? this.a,
      b: b ?? this.b,
      listD: listD ?? this.listD,
      mapE: mapE ?? this.mapE,
    );
  }
}

// ==========================================
// 2. STATE NOTIFIER
// ==========================================

class BigStateNotifier extends Notifier<BigState> {
  @override
  BigState build() {
    return const BigState(
      a: 0,
      b: B(c: 0, other: 0),
      listD: [D(0), D(0)],
      mapE: {'2': E(0), '3': E(0)},
    );
  }

  void changeA() => state = state.copyWith(a: state.a + 1);

  // Changes B, but B.c remains the same
  void changeBOnly() =>
      state = state.copyWith(b: state.b.copyWith(other: state.b.other + 1));

  // Changes B and B.c
  void changeBC() =>
      state = state.copyWith(b: state.b.copyWith(c: state.b.c + 1));

  void changeListD(int index) {
    // 1. Create a copy of the list
    final newList = List<D>.from(state.listD);
    // 2. Modify the target index
    newList[index] = D(newList[index].value + 1);
    // 3. Emit the new state
    state = state.copyWith(listD: newList);
  }

  void changeMapE(String key) {
    final newMap = Map<String, E>.from(state.mapE);
    final currentValue = newMap[key]?.value ?? 0;
    newMap[key] = E(currentValue + 1);
    state = state.copyWith(mapE: newMap);
  }
}

final bigStateProvider = NotifierProvider<BigStateNotifier, BigState>(
  BigStateNotifier.new,
);

// ==========================================
// 3. UI (WIDGETS)
// ==========================================

class BigWidget extends StatelessWidget {
  const BigWidget({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("🔄 Building BigWidget (Should only happen once)");
    return Scaffold(
      appBar: AppBar(title: const Text('Riverpod Fine-Grained Rebuilds')),
      body: const Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  WidgetA(),
                  WidgetB(),
                  WidgetBC(),
                  WidgetListD(index: 0),
                  WidgetListD(index: 1),
                  WidgetMapE(mapKey: '2'),
                  WidgetMapE(mapKey: '3'),
                ],
              ),
            ),
          ),
          Divider(),
          ControlPanel(),
        ],
      ),
    );
  }
}

// ------------------------------------------
// Individual Consumers
// ------------------------------------------

class WidgetA extends ConsumerWidget {
  const WidgetA({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint("🟢 Building WidgetA");
    final a = ref.watch(bigStateProvider.select((s) => s.a));
    return ListTile(title: Text('A: $a'));
  }
}

class WidgetB extends ConsumerWidget {
  const WidgetB({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint("🟠 Building WidgetB Whole");
    final b = ref.watch(bigStateProvider.select((s) => s.b));
    return ListTile(title: Text('B (c: ${b.c}, other:${b.other})'));
  }
}

class WidgetBC extends ConsumerWidget {
  const WidgetBC({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint("🟡 Building WidgetB.c");
    final bc = ref.watch(bigStateProvider.select((s) => s.b.c));
    return ListTile(title: Text('B.c: $bc'));
  }
}

class WidgetListD extends ConsumerWidget {
  final int index;
  const WidgetListD({super.key, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint("🔵 Building WidgetListD[$index]");
    final d = ref.watch(bigStateProvider.select((s) => s.listD[index]));
    return ListTile(title: Text('List<D>[$index]:${d.value}'));
  }
}

class WidgetMapE extends ConsumerWidget {
  final String mapKey;
  const WidgetMapE({super.key, required this.mapKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint("🟣 Building WidgetMapE['$mapKey']");
    final e = ref.watch(bigStateProvider.select((s) => s.mapE[mapKey]));
    return ListTile(title: Text('Map<String, E>[\'$mapKey\']:${e?.value}'));
  }
}

// ------------------------------------------
// Controls
// ------------------------------------------
class ControlPanel extends ConsumerWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint("🔘 Building ControlPanel (Should only happen once)");
    final notifier = ref.read(bigStateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton(
            onPressed: notifier.changeA,
            child: const Text('Change A'),
          ),
          ElevatedButton(
            onPressed: notifier.changeBOnly,
            child: const Text('Change B (not c)'),
          ),
          ElevatedButton(
            onPressed: notifier.changeBC,
            child: const Text('Change B.c'),
          ),
          ElevatedButton(
            onPressed: () => notifier.changeListD(0),
            child: const Text('Change List[0]'),
          ),
          ElevatedButton(
            onPressed: () => notifier.changeListD(1),
            child: const Text('Change List[1]'),
          ),
          ElevatedButton(
            onPressed: () => notifier.changeMapE('2'),
            child: const Text("Change Map['2']"),
          ),
          ElevatedButton(
            onPressed: () => notifier.changeMapE('3'),
            child: const Text("Change Map['3']"),
          ),
        ],
      ),
    );
  }
}

class DepFrame extends StatelessWidget {
  const DepFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: const ProviderScope(child: BigWidget()));
  }
}


// in Flutter, have A, B, B.c, List<D>, Map<String, E> in
// BigWidget, and some BigWidgetState will change A, B, B.c, 
// change List<D>[0], but [1] not rebuild
// change Map<String, E>['2'], but Map['3'] not rebuild
// Add button for change A, B, B.c, List<D>[0], List<D>[1], Map['2'], Map['3']
// add debugPrint in all build
// use Riverpod 2.6.1 implement full example code to achieve fine-grained rebuilds please
// 