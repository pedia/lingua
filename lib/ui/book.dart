import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';

import '../settings/setting.dart';
import 'setting.dart';
import 'voice_setting.dart';
import 'font.dart';
import '../hw.dart';
import '../g.dart';
import 'chapter_list.dart';
import '../data/model.dart';
import '../epub/epub.dart' as epub;
import '../epub/parser.dart' as epub;
import '../tts/dualtts.dart';
import '../freya.dart';
import '../data/sample.dart';
import 'gadget.dart';
import 'shelf.dart';

class ArchiveProvider extends FileProvider {
  ArchiveProvider(String base, this.files) : base = Uri(path: base);
  final Uri base;
  final Map<String, ArchiveFile> files;

  @override
  Uint8List bytes(String path) {
    debugPrint('$path => ${base.resolve(path).path}');
    final fp = base.resolve(path).path.toLowerCase();
    return files[fp]?.content ?? Uint8List.fromList([]);
  }
}

class BookFrame extends ConsumerStatefulWidget {
  const BookFrame({required this.id, super.key});
  final int id;

  @override
  ConsumerState<BookFrame> createState() => _BookFrameState();
}

class _BookFrameState extends ConsumerState<BookFrame> {
  Playback playbackState = Playback.stop;
  bool get isPlaying =>
      playbackState == Playback.pause || playbackState.isPlaying;
  final dt = DualTts();
  final roller = ScrollController();

  // @override
  // void didUpdateWidget(BookFrame oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  // }

  /// CASE: avoid using ref in initState
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;

