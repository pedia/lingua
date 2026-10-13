import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lingua/ui/search.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../epub/epub.dart' as epub;
import 'book.dart';
import '../../g.dart';
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
              NoteList(widget.id),
            ],
          ),
        ),
      ],
    );
  }
}

class Note {
  Note({required this.ci, required this.note});
  final int ci;
  final String note;

  Map<String, dynamic> toJson() => {'ci': ci, 'note': note};
  factory Note.fromJson(Map<String, dynamic> m) =>
      Note(ci: m['ci'], note: m['note']);
}

class NoteList extends ConsumerWidget {
  const NoteList(this.id, {super.key});
  final int id;

  List<Note> get notes {
    final m = gbox.get('note:$id');
    if (m != null && m is List) {
      return m
          .map((i) => Note.fromJson((i as Map).cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ns = notes;
    return ListView.builder(
      itemCount: ns.length,
      itemBuilder: (context, index) => ListTile(),
    );
  }
}

void newNote(int id, Note note) {
  final m = gbox.get('note:$id');
  final ns = <Note>[];
  if (m != null && m is List) {
    ns.addAll(m.map((i) => Note.fromJson((i as Map).cast<String, dynamic>())));
  }
  ns.add(note);
  gbox.put('note:$id', ns.map((n) => n.toJson()).toList());
}
