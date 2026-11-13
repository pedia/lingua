import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../g.dart';

// 1. Provider to track the currently selected ID/category
final selectedIdProvider = StateProvider<String>((ref) => 'cat_1');

class OffsetDemoScreen extends ConsumerWidget {
  const OffsetDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedIdProvider);
    final categories = ['cat_1', 'cat_2', 'cat_3'];

    return Scaffold(
      appBar: AppBar(title: Text('Viewing: Category $selectedId')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Select Category',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            for (String catId in categories)
              ListTile(
                leading: const Icon(Icons.folder),
                title: Text('Category $catId'),
                selected: selectedId == catId,
                onTap: () {
                  // Update ID and close drawer
                  ref.read(selectedIdProvider.notifier).state = catId;
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      // ValueKey(selectedId) forces Flutter to tear down the old list
      // and recreate a fresh one with initState when the category changes.
      body: IdBasedScrollListView(key: ValueKey(selectedId), id: selectedId),
    );
  }
}

class IdBasedScrollListView extends ConsumerStatefulWidget {
  final String id;

  const IdBasedScrollListView({required this.id, super.key});

  @override
  ConsumerState<IdBasedScrollListView> createState() =>
      _IdBasedScrollListViewState();
}

class _IdBasedScrollListViewState extends ConsumerState<IdBasedScrollListView> {
  late final ScrollController _roller;

  @override
  void initState() {
    super.initState();

    // Read the saved offset scoped specifically to this ID
    final double offset = box.get(
      'scroll_offset_${widget.id}',
      defaultValue: 100.0,
    );

    // Initialize controller at 0.0 to prevent layout clamping errors
    _roller = ScrollController(
      initialScrollOffset: offset,
      onAttach: (position) {
        print('roller attached $position\n$_roller');
      },
      onDetach: (position) {
        print('roller deattached $position\n$_roller');
      },
    );

    // Don't need to jump
    // Jump to the saved offset *after* the first frame renders items
    // if (offset > 0.0) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (_scrollController.hasClients) {
    //       _scrollController.jumpTo(offset);
    //     }
    //   });
    // }
  }

  @override
  void dispose() {
    print('roller dispose $_roller');
    // Save the final position scoped to this ID right before disposal
    if (_roller.hasClients) {
      box.put('scroll_offset_${widget.id}', _roller.offset);
    }
    _roller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('ListView build: $_roller');
    return ListView.builder(
      controller: _roller,
      itemCount: 50,
      itemBuilder: (context, index) {
        return ListTile(
          leading: CircleAvatar(child: Text('$index')),
          title: Text('Item #$index for ID: ${widget.id}'),
          subtitle: const Text(
            'Position tracked and saved independently in Hive',
          ),
        );
      },
    );
  }
}
