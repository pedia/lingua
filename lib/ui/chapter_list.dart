import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lingua/ui/search.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../epub/epub.dart' as epub;
import '../../g.dart';
import 'book.dart';
import '../../hw.dart';

@immutable
class ChapterList extends ConsumerWidget {
  const ChapterList(this.id, this.book, {this.isTablet = false, super.key});
  final int id;
  final epub.Book book;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chs = book.chapters;
    final ci = ref.watch(isp(id).select((s) => s.read.ci));
    return ScrollablePositionedList.builder(
      itemScrollController: ItemScrollController(),
      key: PageStorageKey<String>('cl:$id'),
      initialScrollIndex: ci,
      itemCount: chs.length,
      itemBuilder: (context, i) {
        return ListTile(
          selected: i == ci,
          title: Text(chs[i].title),
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          onTap: () {
            if (!isTablet) Navigator.pop(context);
            ref
                .read(isp(id).notifier)
                .updateRead(chapterIndex: i, lineIndex: 0);
            ref.read(linep.notifier).update(0);
          },
        );
      },
    );
  }
}

class TheDrawer extends ConsumerStatefulWidget {
  const TheDrawer(this.id, this.book, {this.initialIndex = 0, super.key});
  final int id;
  final epub.Book book;
  final int initialIndex;

  @override
  ConsumerState<TheDrawer> createState() => _TheDrawerState();
}

class _TheDrawerState extends ConsumerState<TheDrawer>
    with TickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialIndex,
  );
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          child: ListTile(
            leading: boxImage('icon:${widget.id}'),
            title: Text(widget.book.title),
            subtitle: Text(widget.book.author),
          ),
        ),
        TabBar(
          isScrollable: true,
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: 'Chapters'),
            Tab(text: 'Search'),
            Tab(text: 'Highlight'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ChapterList(widget.id, widget.book),
              SearchView(widget.book),
              Placeholder(),
            ],
          ),
        ),
      ],
    );
  }
}
