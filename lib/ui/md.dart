import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epub/epub.dart' as epub;
import '../hw.dart';
import 'chapter_list.dart';
import 'gadget.dart';
import 'book.dart';

class TabletReadFrame extends ConsumerWidget {
  const TabletReadFrame(this.id, {super.key});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ab = ref.watch(bookProvider(id));
    return AsyncValueX(ab).when(
      data: (book) {
        if (book == null) {
          return InfoScreen('Unable to open item:$id');
        }
        return builds(context, book);
      },
      loading: () => const Center(), // TODO: better solution
      error: (err, stackTrace) {
        debugPrint(stackTrace.toString().substring(0, 1000));
        return InfoScreen('Unable to open it\n$err');
      },
    );
  }

  Widget builds(BuildContext context, epub.Book book) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: isTablet
          ? Row(
              children: [
                SizedBox(
                  width: 280,
                  child: ChapterList(id, book, isTablet: true),
                ),
                VerticalDivider(width: 1, thickness: 1),
                Expanded(child: ReadView(id, book)),
              ],
            )
          : ChapterList(id, book, isTablet: false),
    );
  }
}

class ReadView extends ConsumerWidget {
  ReadView(this.id, this.book, {super.key});
  final int id;
  final epub.Book book;
  final roller = ScrollController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(isp(id).select((s) => s.readChapterIndex), (p, n) {
      if (n != p && roller.hasClients) {
        roller.jumpTo(0);
      }
    });

    final ci = ref.watch(isp(id).select((o) => o.readChapterIndex));
    final ch = book.chapters[ci];

    return SelectableRegion(
      selectionControls: materialTextSelectionHandleControls,
      // contextMenuBuilder: selectToolbar,
      child: HtmlWidget(
        html: ch.content,
        mode: Mode.list,
        roller: roller,
        provider: ArchiveProvider(ch.href, book.files),
      ),
    );
  }
}
