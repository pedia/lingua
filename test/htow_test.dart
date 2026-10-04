import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';

import 'package:lingua/hw.dart';

void main() {
  testWidgets('html2widget', (WidgetTester tester) async {
    final html = '''<div class="calibre3">
</div>
<p>foo</p>
<p class="foo">fake news<img height="100"></p>
''';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HtmlWidget(html: html, mode: Mode.list),
        ),
      ),
    );
    final state = tester.state(find.byType(HtmlWidget));

    final spand = state.trans(doc.querySelector('div')!) as TextSpan;
    expect(spand, isA<TextSpan>());
    expect(spand.text, ' ');
    expect(spand.children, isNull);

    final spanp = state.trans(doc.querySelector('p')!) as TextSpan;
    expect(spanp, isA<TextSpan>());
    expect(spanp.text, 'foo');
    expect(spanp.children, isNull);

    final spanf = state.trans(doc.querySelector('p.foo')!) as TextSpan;
    expect(spanf, isA<TextSpan>());
    expect(spanf.text, 'fake news');
    expect(spanf.children?.length, 1);

    // expect(((span as WidgetSpan).child as Container).child, isA<RichText>());
    // await tester.pump();

    // final parentFinder = find.byType(Column);

    // final firstTextFinder = find
    //     .descendant(of: parentFinder, matching: find.byType(Text))
    //     .first;

    // // 4. Verify it exists and has the expected properties
    // expect(firstTextFinder, findsOneWidget);

    // // Optional: Verify the text content of that specific first child
    // expect(tester.widget<Text>(firstTextFinder).data, 'I am the first child');
  });
}
