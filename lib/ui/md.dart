import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/epub.dart' as epub;
import '../hw.dart';
import 'chapter_list.dart';
import 'read.dart';
import 'gadget.dart';
import 'book.dart';

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
  const MasterDetailContainer(this.id, {super.key});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ab = ref.watch(bookProvider(id));
    return AsyncValueX(ab).when(
      data: (book) {
        if (book == null) {
          return ErrScreen('Unable to open item:$id');
        }
        return builds(context, book);
      },
      loading: () => const Center(), // TODO: better solution
      error: (err, stackTrace) {
        print(stackTrace.toString().substring(0, 1000));
        return ErrScreen('Unable to open it\n$err');
      },
    );
  }

  Widget builds(BuildContext context, epub.Book book) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: isTablet
          ? Row(
              children: [
                // Left Pane: Master List View
                SizedBox(
                  width: 280,
                  child: ChapterList(id, book, isTablet: true),
                ),
                VerticalDivider(width: 1, thickness: 1),
                // Right Pane: Detail View
                Expanded(child: DetailView(id, book)),
              ],
            )
          : ChapterList(id, book, isTablet: false),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. DETAIL VIEW (RIGHT PANE)
// -----------------------------------------------------------------------------

class DetailView extends ConsumerWidget {
  DetailView(this.id, this.book, {super.key});
  final int id;
  final epub.Book book;
  final roller = ScrollController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(isp(id).select((s) => s.read.ci), (p, n) {
      if (n != p && roller.hasClients) {
        roller.jumpTo(0);
      }
    });

    final ci = ref.watch(isp(id).select((o) => o.read.ci));
    final ch = book.chapters[ci];

    return SelectableRegion(
      selectionControls: materialTextSelectionHandleControls,
      // contextMenuBuilder: selectToolbar,
      child: HtmlWidget(
        html: ch.content,
        mode: Mode.list,
        roller: roller,
        provider: ArchiveProvider(ch.href, book.files),
      ),
    );
  }
}
