import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/model.dart';
import '../epub/epub.dart' as epub;
import 'book.dart';
import '../imap.dart';

class ItemEditScreen extends ConsumerStatefulWidget {
  final int id;

  const ItemEditScreen({super.key, required this.id});

  @override
  ConsumerState<ItemEditScreen> createState() => _BookEditScreenState();
}

class _BookEditScreenState extends ConsumerState<ItemEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late Item _item;
  late int _selectedShelf;
  late int _origin;
  epub.Book? _book;

  @override
  void initState() {
    super.initState();

    _item = Item.fromBox(widget.id);
    _origin = ref.read(shopProvider).find(_item.path);
    _selectedShelf = _origin;

    _item.open().then((book) {
      setState(() {
        _book = book;
        _item = _item.apply(_book!);
      });
    });
  }

  void _saveBook() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      ref.read(shopProvider.notifier).saveItem(_item);

      if (_selectedShelf != _origin) {
        ref.read(shopProvider.notifier).moveItemTo(_item.id, _selectedShelf);
      }

      Navigator.pop(context, _item);
    }
  }

  Future<void> showDeleteConfirmationDialog(
    BuildContext context,
    String bookTitle,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Book?'),
          content: Text(
            'Are you sure you want to delete "$bookTitle"? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    // Verification step
    if (confirm == true && context.mounted) {
      // Perform the actual delete operation here
      _deleteBook();
    }
  }

  void _deleteBook() {
    _item.remove();

    ref.read(shopProvider.notifier).remove(_item.id);

    Navigator.pop(context, _item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => showDeleteConfirmationDialog(context, _item.name!),
            tooltip: 'Delete',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveBook,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_book?.coverBytes != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Image.memory(_book!.coverBytes!, fit: BoxFit.fitWidth),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                key: UniqueKey(),
                initialValue: _item.name,
                maxLines: null, // softWrap
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a book title';
                  }
                  return null;
                },
                onSaved: (value) => _item = _item.copyWith(name: value!.trim()),
              ),
              const SizedBox(height: 16),

              // Author Field
              TextFormField(
                key: UniqueKey(),
                initialValue: _item.author,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the author\'s name';
                  }
                  return null;
                },
                onSaved: (value) =>
                    _item = _item.copyWith(author: value!.trim()),
              ),
              const SizedBox(height: 16),

              // Shelf Dropdown Choice
              DropdownButtonFormField<int>(
                key: UniqueKey(),
                initialValue: _selectedShelf,
                decoration: const InputDecoration(
                  labelText: 'Shelf',
                  border: OutlineInputBorder(),
                ),
                items: ref
                    .watch(shopProvider.select((s) => s.shelves))
                    .imap(
                      (i, shelf) => DropdownMenuItem<int>(
                        key: UniqueKey(),
                        value: i,
                        child: Text(shelf.name),
                      ),
                    )
                    .toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    _selectedShelf = newValue;
                  }
                },
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                key: UniqueKey(),
                initialValue: _item.description,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                onSaved: (value) =>
                    _item = _item.copyWith(description: value!.trim()),
              ),
              const SizedBox(height: 16),
              // Review Field
              TextFormField(
                key: UniqueKey(),
                initialValue: _item.review,
                decoration: const InputDecoration(
                  labelText: 'Review',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                onSaved: (value) =>
                    _item = _item.copyWith(review: value!.trim()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: UniqueKey(),
                readOnly: true,
                initialValue: _item.path,
                maxLines: null, // softWrap
                decoration: const InputDecoration(
                  labelText: 'Path',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: UniqueKey(),
                readOnly: true,
                initialValue: _item.ctime.toString(),
                maxLines: null, // softWrap
                decoration: const InputDecoration(
                  labelText: 'Add Date',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
