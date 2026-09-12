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


