import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/model.dart';
import '../epub/epub.dart' as epub;
import 'book.dart';
import '../imap.dart';
import '../g.dart';

class BookEditScreen extends ConsumerStatefulWidget {
  final int id;

  const BookEditScreen({super.key, required this.id});

  @override
  ConsumerState<BookEditScreen> createState() => _BookEditScreenState();
}

class _BookEditScreenState extends ConsumerState<BookEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late Item _item;
  late int _selectedShelf;
  epub.Book? _book;

  @override
  void initState() {
    super.initState();

    _selectedShelf = 0;
    _item = Item.fromJson(
      gbox.get('item:${widget.id}').cast<String, dynamic>(),
    );

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

      gbox.put('item:${_item.id}', _item.toJson());

      if (_selectedShelf != 0) {}

      Navigator.pop(context, _item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Book ${widget.id}'),
        actions: [
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
                    setState(() {
                      _selectedShelf = newValue;
                    });
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
            ],
          ),
        ),
      ),
    );
  }
}
