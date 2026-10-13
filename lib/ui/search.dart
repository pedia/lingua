import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

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
    _searchController.addListener(_filterSearchResults);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filtering logic
  void _filterSearchResults() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _allItems;
      } else {
        _filteredItems = _allItems
            .where((item) => item.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Input Field
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search',
            hintText: 'Type to search items...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // Search Result List
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
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        title: Text(item),
                        leading: const Icon(Icons.label_outline),
                        onTap: () {
                          // Handle item tap action
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Selected: $item')),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
