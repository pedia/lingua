import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../data/model.dart';
import '../g.dart';
import 'open.dart';
import '../imap.dart';

class ShelfFrame extends ConsumerStatefulWidget {
  const ShelfFrame({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ShelfFrameState();
}

class _ShelfFrameState extends ConsumerState<ShelfFrame>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  StreamSubscription? subOpenFile;
  List<Item>? searchResult;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_search);

    subOpenFile = OpenPump.stream.listen((fn) {
      debugPrint('lib got relative path:$fn');
      ref
          .read(shopProvider.notifier)
          .addItemTo(
            ref.read(shopProvider.select((s) => s.current)),
            Item(
              id: nextId(),
              ctime: DateTime.now(),
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

  /// search book's title|author|description
  void _search() {
    String q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        searchResult = null;
      } else {
        searchResult = ref.read(shopProvider).search(q);
      }
    });
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
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              // Top Row: Search box + button
              title: Row(
                children: [
                  Expanded(
                    child: CupertinoSearchTextField(
                      focusNode: _searchFocus,
                      controller: _searchController,
                      placeholder: 'Search titles or authors...',
                      style: TextStyle(fontFamily: '.osdefault'),
                      onSuffixTap: () {
                        _searchController.clear();
                        if (_searchFocus.hasFocus) {
                          _searchFocus.unfocus();
                        }
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
                      // /data/user/0/com.lingua.reader.lingua/cache/file_picker/1792052890257/最后...
                      if (result?.files != null) {
                        for (final file in result!.files) {
                          OpenPump.send(file.path!);
                        }

                        FilePicker.clearTemporaryFiles();
                      }
                    },
                    child: const Icon(
                      CupertinoIcons.add_circled_solid,
                      size: 28,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => context.push('/setting'),
                    child: const Icon(CupertinoIcons.settings, size: 28),
                  ),
                ],
              ),
              // Second Row: Dynamic TabBar + button
              bottom: searchResult == null
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Row(
                        children: [
                          Expanded(
                            child: TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              tabs: shelves
                                  .map((s) => Tab(text: s.name))
                                  .toList(),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => context.push('/shelf-mgmt'),
                            child: Icon(Icons.edit),
                          ),
                        ],
                      ),
                    )
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Text('History'),
                    ),
            ),
          ];
        },
        body: searchResult == null
            ? TabBarView(
                controller: _tabController,
                children: shelves
                    .imap((i, shelf) => _buildBookList(i))
                    .toList(),
              )
            : Scrollbar(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: searchResult!.length,
                  itemBuilder: (context, index) =>
                      buildTile(context, searchResult![index]),
                ),
              ),
      ),
    );
  }

  Widget _buildBookList(int shelfidx) {
    final shelf = ref.watch(shopProvider.select((s) => s.shelves[shelfidx]));
    return Scrollbar(
      child: ListView.builder(
        key: PageStorageKey<String>('tab$shelfidx'),
        primary: true,
        restorationId: 'shelf:$shelfidx',
        padding: const EdgeInsets.all(16.0),
        itemCount: shelf.items.length,
        itemBuilder: (context, i) => buildTile(context, shelf.items[i]),
      ),
    );
  }

  Widget buildTile(BuildContext context, Item e) => ListTile(
    title: Text(
      e.name!,
      maxLines: 3,
      softWrap: true,
      style: TextStyle(fontFamily: '.osdefault'),
    ),
    subtitle: e.subtitle.isEmpty
        ? null
        : Text(
            e.subtitle,
            style: TextStyle(fontFamily: '.osdefault', fontSize: 12),
          ),
    leading: boxImage('icon:${e.id}'),
    // trailing: const CupertinoListTileChevron(),
    onTap: () {
      // TODO: ugly
      ref.read(ciip.notifier).update(e.id);
      context.push('/read/${e.id}');
      ref.read(shopProvider.notifier).touch(e.id);
    },
    onLongPress: () => context.push('/edit/${e.id}'),
  );

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

/// Scan application documents books/
Future<int> scan(WidgetRef ref) async {
  final appDir = await getApplicationDocumentsDirectory();
  final booksDir = Directory(p.join(appDir.path, 'books'));

  int c = 0;
  final shelfidx = ref.read(shopProvider.select((s) => s.current));
  final shop = ref.read(shopProvider);

  await for (final e in booksDir.list()) {
    if (e.path.endsWith('.epub')) {
      final fp = e.path.substring(booksDir.path.length + 1); // +1 for last /

      if (-1 == shop.find(fp)) {
        ref
            .read(shopProvider.notifier)
            .addItemTo(
              shelfidx,
              Item(
                id: nextId(),
                ctime: DateTime.now(),
                type: ItemType.file,
                path: fp,
                name: p.basename(fp).replaceAll('.epub', ''),
              ),
            );
        c += 1;
      }
    }
  }

  return Future.value(c);
}
