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
      itemCount: chs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: ListTile(
              leading: boxImage('icon:$id'),
              title: Text(book.title),
              subtitle: Text(book.author),
            ),
          );
        }
        final i = index - 1;
        return ListTile(
          selected: i == ci,
          title: Text(chs[i].title),
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          onTap: () {
            if (!isTablet) Navigator.pop(context);
            ref
                .read(isp(id).notifier)
                .updateRead(chapterIndex: i, lineIndex: 0);
            ref.read(linep.notifier).updateActive(0);
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
    return TabBarView(
      controller: _tabController,
      children: [
        ChapterList(widget.id, widget.book),
        Padding(padding: const EdgeInsets.all(8.0), child: SearchView()),
        SearchView(),
      ],
    );
  }
}
