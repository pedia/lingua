import 'package:flutter/material.dart';
import 'fix.dart';

class FixitEdit extends StatefulWidget {
  const FixitEdit({super.key, this.initialItems = const [], this.onChanged});

  final List<Fixit> initialItems;
  final ValueChanged<List<Fixit>>? onChanged;

  @override
  State<FixitEdit> createState() => _FixitEditState();
}

class _FixitEditState extends State<FixitEdit> {
  late final List<Fixit> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Fixit>.of(widget.initialItems);
  }

  void _notifyChanged() {
    widget.onChanged?.call(List<Fixit>.unmodifiable(_items));
  }

  Future<void> _showItemDialog({int? index}) async {
    final isEditing = index != null;
    final existing = isEditing ? _items[index] : null;

    final srcController = TextEditingController(text: existing?.src ?? '');
    final destController = TextEditingController(text: existing?.dest ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Fixit>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Fixit' : 'Add Fixit'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: srcController,
                  decoration: const InputDecoration(
                    labelText: 'Source (src)',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Source is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: destController,
                  decoration: const InputDecoration(
                    labelText: 'Destination (dest)',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Destination is required';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop(
                        Fixit(
                          srcController.text.trim(),
                          destController.text.trim(),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(
                    Fixit(
                      srcController.text.trim(),
                      destController.text.trim(),
                    ),
                  );
                }
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );

    // srcController.dispose();
    // destController.dispose();

    if (result != null) {
      setState(() {
        if (isEditing) {
          _items[index] = result;
        } else {
          _items.add(result);
        }
      });
      _notifyChanged();
    }
  }

  void _removeItem(int index) {
    final removedItem = _items[index];

    setState(() {
      _items.removeAt(index);
    });
    _notifyChanged();

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed "${removedItem.src} → ${removedItem.dest}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              setState(() {
                _items.insert(index, removedItem);
              });
              _notifyChanged();
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rules')),
      body: _items.isEmpty
          ? const Center(
              child: Text(
                'No items yet.\nTap + to add one.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Dismissible(
                  key: ObjectKey(item),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                  onDismissed: (_) => _removeItem(index),
                  child: ListTile(
                    title: Text(item.src),
                    subtitle: Text(item.dest),
                    leading: const Icon(Icons.swap_horiz),
                    onTap: () => _showItemDialog(index: index),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit',
                          onPressed: () => _showItemDialog(index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                          onPressed: () => _removeItem(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemDialog(),
        tooltip: 'Add Fixit',
        child: const Icon(Icons.add),
      ),
    );
  }
}
