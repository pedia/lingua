import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../epub/epub.dart' as epub;
import '../data/model.dart';

class ChapterList extends ConsumerStatefulWidget {
  const ChapterList(this.book, this.id, {super.key});
  final epub.Book book;
  final int id;

  @override
  ConsumerState<ChapterList> createState() => _ChapterListState();
}

class _ChapterListState extends ConsumerState<ChapterList> {
  final roller = ItemScrollController();
  @override
  Widget build(BuildContext context) {
    final pp = ref.watch(currentProgressProvider.notifier);
    return ScrollablePositionedList.builder(
      itemScrollController: roller,
      key: PageStorageKey<int>(widget.id),
      initialScrollIndex: pp.state?.chapterIndex ?? 0,
      itemCount: widget.book.chapters.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: ListTile(
              title: Text(widget.book.title),
              subtitle: Text(widget.book.author),
            ),
          );
        }
        final i = index - 1;
        return ListTile(
          selected: i == pp.state?.chapterIndex,
          title: Text(widget.book.chapters[i].title),
          onTap: () {
            Navigator.pop(context);
            ref
                .read(currentProgressProvider.notifier)
                .update((_) => pp.state?.copyWith(chapterIndex: i));
          },
        );
      },
    );
  }
}
