import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../epub/epub.dart' as epub;
import '../../g.dart';
import 'state.dart';

class ChapterList extends ConsumerStatefulWidget {
  const ChapterList({required this.id, required this.book, super.key});
  final int id;
  final epub.Book book;

  @override
  ConsumerState<ChapterList> createState() => _ChapterListState();
}

class _ChapterListState extends ConsumerState<ChapterList> {
  // not work for 0.3.8 final roller = ScrollController();
  final isroller = ItemScrollController();

  @override
  Widget build(BuildContext context) {
    final chs = ref.watch(readp.select((s) => s.book.chapters));
    return ScrollablePositionedList.builder(
      itemScrollController: isroller,
      key: PageStorageKey<int>(ref.watch(readp.select((s) => s.id))),
      initialScrollIndex: 0,
      itemCount: chs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: ListTile(
              leading: boxImage('icon-${widget.id}'),
              title: Text(widget.book.title),
              subtitle: Text(widget.book.author),
            ),
          );
        }
        final i = index - 1;
        return ListTile(
          selected: i == ref.watch(readp.select((s) => s.progress.$1)),
          title: Text(widget.book.chapters[i].title),
          onTap: () {
            Navigator.pop(context);
            ref.read(readp.notifier).update(progress: (i, 0));
          },
        );
      },
    );
  }
}
