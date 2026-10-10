import 'package:flutter/material.dart';
import '../data/model.dart';

class BookEditScreen extends StatefulWidget {
  final Item item;

  const BookEditScreen({super.key, required this.item});

  @override
  State<BookEditScreen> createState() => _BookEditScreenState();
}

class _BookEditScreenState extends State<BookEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late Item _item;
  late String? _selectedShelf;

  // Available shelves options for the dropdown
  final List<String> _shelves = [
    'Want to Read',
    'Currently Reading',
    'Finished',
    'Favorites',
  ];

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  void _saveBook() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Return the updated data back to the previous screen
      Navigator.pop(context, _item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Book'),
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
              // Title Field
              TextFormField(
                initialValue: _item.name,
                decoration: const InputDecoration(
                  labelText: 'Title',
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
              DropdownButtonFormField<String>(
                value: _selectedShelf,
                decoration: const InputDecoration(
                  labelText: 'Shelf',
                  border: OutlineInputBorder(),
                ),
                items: _shelves.map((String shelf) {
                  return DropdownMenuItem<String>(
                    value: shelf,
                    child: Text(shelf),
                  );
                }).toList(),
                onChanged: (String? newValue) {
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
