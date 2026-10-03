# Bilingua Reader

Bilingual, epub reader and translator


# UI

## Home
epub list [lang]
...
...
movie list [count of subtitles]
...
...

## EPUB Reader
```txt
[menu]  [chapter title]       [en|zh|dual][play] [...]
list of text lines

more function
  Search
  Replace globally
    src(s) -> dest
  TTS Engine
    Stop
    Bottom control panel?
  
  Selectable
  Tap item entering inline edit mode
    How to save?
  Dictionary
```

## Key Readability Tips (Especially for Chinese)

|Property|Recommended Value|Reason|
|---|---|---|
|height | 1.5 ~ 1.65(body) | Chinese needs more vertical space|
|fontSize | 15–16 (body), 14 min | Too small hurts CJK readability|
|fontWeight |w400 / w500 (body) | Avoid pure bold on long text|
|letterSpacing |0 ~ 0.3|Slight positive helps English|
|Line length |≤ 35–40 Chinese characters|Better reading comfort|

Start with GoogleFonts.notoSansTcTextTheme() + height: 1.55.


## app icon prompt
Generate an app icon shows a cartoon bilingual white boy walking up stairs from the bottom right to the top left. Some English, Spanish, Japanese text on Stairs,
Limited text count; pure white background. round corner

```bash
adb devices
adb -s 192.168.31.105:38761 shell cat /system/etc/fonts.xml
```


## os native font
- Galaxy
SECCJK-Regular.ttc # OneUI
NotoSerifCJK-Regular.ttc

#
How to implement prev/next page read mode in a flutter EPUB reader?
- Tap at the bottom of screen to go to next page,
- scroll up/down
- text is selectable and show a menu
Explain the concept first

git@github.com:Ohgyuchan/flutter_epub_viewer_kit.git

- low quality
epubx
git@github.com:ScerIO/packages.flutter.git
git@github.com:Mamasodikov/cosmos_epub.git
git@github.com:chenkaiHere/flutter_book_reader.git
  only pure text

# TODO:
tts read from dom, Same top blocks
sliver list lib, multiple shelf
sliver list hw
tts progress
read progress


# legacy code

drawer: Drawer(
        child: Scrollbar(
          child: ListView.builder(
            primary: true,
            key: PageStorageKey<String>(widget.book.title),
            itemCount: widget.book.chapters.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                  child: ListTile(
                    title: Text(widget.book.title),
                    subtitle: Text(widget.book.author),
                  ),
                );
              }
              final i = index - 1;
              return ListTile(
                selected: i == progress.chapterIndex,
                title: Text(widget.book.chapters[i].title),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => progress = Progress(chapterIndex: i));
                },
              );
            },
          ),
        ),
      )


// CASE: get provider in context
//   final m = ProviderScope.containerOf(
//     context,
//   ).read(settingProvider);

// PopupMenuButton<String>(
//   tooltip: 'Display language',
//   initialValue: lang,
//   onSelected: (String val) {
//     ref.watch(settingProvider.notifier).put('ui.lang', val);
//     setState(() => lang = val);
//     // TODO: reset index
//     // roller.ensureVisible
//   },
//   itemBuilder: (BuildContext context) => const [
//     PopupMenuItem(value: 'en', child: Text('Only English')),
//     PopupMenuItem(value: 'zh', child: Text('Only Chinese')),
//     PopupMenuItem(value: '', child: Text('All')),
//   ],
//   child: Text(switch (lang) {
//     'en' => 'EN',
//     'zh' => 'ZH',
//     '' || _ => 'ALL',
//   }),
// ),


# state

-    tts:
   watch: tts-line?
    read: lines
      up: tts-line

- reader:
   watch: cch, read-line, tts.state
    read: cch, cbook(ArchiveProvider)
   // up: read-line

-    hw: [bookProvider]
   read: Doc[Blocks] + ArchiveProvider, lineIndex
  watch: lineIndex
     up: read-line

- chs list:
     watch: cch=?book,  cbook
      read: chs
        up: cch
