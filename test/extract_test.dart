import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:lingua/epub/extract.dart';

void main() {
  String htmlString = '''
    <div>
      <p lang="en">This is paragraph text with <strong>bold</strong> and <sup>sup</sup> text.</p>
      <img src="https://example.com" alt="Banner" />
      <div>This text lives inside a div.</div>
      <ul>
        <li lang="zh">List item number one</li>
        <li>List item with an inline <img src="https://example.com" /> asset</li>
      </ul>
      <span>Trailing standalone inline text here.</span>
    </div>
    <div>
      <p>1<span>a</span><span>b</span></p>
      <p>2</p>
    </div>
    <p><img src="../images/foo.jpg" /></p>
    <p>Hello <img src="a.jpg" /> world</p>
    <p lang="zh">文字 <img src="b.jpg" /> 更多</p>
    <figure class="full breakafter ">
      <img alt=" " id="Dusttitlepage" src="images/Dusttitlepage.jpg"/>
    </figure>
  ''';

  dom.Document document = parse(htmlString);
  final lines = extract(document.body!);

  lines.forEach(print);
}
