import 'dart:io';
import 'dart:convert';
import 'package:html/parser.dart' show parse;
import '../lib/epub/epub.dart';
import '../lib/epub/parser.dart';

final complex = '''
<p class="calibre8"><span class="calibre11">尽管美国的禁酒令在20世纪20年
代被废除，但自行车还是促成了美国人酒精消费行为的持久性改变——美国的一些县至今仍然
流行“干型酒”。
        <sup class="calibre22"><a href="part0039.html#footnote-39-65" type="noteref" class="calibre"> <img alt="“干型酒”的含糖量在4g/L以下。美国人一般更偏爱糖分更多的“半干型酒”。" class="epub-footnote" src="../images/00001.png" zy-footnote="“干型酒”的含糖量在4g/L以下。美国人一般更偏爱糖分更多的“半干型酒”。"/></a></sup></span></p>

<aside id="footnote-39-65" type="footnote" class="calibre"><ol class="duokan-footnote-content"><li class="duokan-footnote-item">“干型酒”的含糖量在4g/L以下。美国人一般更偏爱糖分更多的“半干型酒”。</li>
</ol>
</aside>

<p>这纯属<b>男性</b>所为</p>

<p>敦请奥尔良公爵登基。<a class="footnote" href="#note485n"><img alt="" height="24" src="../../5eb9a36f724d92b4225a03c21d3399inr0.png" width="24"/></a>在72小时的激战之后，七月革命结束了。后来，这72小时在法国历史上以“光荣三日”著称。三天的战斗导致800名平民和200名士兵死亡，4000名平民和800名士兵负伤。革命期间，起义者在巴黎的大街小巷中建了4000多座街垒。<a class="footnote" href="#note486n"><img alt="" height="24" src="../../5eb9a36f724d92b4225a03c21d3399inr0.png" width="24"/></a></p>

<p class="tushuo">资料来源：Petit Palais, musée des Beaux-Arts de la Ville de Pa
ris. (Photo: CC0 Paris Musées)</p>

<ol class="footnote-content">
<li class="footnote-item" id="note476n"> <p>日记条目，1830年7月26日，见Juste Oli
vier, <span class="italic">Paris en 1830. Journal</span>, ed. André Delattre and
 Marc Denkinger (Chapel Hill, 1951), p. 235。</p> </li>
<li class="footnote-item" id="note477n"> <p>日记条目，1830年7月27日，10.30 p.m.,
 ibid., p. 239–43。</p> </li>
<li class="footnote-item" id="note478n"> <p>日记条目，1830年7月28日，6 p.m., ibi
d., pp. 248, 252, 255–6。</p> </li>
<li class="footnote-item" id="note479n"> <p>日记条目，1830年7月29日，9.30 p.m.,
ibid., p. 272。</p> </li>
<li class="footnote-item" id="note480n"> <p>David H. Pinkney, ‘The Revolution of
 1830 Seen by a Combatant’, <span class="italic">French Historical</span> <span
class="italic">Studies</span> 2/2 (1961), pp. 242–6.</p> </li>
<li class="footnote-item" id="note481n"> <p>Ibid., p. 245.</p> </li>
<li class="footnote-item" id="note482n"> <p>Ibid., pp. 242–6.</p> </li>
<li class="footnote-item" id="note483n"> <p>Daniel Stern [Marie d’Agoult], <span
 class="italic">Mes souvenirs, 1806–1833</span> (3rd edn, Paris, 1880), p. 327.<
/p> </li>
<li class="footnote-item" id="note484n"> <p>Ibid., pp. 328, 330.</p> </li>
<li class="footnote-item" id="note485n"> <p>Ibid., pp. 330–2.</p> </li>
<li class="footnote-item" id="note486n"> <p>Mark Traugott, <span class="italic">The Insurgent Barricade</span> (Berkeley, 2010), p. 105.</p> </li>
</ol>
''';

void main(List<String> argv) {
  final dom = parse(complex);
  for (final c in HtmlExtractor('foo/bar/a.html').extract(dom.body!)) {
    print(c.runtimeType);
    print(c);
  }
}
