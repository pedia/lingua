import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../epub/epub.dart' as epub;
import '../../g.dart';
import 'book.dart';

class ChapterList extends ConsumerStatefulWidget {
  const ChapterList(this.id, this.book, {super.key});
  final int id;
  final epub.Book book;

  @override
  ConsumerState<ChapterList> createState() => _ChapterListState();
}

class _ChapterListState extends ConsumerState<ChapterList> {
  // not work for 0.3.8 final roller = ScrollController();
  final itemroller = ItemScrollController();

  @override
  Widget build(BuildContext context) {
    final chs = widget.book.chapters;
    return ScrollablePositionedList.builder(
      itemScrollController: itemroller,
      key: PageStorageKey<String>('cl:${widget.id}'),
      initialScrollIndex: 0,
      itemCount: chs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: ListTile(
              leading: boxImage('icon:${widget.id}'),
              title: Text(widget.book.title),
              subtitle: Text(widget.book.author),
            ),
          );
        }
        final i = index - 1;
        return ListTile(
          selected: i == ref.watch(isp(widget.id)).read.ci,
          title: Text(chs[i].title),
          onTap: () {
            Navigator.pop(context);
            ref
                .read(isp(widget.id).notifier)
                .updateRead(chapterIndex: i, lineIndex: 0);
          },
        );
      },
    );
  }
}