      // ✅ Safe to use ref here
      // lang = ref.read(settingProvider.select((m) => m.stringOf('ui.lang')));
    }
  }

  /// CASE: save/restore scroll offset, include
  /// - addPostFrameCallback
  /// - ScrollController.addListener
  /// - dispose Future

  late StreamSubscription sub;
  late epub.Book book;

  @override
  void initState() {
    super.initState();

    // CASE:
    // Not work here(in initState). Move into didChangeDependencies
    // lang = ref.watch(settingProvider.select((m) => m.stringOf('ui.lang')));

    sub = dt.stream.listen(_onTts);

    // Set drawer opened at first time frame appear
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  epub.Chapter get chapter {
    final s = ref.read(isp(widget.id));
    return book.chapters[s.read.ci];
  }

  @override
  void dispose() {
    Future(() {
      /// Save progress with newest scroll offset
      // _itemsProvider.update(widget.id, progress: _progress);
      // ref.read(readpp).$1
    });

    sub.cancel();

    roller.dispose();

    super.dispose();
  }

  void _onTts((Playback, int) m) {
    if (!mounted) {
      return;
    }

    // final doc = ProviderScope.containerOf(context).read(docp);
    // debugPrint('demo $doc');
    // ref.read(docp);

    debugPrint('got dts notify $m');

    // next chapter
    if (playbackState.isPlaying &&
        m.$1 == Playback.stop &&
        m.$2 + 1 == lines.length) {
      print('speak, try next chapter ${lines.length}');
      // if (_progress.chapterIndex + 1 < widget.book.chapters.length) {
      //   setState(
      //     () => _progress = Progress(chapterIndex: _progress.chapterIndex + 1),
      //   );

      /// not set `playbackState`
      return;
    }

    if (m.$1 != playbackState) {
      setState(() => playbackState = m.$1);
    }
  }

  List<epub.Chunk> get lines {
    final lang = ref.read(settingProvider.select((m) => m.stringOf('ui.lang')));
    final chi = ref.read(isp(widget.id)).read.ci;
    return book.chapters[chi].chunks
        .where((line) => lang == '' || line.lang == lang)
        .toList();
  }

  Future applyVoice(BuildContext context) {
    final m = ProviderScope.containerOf(context).read(settingProvider);

    // debugPrint('in apply got setting: $m');
    // print(m.has('tts.en'));

    final vs = [
      if (m.has('tts.en')) EngineSetting.from('en', m.objectOf('tts.en')),
      if (m.has('tts.zh')) EngineSetting.from('zh', m.objectOf('tts.zh')),
    ];
    return dt.apply(vs).then((x) => debugPrint('dualtts inited ${vs.length}'));
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    ref.listen(isp(widget.id), (previous, next) {
      if (next.read.li != previous?.read.li) {
        ref.read(linep.notifier).updateActive(next.read.li);
      }
    });

    ref.listen(linep, (prev, next) {
      if (next != null && next != prev) {
        ref.read(isp(widget.id).notifier).updateRead(lineIndex: next);
      }
    });

    final ab = ref.watch(bookProvider(widget.id));
    return AsyncValueX(ab).when(
      data: (book) {
        if (book == null) {
          return ErrScreen('Unable to open item:${widget.id}');
        }
        this.book = book;
        return builds(context, book);
      },
      loading: () => const Center(), // TODO: better solution
      error: (err, stackTrace) {
        print(stackTrace.toString().substring(0, 1000));
        return ErrScreen('Unable to open it\n$err');
      },
    );
  }

  Widget builds(BuildContext context, epub.Book book) {
    final ci = ref.watch(isp(widget.id).select((o) => o.read.ci));
    final ch = book.chapters[ci];

    print('book build with $ci ${ch.title}');

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(ch.title),
        actions: [
          IconButton(
            tooltip: switch (playbackState) {
              Playback.playing => 'Stop',
              _ => 'Play',
            },
            icon: Icon(switch (playbackState) {
              Playback.playing => Icons.stop_rounded,
              _ => Icons.play_arrow_rounded,
            }),
            onPressed: () async {
              if (playbackState.isPlaying) {
                dt.stop();
              } else {
                if (!dt.inited) {
                  await applyVoice(context);
                }

                dt.load(lines);
                dt.play();
              }
            },
          ),

          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (String v) async {
              final f = Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => switch (v) {
                    'font' => FontFrame(),
                    'tts-setting' => EngineSettingPage.from(context),
                    'setting' || _ => SettingFrame(),
                  },
                ),
              );

              f.then((_) {
                // CASE: get provider in context
                //   final m = ProviderScope.containerOf(
                //     context,
                //   ).read(settingProvider);
                //   debugPrint(m.toString());
                if (mounted) {
                  applyVoice(context);
                }
              });
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(value: 'setting', child: Text('Setting')),
              PopupMenuItem(value: 'search', child: Text('Search')),
              PopupMenuItem(value: 'replace', child: Text('Replace')),
              PopupMenuItem(value: 'tts-setting', child: Text('TTS Setting')),
              PopupMenuItem(value: 'font', child: Text('Font Demo')),
            ],
            child: Icon(Icons.more_vert, size: 36),
          ),
        ],
      ),
      drawer: Drawer(width: 280, child: ChapterList(widget.id, book)),
      body: SelectableRegion(
        selectionControls: materialTextSelectionHandleControls,
        contextMenuBuilder: selectToolbar,
        child: SafeArea(
          child: HtmlWidget(
            html: ch.content,
            mode: Mode.list,
            provider: ArchiveProvider(ch.href, book.files),
          ),
        ),
      ),
    );
  }

  void gotoNextChapter() {
    // if (_progress.chapterIndex + 1 < widget.book.chapters.length) {
    //   setState(
    //     () => _progress = _progress.copyWith(
    //       chapterIndex: _progress.chapterIndex + 1,
    //       lineIndex: 0,
    //     ),
    //   );
    //   ref.read(itemsProvider.notifier).update(widget.id, progress: _progress);
    // } else {
    //   debugPrint('book end');
    // }
  }

  // void scrollToNextPage(TapUpDetails d) {
  //   if (!roller.hasClients) return;

  //   final double viewportHeight = roller.position.viewportDimension;
  //   final double target = (roller.offset + viewportHeight).clamp(
  //     0.0,
  //     roller.position.maxScrollExtent,
  //   );

  //   if (roller.offset == roller.position.maxScrollExtent) {
  //     debugPrint('next chapter');
  //     gotoNextChapter();
  //     return;
  //   }

  //   if (ref.watch(
  //     settingProvider.select((m) => m.flag('ui.next-page-animation')),
  //   )) {
  //     roller.animateTo(
  //       target,
  //       duration: const Duration(milliseconds: 100),
  //       curve: Curves.easeOut,
  //     );
  //   } else {
  //     roller.jumpTo(target);
  //   }
  // }

  Widget playbackPanel(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous sentence',
              onPressed: () => dt.skip(-1),
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton.filled(
              tooltip: switch (playbackState) {
                Playback.playing => 'Pause',
                Playback.pause => 'Play',
                _ => '_',
              },
              onPressed: dt.toggle,
              icon: Icon(switch (playbackState) {
                Playback.pause => Icons.play_arrow,
                Playback.stop => Icons.stop,
                _ => Icons.pause,
              }),
            ),
            IconButton(
              tooltip: 'Next sentence',
              onPressed: () => dt.skip(1),
              icon: const Icon(Icons.skip_next),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ref.read(
                          settingProvider.select((m) => m.stringOf('ui.lang')),
                        ) ==
                        'zh'
                    ? 'TTS 中文'
                    : 'TTS EN',
                textAlign: TextAlign.end,
              ),
            ),
            IconButton(
              tooltip: 'Translate chapter',
              onPressed: () {
                // _translated.remove(_chapter);
                // _translateChapter(_chapter);
              },
              icon: const Icon(Icons.translate),
            ),
          ],
        ),
      ),
    );
  }

  Widget readerPanel(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Chapters',
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            IconButton.filled(
              tooltip: switch (playbackState) {
                Playback.playing => 'Pause',
                Playback.pause => 'Play',
                _ => '_',
              },
              onPressed: dt.toggle,
              icon: Icon(switch (playbackState) {
                Playback.pause => Icons.play_arrow,
                Playback.stop => Icons.stop,
                _ => Icons.pause,
              }),
            ),
            IconButton(
              tooltip: 'Next sentence',
              onPressed: () => dt.skip(1),
              icon: const Icon(Icons.skip_next),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ref.read(
                          settingProvider.select((m) => m.stringOf('ui.lang')),
                        ) ==
                        'zh'
                    ? 'TTS 中文'
                    : 'TTS EN',
                textAlign: TextAlign.end,
              ),
            ),
            IconButton(
              tooltip: 'Translate chapter',
              onPressed: () {
                // _translated.remove(_chapter);
                // _translateChapter(_chapter);
              },
              icon: const Icon(Icons.translate),
            ),
          ],
        ),
      ),
    );
  }

  AdaptiveTextSelectionToolbar selectToolbar(
    BuildContext context,
    SelectableRegionState editableTextState,
  ) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        ...editableTextState.contextMenuButtonItems, // Copy, Select all, …
        ContextMenuButtonItem(
          label: 'Highlight',
          onPressed: () {
            final value = editableTextState.textEditingValue;
            final sel = value.selection;
            if (!sel.isValid || sel.isCollapsed) return;
            final selected = value.text.substring(sel.start, sel.end);
            debugPrint('Highlight: $selected');
            ContextMenuController.removeAny();
          },
        ),
      ],
    );
  }
}

