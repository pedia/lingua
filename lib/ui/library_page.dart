import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/library_store.dart';
import '../epub/parser.dart';
import '../settings/app_settings.dart';
import '../translate/translation_service.dart';
import 'reader.dart';
import 'settings_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.store,
    required this.settings,
    required this.translation,
  });

  final Store store;
  final AppSettings settings;
  final TranslationService translation;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool _busy = false;
  String? _error;

  Future<void> _import() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub'],
      );
      final path = result?.files.single.path;
      if (path == null) {
        return;
      }
      final parsed = const EpubParser().parseBytes(
        File(path).readAsBytesSync(),
      );
      await widget.store.importEpub(
        sourcePath: path,
        title: parsed.title,
        author: parsed.author,
      );
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _open(Item book) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => Center()));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.store.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsPage(
                    settings: widget.settings,
                    translation: widget.translation,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: books.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Import an EPUB to start reading, listening, and translating English and Chinese.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: books.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(book.title),
                        subtitle: Text(
                          '${book.author} · ch ${book.lastChapter + 1}',
                        ),
                        onTap: () => _open(book),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await widget.store.remove(book);
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _import,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_busy ? 'Importing…' : 'Import'),
      ),
    );
  }
}
