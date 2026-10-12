import 'package:flutter/material.dart';

class DrawerScrollExample extends StatefulWidget {
  const DrawerScrollExample({Key? key}) : super(key: key);

  @override
  State<DrawerScrollExample> createState() => _DrawerScrollExampleState();
}

class _DrawerScrollExampleState extends State<DrawerScrollExample> {
  final ScrollController _scrollController = ScrollController();

  // Mock data categories
  final Map<String, List<String>> _categories = {
    'Fruits': List.generate(30, (i) => 'Fruit Item ${i + 1}'),
    'Vegetables': List.generate(30, (i) => 'Vegetable Item ${i + 1}'),
    'Snacks': List.generate(30, (i) => 'Snack Item ${i + 1}'),
  };

  late String _selectedCategory;
  late List<String> _currentItems;

  @override
  void initState() {
    super.initState();
    _selectedCategory = 'Fruits';
    _currentItems = _categories[_selectedCategory]!;
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _currentItems = _categories[category]!;
    });

    // Close the drawer
    Navigator.of(context).pop();

    // Scroll to top after items update
    // _scrollToTop();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Category: $_selectedCategory')),
      // Drawer menu
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Select Category',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ..._categories.keys.map((category) {
              return ListTile(
                title: Text(category),
                selected: category == _selectedCategory,
                onTap: () => _selectCategory(category),
              );
            }),
          ],
        ),
      ),
      // Main scrollable list
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _currentItems.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(_currentItems[index]),
          );
        },
      ),
    );
  }
}
