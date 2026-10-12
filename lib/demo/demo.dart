import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../hw.dart';
import '../data/sample.dart';

class DemoFrame extends StatefulWidget {
  const DemoFrame({super.key});

  @override
  State<DemoFrame> createState() => _DemoFrameState();
}

class _DemoFrameState extends State<DemoFrame> {
  Mode _mode = Mode.list;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    // _timer = Timer.periodic(const Duration(seconds: 1), (timer) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final small = 'The quick brown fox jumps over the lazy dog.';
    final long = '''The quick brown fox jumps over the "lazy" 'dog'?,
「私は、ガラスを食べられますか？」――いいえ！それは私を傷つけません。
『我能吞下玻璃嗎？』——不，這傷不到我的身體！
“나는유리를먹을수있습니까?”…… 아니요! 그래도 아프지 않아요.
“选择关复简”体、中文，年度报告。''';

    final h =
        '''<body>
  <div>Standalone Div</div>
  <div>We will talk:<p>Quick Brown Fox</p> - Jerry</div>
  <h1>H1 Quick Brown Fox</h1>
  <h2>H2 Quick Brown Fox</h2>
  <H3>H3 Quick Brown Fox</H3>
  <p><a href="#long">goto <i>italic</i> long</a></p>
  <p><a href="#long">goto long</a></p>
  <p>$small</p>
  <p>inline image<img src="note" width="64" height="64" alt="alt"></p>
  <p><img src="note" width="400" height="400" alt="alt"></p>
  <p id="long">$long</p>
  <p><span>- End -</span></p>
</body>''';

    return Scaffold(
      appBar: AppBar(
        title: Text('HtmlWidget Demo(Debug)'),
        actions: [
          IconButton(
            icon: Icon(Icons.list, color: Theme.of(context).iconTheme.color),
            onPressed: () => setState(() => _mode = Mode.list),
          ),
          IconButton(
            icon: Icon(
              Icons.text_format,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () => setState(() => _mode = Mode.rich),
          ),
        ],
      ),
      body: SelectableRegion(
        contextMenuBuilder: selectToolbar,
        selectionControls: materialTextSelectionHandleControls,
        child: HtmlWidget(html: h, mode: _mode),
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
