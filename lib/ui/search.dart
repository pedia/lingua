import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../epub/epub.dart' as epub;

class SearchView extends ConsumerStatefulWidget {
  const SearchView(this.book, {super.key});
  final epub.Book book;

  @override
  ConsumerState<SearchView> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchView> {
  // Controller to track text input
  final TextEditingController _searchController = TextEditingController();

  // Full list of mock data
  final List<String> _allItems = [
    'Apple',
    'Banana',
    'Cherry',
    'Date',
    'Elderberry',
    'Fig',
    'Grape',
    'Honeydew',
    'Kiwi',
    'Lemon',
    'Mango',
    'Nectarine',
    'Orange',
    'Papaya',
    'Raspberry',
    'Strawberry',
    'Watermelon',
  ];

  // List holding the currently filtered results
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    // Initialize filtered list with all items
    _filteredItems = _allItems;
    // Listen for changes in the text field
    _searchController.addListener(_search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    String q = _searchController.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = _allItems;
      } else {
        _filteredItems = _allItems
            .where((item) => item.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CupertinoSearchTextField(
          controller: _searchController,
          placeholder: 'Search...',
          style: TextStyle(fontFamily: '.osdefault'),
        ),
        const SizedBox(height: 16.0),
        Expanded(
          child: _filteredItems.isEmpty
              ? const Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    return ListTile(
                      title: Text(item),
                      leading: const Icon(Icons.label_outline),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Selected: $item')),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
