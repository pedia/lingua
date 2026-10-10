import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lingua/ui/book_edit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../data/model.dart';
import '../g.dart';
import 'open.dart';
import 'book_edit.dart';

class ShelfFrame extends ConsumerStatefulWidget {
  const ShelfFrame({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ShelfFrameState();
}

class _ShelfFrameState extends ConsumerState<ShelfFrame>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final _searchController = TextEditingController();
  StreamSubscription? subOpenFile;
  List<Item>? searchResult;

  @override
  void initState() {
    super.initState();

    subOpenFile = OpenPump.stream.listen((fn) {
      debugPrint('lib got relative path:$fn');
      ref
          .read(shopProvider.notifier)
          .addItemTo(
            0, // TODO:
            Item(
              id: nextId(),
              type: ItemType.file,
              path: fn,
              name: p.basename(fn).replaceAll('.epub', ''),
            ),
          );
    });

    _initTabController();
  }

  @override
  void dispose() {
    subOpenFile?.cancel();
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initTabController({int? length}) {
    // Safely dispose the old controller if it exists before making a new one
    _tabController?.dispose();

    length ??= ref.read(shopProvider).shelves.length;
    _tabController = TabController(
      initialIndex: ref.read(shopProvider).current,
      length: length,
      vsync: this,
    );

    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        ref.read(shopProvider.notifier).update(current: _tabController!.index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shelves = ref.watch(shopProvider.select((shop) => shop.shelves));
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
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
                          onChanged: (v) {
                            if (v.trim().isEmpty) {
                              setState(() => searchResult = null);
                              return;
                            }

                            setState(() {
                              searchResult = ref
                                  .read(shopProvider)
                                  .search(v.trim());
                              print('${searchResult?.length}');
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        // minSize: 36,
                        onPressed: () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: const ['epub'],
                            allowMultiple: true,
                          );
                          if (result?.files != null) {
                            for (final file in result!.files) {
                              OpenPump.send(file.path!);
                            }
                          }
                        },
                        child: const Icon(
                          CupertinoIcons.add_circled_solid,
                          size: 28,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => context.push('/route'),
                        child: const Icon(CupertinoIcons.settings, size: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. PINNED: The segmented control stays fixed at the top of the viewport
            if (searchResult == null)
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabHeaderDelegate(
                  child: Row(
                    children: [
                      Expanded(
                        child: TabBar(
                          isScrollable: true,
                          controller: _tabController,
                          // Styling the TabBar to look cleaner and integrated with iOS styles
                          labelColor: CupertinoColors.activeBlue.resolveFrom(
                            context,
                          ),
                          unselectedLabelColor: CupertinoColors.systemGrey
                              .resolveFrom(context),
                          indicatorColor: CupertinoColors.activeBlue
                              .resolveFrom(context),
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: shelves.map((s) => Tab(text: s.name)).toList(),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => context.push('/shelf-mgmt'),
                        child: Icon(Icons.edit),
                      ),
                    ],
                  ),
                ),
              ),
          ];
        },
        body: searchResult != null
            ? ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: searchResult!.length,
                itemBuilder: (context, index) {
                  return buildSearchItem(context, searchResult![index]);
                },
              )
            : TabBarView(
                controller: _tabController,
                children: List.generate(
                  shelves.length,
                  (i) => _buildBookList(i),
                ),
              ),
      ),
    );
  }

  Widget _buildBookList(int shelfidx) {
    final shelf = ref.watch(shopProvider.select((s) => s.shelves[shelfidx]));
    return Scrollbar(
      child: ListView.builder(
        primary: true,
        restorationId: 'shelf:$shelfidx',
        padding: const EdgeInsets.all(16.0),
        itemCount: shelf.items.length,
        itemBuilder: (context, i) {
          final e = shelf.items[i];
          return ListTile(
            title: Text(
              '${e.name}/${e.id}',
              maxLines: 3,
              softWrap: true,
              style: TextStyle(fontFamily: '.osdefault'),
            ),
            subtitle: Text(
              e.subtitle,
              style: TextStyle(fontFamily: '.osdefault'),
            ),
            leading: SizedBox(
              // width: 64,
              height: 328, // not work
              child: boxImage('icon:${e.id}'),
            ),
            trailing: const CupertinoListTileChevron(),
            onTap: () {
              ref.read(ciip.notifier).update(e.id);
              context.push('/read/${e.id}');
              ref.read(shopProvider.notifier).touch(shelfidx, e.id);
            },
            onLongPress: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => BookEditScreen(item: e),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget buildSearchItem(BuildContext context, Item e) {
    return CupertinoListTile(
      title: Text(
        '${e.name}/${e.id}',
        maxLines: 3,
        softWrap: true,
        style: TextStyle(fontFamily: '.osdefault'),
      ),
      subtitle: Text(e.subtitle, style: TextStyle(fontFamily: '.osdefault')),
      leading: boxImage('icon:${e.id}'),
      leadingSize: 64,
      padding: EdgeInsets.only(bottom: 8),
      trailing: const CupertinoListTileChevron(),
      onTap: () {
        // TODO: ugly
        ref.read(ciip.notifier).update(e.id);
        context.push('/read/${e.id}');
        // ref.read(shopProvider.notifier).touch(shelfidx, e.id);
      },
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

  int c = 0;
  final shelfidx = ref.read(shopProvider.select((s) => s.current));
  final shelf = ref.read(shopProvider.select((s) => s.shelves[shelfidx]));

  await for (final e in booksDir.list()) {
    if (e.path.endsWith('.epub')) {
      final fp = e.path.substring(booksDir.path.length + 1); // +1 for last /

      if (!shelf.items.any((i) => i.path == fp)) {
        ref
            .read(shopProvider.notifier)
            .addItemTo(
              shelfidx,
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
