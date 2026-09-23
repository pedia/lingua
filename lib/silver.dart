import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SilverFrame extends StatelessWidget {
  SilverFrame({super.key});

  final roller = ScrollController();
  @override
  Widget build(BuildContext context) {
    return FullScreen(
      child: Scaffold(
        body: Scrollbar(
          controller: roller,
          child: CustomScrollView(
            controller: roller,
            slivers: [
              const SliverAppBar(
                title: Text('Scroll Up to Show Me'),
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
                  childCount: 40,
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
                color: Colors.black.withAlpha(
                  25,
                ), // 2026 Flutter syntax / safe opacity
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

class FullScreen extends StatefulWidget {
  const FullScreen({this.on = true, required this.child, super.key});
  final bool on;
  final Widget child;

  @override
  State<FullScreen> createState() => _FullScreenState();
}

class _FullScreenState extends State<FullScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.on) {
      // Hide status bar when entering this screen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    if (widget.on) {
      // Restore regular status bar and bottom navigation when leaving this screen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
