import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../epub/epub.dart';
import '../epub/parser.dart';
import '../data/model.dart';
import '../g.dart';
import 'book.dart';

class ShelfFrame extends ConsumerStatefulWidget {
  const ShelfFrame({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ShelfFrameState();
}

class _ShelfFrameState extends ConsumerState<ShelfFrame>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _initTabController();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initTabController({int? length}) {
    // Safely dispose the old controller if it exists before making a new one
    _tabController?.dispose();

    length ??= ref.read(shopProvider).shelves.length;
    _tabController = TabController(length: length, vsync: this);

    // Optional: Add a listener if you need to perform actions when swiping tabs
    // _tabController!.addListener(() {
    //   if (!_tabController!.indexIsChanging) {
    //     setState(() {});
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopProvider);
    return CupertinoPageScaffold(
      child: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          // final shop = ref.watch(shopProvider);
          return <Widget>[
            // 1. SCROLLABLE: This row disappears up and out of view when scrolling down
            SliverToBoxAdapter(
              child: Container(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: 'Search titles or authors...',
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        // minSize: 36,
                        onPressed: _showNewShelfDialog,
                        child: const Icon(
                          CupertinoIcons.add_circled_solid,
                          size: 28,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        // minSize: 36,
                        onPressed: () => context.push('/route'),
                        child: const Icon(CupertinoIcons.settings, size: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. PINNED: The segmented control stays fixed at the top of the viewport
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabHeaderDelegate(
                child: Material(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  child: TabBar(
                    controller: _tabController,
                    // Styling the TabBar to look cleaner and integrated with iOS styles
                    labelColor: CupertinoColors.activeBlue.resolveFrom(context),
                    unselectedLabelColor: CupertinoColors.systemGrey
                        .resolveFrom(context),
                    indicatorColor: CupertinoColors.activeBlue.resolveFrom(
                      context,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: shop.shelves.map((s) => Tab(text: s.name)).toList(),
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          // TODO: shelfIdx
          children: shop.shelves.map((s) => _buildBookList(0, s)).toList(),
        ),
      ),
    );
  }

  // Quick Mock List View for content screens
  Widget _buildBookList(int shelfIdx, Shelf shelf) {
    return CupertinoScrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: shelf.items.length,
        itemBuilder: (context, i) {
          final e = shelf.items[i];
          return Material(
            child: ListTile(
              title: Text(e.name ?? ''),
              subtitle: Text(e.subtitle),
              leading: boxImage('icon-${e.id}'),
              onTap: () {
                ref.read(ciip.notifier).update(e.id);
                context.push('book/${e.id}');
              },

              // Book? book;
              // if (e.type == ItemType.assets) {
              //   final d = await rootBundle.load(e.path);
              //   book = EpubParser().parseBytes(d.buffer.asInt8List());
              // } else if (e.type == ItemType.file) {
              //   book = await openEpub(e.path);
              // } else if (e.type == ItemType.demo) {
              //   book = sample();
              // }
            ),
          );
        },
      ),
    );
  }

  void _showNewShelfDialog() {
    final TextEditingController controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Shelf'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Shelf Name',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Create'),
            onPressed: () {
              Navigator.pop(context);

              if (controller.text.trim().isNotEmpty) {
                String name = controller.text.trim();
                int n = ref.read(shopProvider.notifier).add(name);
                _initTabController(length: n);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  // Compact height since it only contains the Segmented Control widget now
  final double height = 48.0;

  _TabHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

void scan(WidgetRef ref) async {
  final appDir = await getApplicationDocumentsDirectory();
  final booksDir = Directory(p.join(appDir.path, 'books'));

  final items = ref.read(itemsProvider);

  int c = 0;

  await for (final e in booksDir.list()) {
    if (e.path.endsWith('.epub')) {
      if (!items.any((i) => i.path == e.path)) {
        final fp = e.path.substring(booksDir.path.length + 1); // +1 for last /
        ref
            .read(shopProvider.notifier)
            .addItemTo(
              0,
              Item(
                id: nextId(),
                type: ItemType.file,
                path: fp,
                name: p.basename(fp).replaceAll('.epub', ''),
              ),
            );
        c += 1;
      }
    }
  }

  // ScaffoldMessenger.of(
  //   context,
  // ).showSnackBar(SnackBar(content: Text('$c added')));
}

class ErrScreen extends StatelessWidget {
  const ErrScreen(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Error')),
      child: Center(child: Text(text)),
    );
  }
}
