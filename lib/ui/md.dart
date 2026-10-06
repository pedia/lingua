import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chapter_list.dart';
import 'read.dart';

/// left master ListView, right detail view

class Item {
  final int id;
  final String title;
  final String details;

  const Item({required this.id, required this.title, required this.details});
}

// Master list provider
final masterItemsProvider = Provider<List<Item>>((ref) {
  return List.generate(
    15,
    (i) => Item(
      id: i + 1,
      title: 'Item ${i + 1}',
      details: 'Detailed content and specifications for Item ${i + 1}.',
    ),
  );
});

// Currently selected item ID state
final selectedItemIdProvider = StateProvider<int?>((ref) => 1);

// Derived provider for the current detail item
final activeDetailItemProvider = Provider<Item?>((ref) {
  final selectedId = ref.watch(selectedItemIdProvider);
  final items = ref.watch(masterItemsProvider);
  if (selectedId == null) return null;
  return items.firstWhere(
    (item) => item.id == selectedId,
    orElse: () => items.first,
  );
});

// -----------------------------------------------------------------------------
// 2. PARENT CONTAINER (TABLET / PHONE ADAPTER)
// -----------------------------------------------------------------------------

class MasterDetailContainer extends ConsumerWidget {
  const MasterDetailContainer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(title: const Text('Master-Detail Layout')),
      body: isTablet
          ? Row(
              children: [
                // Left Pane: Master List View
                SizedBox(width: 340, child: MasterListView(isTablet: true)),
                VerticalDivider(width: 1, thickness: 1),
                // Right Pane: Detail View
                Expanded(child: DetailView()),
              ],
            )
          : const MasterListView(isTablet: false),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. MASTER LIST VIEW (LEFT PANE)
// -----------------------------------------------------------------------------

class MasterListView extends ConsumerWidget {
  final bool isTablet;

  const MasterListView({super.key, required this.isTablet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(masterItemsProvider);
    final selectedId = ref.watch(selectedItemIdProvider);

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = item.id == selectedId;

        return ListTile(
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            item.details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          selected: isTablet && isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          onTap: () {
            ref.read(selectedItemIdProvider.notifier).state = item.id;

            if (!isTablet) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: Text(item.title)),
                    body: DetailView(),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// 4. DETAIL VIEW (RIGHT PANE)
// -----------------------------------------------------------------------------

class DetailView extends ConsumerWidget {
  DetailView({super.key});
  final roller = ScrollController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(activeDetailItemProvider);

    if (item == null) {
      return const Center(child: Text('Please select an item from the left.'));
    }

    ref.listen(activeDetailItemProvider, (p, n) {
      if (n != p) {
        roller.jumpTo(0);
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView(
        // crossAxisAlignment: CrossAxisAlignment.start,
        controller: roller,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(item.details, style: Theme.of(context).textTheme.bodyLarge),
          ...List.generate(20, (i) => ListTile(title: Text('${item.id} $i'))),
        ],
      ),
    );
  }
}
