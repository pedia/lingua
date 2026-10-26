import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  String _searchTerm = '';
  final _searchFocus = FocusNode();
  StreamSubscription? subOpenFile;
  List<Item>? searchResult;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_search);

    subOpenFile = OpenPump.stream.listen((fn) {
      debugPrint('lib got relative path:$fn');

      String name = p.basename(fn).replaceAll('.epub', '');
      if (name.contains('%3A') && fn.startsWith('content://')) {
        name = Uri.decodeComponent(name);
        name = p.basename(name).replaceAll('.epub', '');
      }

      ref
          .read(shopProvider.notifier)
          .addItemTo(
            ref.read(shopProvider.select((s) => s.current)),
            Item(
              id: nextId(),
              ctime: DateTime.now(),
              type: ItemType.file,
              path: fn,
              name: name,
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
    if (q == _searchTerm) {
      return;
    }

    setState(() {
      if (q.isEmpty) {
        searchResult = null;
      } else {
        searchResult = ref.read(shopProvider).search(q);
      }
      _searchTerm = q;
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
                    onPressed: pickFiles,
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
                            onPressed: () async {
                              final n = await context.push<int>('/shelf-mgmt');
                              _initTabController(length: n);
                              setState(() {});
                            },
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
        itemCount: shelf.iids.length,
        itemBuilder: (context, i) => buildTile(context, shelf.item(i)),
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
    leading: lazyBoxImage('icon:${e.id}'),
    // trailing: const CupertinoListTileChevron(),
    onTap: () {
      // TODO: ugly
      ref.read(ciip.notifier).update(e.id);
      context.push('/read/${e.id}');
      ref.read(shopProvider.notifier).touch(e.id);
    },
    onLongPress: () => context.push('/edit/${e.id}'),
  );
}
