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
  final roller = ScrollController();
  @override
  Widget build(BuildContext context) {
    final p = ref.watch(progressProvider);
    return Scrollbar(
      controller: roller,
      child: ListView.builder(
        primary: true,
        controller: roller,
        key: PageStorageKey<int>(widget.id),
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
            selected: i == p.chapterIndex,
            title: Text(widget.book.chapters[i].title),
            onTap: () {
              Navigator.pop(context);
              ref.read(progressProvider.notifier).update(i);
            },
          );
        },
      ),
    );
  }
}
