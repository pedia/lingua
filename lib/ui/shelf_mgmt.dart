import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/model.dart';
import '../g.dart';

class ShelfManagementScreen extends ConsumerStatefulWidget {
  const ShelfManagementScreen({super.key});

  @override
  ConsumerState<ShelfManagementScreen> createState() => _EditableListScreenState();
}

class _EditableListScreenState extends ConsumerState<ShelfManagementScreen> {
  // 1. Data Source
  final List<Shelf> _items = [];
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    setState(
      () => _items.addAll(ref.read(shopProvider.select((s) => s.shelves))),
    );
  }

  // Add New Item
  void _addItem(String name) {
    if (name.trim().isEmpty) return;
    setState(() {
      _items.add(Shelf(id: nextId(), name: name.trim(), items: []));
    });
    _textController.clear();
  }

  // Delete Item
  void _deleteItem(int index) {
    final deletedItem = _items[index];
    setState(() {
      _items.removeAt(index);
    });

    // Optional: Show undo snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$deletedItem deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _items.insert(index, deletedItem);
            });
          },
        ),
      ),
    );
  }

  void _renameItem(int index, String newName) {
    if (newName.trim().isEmpty) return;
    setState(() {
      _items[index] = _items[index].copyWith(name: newName.trim());
    });
    _textController.clear();
  }

  // 4. Reorder Items
  void _reorderItems(int oldIndex, int newIndex) {
    setState(() {
      // ReorderableListView adjustment for moving down
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  // Dialog to enter new item text
  void _showAddDialog() {
    _textController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Shelf'),
          content: TextField(
            controller: _textController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter shelf name'),
            onSubmitted: (value) {
              _addItem(value);
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _addItem(_textController.text);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // Dialog for Renaming an Existing Item
  void _showRenameDialog(int index) {
    _textController.text = _items[index].name;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Shelf'),
          content: TextField(
            controller: _textController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter shelf name'),
            onSubmitted: (value) {
              _renameItem(index, value);
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _renameItem(index, _textController.text);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // Allows the screen to pop normally
      onPopInvokedWithResult: (didPop, result) {
        // didPop is true if the pop navigation actually occurred
        if (didPop) {
          update();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shelf'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddDialog,
              tooltip: 'Add Shelf',
            ),
          ],
        ),
        body: _items.isEmpty
            ? const Center(child: Text('No shelf in the list. Tap + to add.'))
            : ReorderableListView.builder(
                itemCount: _items.length,
                onReorder: _reorderItems,
                itemBuilder: (context, index) {
                  final item = _items[index];

                  return ListTile(
                    // Key must also be unique across items for ReorderableListView
                    key: ValueKey(item),
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text('${item.name}, ${item.items.length}'),
                    onTap: () => _showRenameDialog(index), // Tap tile to rename
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          onPressed: () => _showRenameDialog(index),
                          tooltip: 'Rename',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.grey,
                          ),
                          onPressed: () => _deleteItem(index),
                          tooltip: 'Delete',
                        ),
                        SizedBox(width: 12),
                      ],
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddDialog,
          tooltip: 'Add Item',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// update provider
  void update() {
    ref.read(shopProvider.notifier).update(_items);
  }
}