final bookProvider = FutureProvider.autoDispose.family<epub.Book?, int>((
  ref,
  id,
) async {
  final m = gbox.get('item:$id');
  if (m == null) throw Exception('item:$id not exist');

  epub.Book? book;
  final item = Item.fromJson((m as Map).cast<String, dynamic>());
  if (id == 5) {
    book = freya;
  } else if (id == 6) {
    book = sample();
  } else if (item.type == ItemType.file) {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));

    final file = File(p.join(booksDir.path, item.path));
    if (!file.existsSync()) {
      return null;
    }
    book = const epub.EpubParser().parseBytes(await file.readAsBytes());
  } else if (item.type == ItemType.assets) {
    final d = await rootBundle.load(item.path);
    book = epub.EpubParser().parseBytes(d.buffer.asInt8List());
  }

  if (book == null) {
    throw Exception('book:${item.type}/${item.path} not exist');
  }

  // // book cover image thumbnail
  if (gbox.get('icon:$id') == null) {
    final cb = book.coverBytes;
    if (cb != null) {
      gbox.put('icon:$id', iconify(cb));
    }
  }

  if (book.author.isNotEmpty && item.author == null) {
    gbox.put(
      'item:$id',
      item.copyWith(author: book.author, name: book.title).toJson(),
    );
  }

  return book;
});

class Progress {
  const Progress({this.ci = 0, this.li = 0, this.offset});
  final int ci;
  final int li;
  final double? offset;

  factory Progress.fromJson(Map<String, dynamic> json) => Progress(
    ci: json['ci'] ?? 0,
    li: json['li'] ?? 0,
    offset: json['offset'],
  );

  Map<String, dynamic> toJson() => {"ci": ci, "li": li, "offset": ?offset};

  Progress copyWith({int? ci, int? li, double? offset}) => Progress(
    ci: ci ?? this.ci,
    li: li ?? this.li,
    offset: offset ?? this.offset,
  );
}

//
class ItemState {
  ItemState({
    required this.id,
    this.read = const Progress(),
    this.speak = const Progress(),
  });
  final int id;
  final Progress read;
  final Progress speak;

  ItemState copyWith({int? id, Progress? read, Progress? speak}) => ItemState(
    id: id ?? this.id,
    read: read ?? this.read,
    speak: speak ?? this.speak,
  );

  factory ItemState.fromJson(Map<String, dynamic> json) => ItemState(
    id: json['id'],
    read: Progress.fromJson(json['read'].cast<String, dynamic>()),
    speak: Progress.fromJson(json['speak'].cast<String, dynamic>()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'read': read.toJson(),
    'speak': speak.toJson(),
  };
}

// AsyncNotifier family tracking just progress for a book ID
class ItemStateNotifier extends FamilyNotifier<ItemState, int> {
  @override
  ItemState build(int id) {
    final m = gbox.get('item-state:$id');
    if (m == null) {
      return ItemState(id: id);
    }
    return ItemState.fromJson(m.cast<String, dynamic>());
  }

  void updateRead({int? chapterIndex, int? lineIndex}) async {
    final nr = state.read.copyWith(ci: chapterIndex, li: lineIndex);
    state = state.copyWith(read: nr);
    gbox.put('item-state:${state.id}', state.toJson());
  }
}

/// short for ItemStateProvider
final isp = NotifierProvider.family<ItemStateNotifier, ItemState, int>(
  ItemStateNotifier.new,
  name: 'ItemState',
);
