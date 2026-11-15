import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class NonSliverTextScreen extends StatefulWidget {
  const NonSliverTextScreen({super.key});

  @override
  State<NonSliverTextScreen> createState() => _NonSliverTextScreenState();
}

class _NonSliverTextScreenState extends State<NonSliverTextScreen> {
  bool _isAppBarVisible = true;
  late final ScrollController _scrollController;
  final double _appBarHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      // Scrolling down -> Hide AppBar
      if (_isAppBarVisible) {
        setState(() => _isAppBarVisible = false);
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      // Scrolling up -> Show AppBar
      if (!_isAppBarVisible) {
        setState(() => _isAppBarVisible = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final totalAppBarHeight = _appBarHeight + topPadding;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Scrollable Body (SingleChildScrollView with top padding so content isn't hidden under AppBar)
          SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              16.0,
              totalAppBarHeight + 16.0,
              16.0,
              16.0,
            ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 16.0,
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: List.generate(
                  50,
                  (index) => TextSpan(
                    text:
                        'Paragraph ${index + 1}: This is a non-sliver version using a standard SingleChildScrollView. When scrolling down, the top bar slides out of view. When scrolling up, it slides back in.\n\n',
                    style: TextStyle(
                      fontWeight: index % 5 == 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: index % 3 == 0 ? Colors.indigo : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Sliding Top AppBar / Header
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: _isAppBarVisible ? 0 : -totalAppBarHeight,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: topPadding),
              height: totalAppBarHeight,
              color: Theme.of(context).primaryColor,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RichText Reader (Non-Sliver)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // 3. Always-showing bottom buttons panel
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
