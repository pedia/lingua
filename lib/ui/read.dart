import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../epub/epub.dart' as epub;
import 'book.dart';
import 'gadget.dart';
import '../hw.dart';
import 'chapter_list.dart';

/// Material Silver Style Reader
class ReadFrame extends ConsumerStatefulWidget {
  ReadFrame({required this.id, super.key});
  final int id;

  @override
  ConsumerState<ReadFrame> createState() => _ReadFrameState();
}

class _ReadFrameState extends ConsumerState<ReadFrame> {
  final roller = ScrollController();

  late StreamSubscription sub;
  late epub.Book book;

  @override
  Widget build(BuildContext context) {
    // ci change, scroll to top
    ref.listen(isp(widget.id).select((s) => s.read.ci), (p, n) {
      if (n != p && roller.hasClients) {
        roller.jumpTo(0);
      }
    });
    //
    // ref.listen(isp(widget.id), (previous, next) {
    //   if (next.read.li != previous?.read.li) {
    //     ref.read(linep.notifier).updateActive(next.read.li);
    //   }
    // });

    // save current progress
    ref.listen(linep, (prev, next) {
      if (next != null && next != prev) {
        ref.read(isp(widget.id).notifier).updateRead(lineIndex: next);
      }
    });

    final ab = ref.watch(bookProvider(widget.id));
    return AsyncValueX(ab).when(
      data: (book) {
        if (book == null) {
          return ErrScreen('Unable to open item:${widget.id}');
        }
        this.book = book;
        return builds(context, book);
      },
      loading: () => const Center(), // TODO: better solution
      error: (err, stackTrace) {
        print(stackTrace.toString().substring(0, 1000));
        return ErrScreen('Unable to open it\n$err');
      },
    );
  }

  Widget builds(BuildContext context, epub.Book book) {
    final ci = ref.watch(isp(widget.id).select((o) => o.read.ci));
    final ch = book.chapters[ci];
    return FullScreen(
      child: Scaffold(
        drawer: Drawer(width: 280, child: ChapterList(widget.id, book)),
        body: SelectableRegion(
          selectionControls: materialTextSelectionHandleControls,
          // contextMenuBuilder: selectToolbar,
          child: CustomScrollView(
            restorationId: 'read-${widget.id}-$ci',
            controller: roller,
            slivers: [
              SliverAppBar(
                title: Text(ch.title),
                // Disappears on scroll down, reveals immediately on scroll up
                floating: true,
                // Snaps fully open with a slight upward swipe (highly recommended)
                snap: true,
                // Set to false so it completely hides when scrolling down
                pinned: false,
                elevation: 2.0,
              ),
              HtmlWidget(html: ch.content, mode: Mode.sliver, roller: roller),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          decoration: BoxDecoration(
            // color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total: \$150.00',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(onPressed: () {}, child: const Text('Checkout')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
