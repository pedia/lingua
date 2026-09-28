import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class PageFrame extends StatefulWidget {
  const PageFrame({super.key});

  @override
  State<PageFrame> createState() => _PageFrameState();
}

class _PageFrameState extends State<PageFrame> {
  final roller = ScrollController();

  @override
  void initState() {
    super.initState();
    _pkeys.clear();

    roller.addListener(_onScroll);
  }

  @override
  void dispose() {
    roller.dispose();
    super.dispose();
  }

  void _handlePress() {
    debugPrint('got press');
  }

  final Map<String, GlobalKey> _pkeys = {};
  void _onScroll() {
    // print(
    //   'onScroll ${roller.offset.toStringAsFixed(2)}, keys: ${_pkeys.length}',
    // );

    final RenderBox? scrollBox = context.findRenderObject() as RenderBox?;
    if (scrollBox == null) return;

    String? firstVisibleId;
    double closestTop = double.infinity;

    for (final entry in _pkeys.entries) {
      final key = entry.value;
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;

      final position = box.localToGlobal(Offset.zero, ancestor: scrollBox);
      final top = position.dy;

      if (top >= -box.size.height && top < closestTop) {
        closestTop = top;
        firstVisibleId = entry.key;
      }
    }

    if (firstVisibleId != null) {
      print(
        'onScroll ${roller.offset.toStringAsFixed(2)}, keys: ${_pkeys.length}, First visible block: $firstVisibleId',
      );
    }
  }

  final foo = GlobalKey(debugLabel: "foo");

  @override
  Widget build(BuildContext context) {
    final textsmall = 'The quick brown fox jumps over the lazy dog.';
    final longtext = '''The quick brown fox jumps over the "lazy" 'dog'?,
「私は、ガラスを食べられますか？」――いいえ！それは私を傷つけません。
『我能吞下玻璃嗎？』——不，這傷不到我的身體！
“나는유리를먹을수있습니까?”…… 아니요! 그래도 아프지 않아요.
“选择关复简”体、中文，年度报告。''';

    return SelectionArea(
      contextMenuBuilder: selectToolbar,
      selectionControls: materialTextSelectionControls,
      child: Scaffold(
        appBar: AppBar(title: Text('RichText(Debug)')),
        body: SingleChildScrollView(
          controller: roller,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(8),
            child: Text.rich(
              style: Theme.of(context).textTheme.displaySmall,
              TextSpan(
                mouseCursor: SystemMouseCursors.contextMenu,
                children: [
                  TextSpan(
                    text: 'Parent text followed ',
                    children: [
                      TextSpan(
                        text: 'red',
                        style: TextStyle(color: Colors.red),
                      ),
                      TextSpan(text: ' and plain.\n'),
                    ],
                  ),
                  TextSpan(
                    text: 'Tap Goto foo',
                    style: const TextStyle(
                      color: Colors.green,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.wavy,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        await Scrollable.ensureVisible(foo.currentContext!);
                      },
                    mouseCursor: SystemMouseCursors.click,
                  ),
                  TextSpan(text: '\n'),
                  TextSpan(
                    text: 'Longtap Goto foo',
                    style: const TextStyle(
                      color: Colors.red,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.wavy,
                    ),
                    recognizer: LongPressGestureRecognizer()
                      ..onLongPress = () async {
                        await Scrollable.ensureVisible(foo.currentContext!);
                      },
                    mouseCursor: SystemMouseCursors.click,
                  ),
                  WidgetSpan(child: Text('Raw text')),
                  WidgetSpan(
                    child: Container(key: null, child: Text('in Container')),
                  ),
                  TextSpan(text: 'followed line return'),
                  TextSpan(text: '\n'),
                  TextSpan(text: longtext),
                  TextSpan(text: '\n'),
                  TextSpan(text: textsmall),
                  WidgetSpan(
                    child: Icon(Icons.abc, size: 36),
                    baseline: TextBaseline.ideographic,
                  ),
                  TextSpan(text: '\n'),
                  WidgetSpan(
                    child: Icon(Icons.abc, size: 128),
                    baseline: TextBaseline.ideographic,
                  ),
                  WidgetSpan(child: Text(textsmall, key: null)),
                  TextSpan(
                    text: 'Can you ',
                    style: const TextStyle(color: Colors.black),
                    children: [
                      TextSpan(
                        text: 'find the',
                        style: const TextStyle(
                          color: Colors.green,
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.wavy,
                        ),
                        recognizer: LongPressGestureRecognizer()
                          ..onLongPress = _handlePress,
                        mouseCursor: SystemMouseCursors.precise,
                      ),
                      const TextSpan(text: ' secret?'),
                    ],
                  ),
                  TextSpan(text: '\n'),
                  WidgetSpan(child: Text('At end with key(foo)', key: foo)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  AdaptiveTextSelectionToolbar selectToolbar(
    BuildContext context,
    SelectableRegionState state,
  ) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        ...state.contextMenuButtonItems, // Copy, Select all, …
        ContextMenuButtonItem(
          label: 'Highlight',
          onPressed: () {
            final value = state.textEditingValue;
            final sel = value.selection;
            if (!sel.isValid || sel.isCollapsed) return;
            final selected = value.text.substring(sel.start, sel.end);
            debugPrint('Highlight: $selected ${value.text}');
            ContextMenuController.removeAny();
          },
        ),
      ],
    );
  }
}

/// inline image hight = font size
/// block image fitWidth
/// parent has key, key to paragraph index
/// selectable, select all
/// - highlight
