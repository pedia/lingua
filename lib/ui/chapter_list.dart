import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:go_router/go_router.dart';
import '../chunk/chunk.dart';
import '../data/model.dart';
import '../ui/book.dart' as legacy;
import '../../g.dart';
import '../../hw.dart';

@immutable
class ChapterList extends ConsumerWidget {
  const ChapterList(this.id, this.book, {this.isTablet = false, super.key});
  final int id;
  final Book book;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chs = book.chapters;
    final ci = ref.watch(legacy.isp(id).select((s) => s.readChapterIndex));
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
            ref.read(legacy.isp(id).notifier).update(readChapterIndex: i);
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
  final Book book;
  final int initialIndex;

  @override
  ConsumerState<TheDrawer> createState() => _TheDrawerState();
}

class _TheDrawerState extends ConsumerState<TheDrawer>
    with TickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
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
            leading: lazyBoxImage('icon:${widget.id}'),
            title: Text(widget.book.title),
            subtitle: Text(widget.book.author ?? ''),
          ),
        ),
        TabBar(
          isScrollable: true,
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: 'Chapters'),
            Tab(text: 'Highlight'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ChapterList(widget.id, widget.book),
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

  static List<Note> fromBox(int id) {
    final m = box.get('note:$id');
    if (m != null && m is List) {
      return m
          .map((i) => Note.fromJson((i as Map).cast<String, dynamic>()))
          .toList();
    }
    return [];
  }
}

class NoteList extends ConsumerWidget {
  const NoteList(this.id, {super.key});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ns = Note.fromBox(id);
    return ListView.builder(
      itemCount: ns.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(ns[i].note),
        subtitle: Text('${i + 1}', style: TextStyle(fontSize: 10)),
        onTap: () {
          ref.read(legacy.isp(id).notifier).update(readChapterIndex: i);
          ref.read(linep.notifier).update(0);
          context.push('/book/$id');
        },
      ),
    );
  }
}

void newNote(int id, Note note) {
  final ns = Note.fromBox(id);
  ns.insert(0, note);
  box.put('note:$id', ns);
}

class NoteScreen extends ConsumerWidget {
  const NoteScreen({super.key});

  Iterable<int> get ids => box.keys
      .cast<String>()
      .where((k) => k.startsWith('note:'))
      .map((k) => k.substring(5))
      .map((k) => int.parse(k));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bids = ids.toList();
    return Scaffold(
      appBar: AppBar(title: Text('Hightlights')),
      body: ListView.builder(
        itemCount: bids.length,
        itemBuilder: (_, i) {
          final ns = Note.fromBox(bids[i]);
          return ExpansionTile(
            title: Text(Item.fromBox(bids[i]).name ?? '${bids[i]}'),
            children: ns
                .map(
                  (n) => ListTile(
                    title: Text(n.note),
                    subtitle: Text(
                      '${n.ci + 1}',
                      style: TextStyle(fontSize: 10),
                    ),
                    onTap: () {
                      ref
                          .read(legacy.isp(bids[i]).notifier)
                          .update(readChapterIndex: n.ci);
                      context.push('/book/${bids[i]}');
                    },
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
