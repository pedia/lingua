import 'package:flutter/material.dart';

class LongTextScreen extends StatelessWidget {
  const LongTextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Hiding/Showing AppBar on scroll
          SliverAppBar(
            title: const Text('RichText Reader'),
            floating: true,
            snap: true,
            pinned: false,
            elevation: 2,
          ),

          // 2. Very long RichText body inside a sliver
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                          'Paragraph ${index + 1}: This is a very long block of rich text designed to demonstrate scrolling behavior in Flutter. When you scroll down, the AppBar disappears. The moment you scroll up even slightly, it reappears instantly.\n\n',
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
