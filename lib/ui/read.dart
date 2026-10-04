import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'book.dart';
import 'gadget.dart';

/// Material Silver Style reader
class ReadFrame extends ConsumerWidget {
  ReadFrame({required this.id, super.key});
  final int id;

  final roller = ScrollController();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FullScreen(
      child: Scaffold(
        body: Scrollbar(
          controller: roller,
          child: CustomScrollView(
            controller: roller,
            slivers: [
              const SliverAppBar(
                title: Text('Material Silver, Scroll Up'),
                // Disappears on scroll down, reveals immediately on scroll up
                floating: true,
                // Snaps fully open with a slight upward swipe (highly recommended)
                snap: true,
                // Set to false so it completely hides when scrolling down
                pinned: false,
                elevation: 2.0,
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => RichText(
                    text: TextSpan(children: [TextSpan(text: 'Item #$index')]),
                  ),
                  childCount: 140,
                ),
              ),
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
