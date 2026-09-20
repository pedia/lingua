import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' show parse;
import '../epub/epub.dart';

Book sample() {
  final cs = HtmlExtractor('foo/bar/a.html').extract(complex.body!);
  return Book(
    title: 'Sample',
    author: 'dev',
    chapters: [
      Chapter.cache(
        href: "",
        title: "Chapter 1",
        chunks: [
          TextBlock(
            [InlineText('🌸 Romance & Longing')],
            headingLevel: 2,
            lang: 'en',
          ),
          TextBlock.single(
            'If I know what love is, it is because of you.',
            lang: 'en',
          ),
          TextBlock.single(
            '愿得一人心，白首不相离。 (May I win a heart, and never part until our hair turns white.',
            lang: "zh",
          ),
          TextBlock.single(
            'I love you not only for what you are, but for what I am when I am with you.',
            lang: 'en',
          ),
          TextBlock.single('我爱你不仅因为你的样子，还因为和你在一起时我的样子。', lang: 'zh'),
          TextBlock.single(
            'In the book of life, you are my favorite chapter.',
            lang: 'en',
          ),
          TextBlock.single('在生命这本长卷里，你是我最喜欢的篇章。', lang: 'zh'),
          TextBlock(
            [InlineText('🍂 Solitude & Reflection')],
            headingLevel: 2,
            lang: 'en',
          ),
          TextBlock.single('The quiet mind is the best companion.', lang: 'en'),
          TextBlock.single('独处是灵魂的清欢。 (Solitude is the pure joy of the soul.)'),
          TextBlock.single(
            'Time tempers everything, leaving only the truest behind.',
            lang: 'en',
          ),
          TextBlock.single('岁月洗尽铅华，留下最真的情意。', lang: 'zh'),
          TextBlock.single(
            'We are all travelers in the wilderness of this world, and the best we can find in our travels is an honest friend.',
            lang: 'en',
          ),
          TextBlock.single('我们都是尘世的旅人，旅途中最美的际遇，莫过于遇到懂你的人。', lang: 'zh'),
          TextBlock.single(
            'There is a crack in everything, that\'s how the light gets in.',
            lang: 'en',
          ),

          TextBlock(
            [InlineText('✨ Hope & Resilience')],
            headingLevel: 2,
            lang: 'en',
          ),
          TextBlock.single('万物皆有裂痕，那是光照进来的地方。', lang: 'zh'),
          TextBlock.single(
            'May you find hidden treasures wherever you go.',
            lang: 'en',
          ),
          TextBlock.single('愿你行囊饱满，所到之处皆有惊喜。', lang: 'zh'),
          TextBlock.single(
            'The flower that blooms in adversity is the rarest and most beautiful of all.',
            lang: 'en',
          ),
          TextBlock.single('逆境中绽放的花朵，最是难得，也最是美丽。', lang: 'zh'),
          TextBlock.single(
            'The mountain remains still while the river flows endlessly.',
            lang: 'en',
          ),
          TextBlock.single('青山依旧在，绿水长流不息。', lang: 'zh'),
          TextBlock.single(
            'Live as beautifully as summer flowers and die as quietly as autumn leaves.',
            lang: 'en',
          ),
          TextBlock.single(
            '生如夏花之绚烂，死如秋叶之静美。 (Adapted from Rabindranath Tagore\'s Stray Birds)',
            lang: 'zh',
          ),
        ],
      ),
      Chapter.cache(title: 'Features', href: 'foo/bar/a.html', chunks: cs),
    ],
    files: {
      'foo/images/00001.png': ArchiveFile.bytes('00001.png', note),
      'note.png': ArchiveFile.bytes('note.png', note),
    },
  );
}

final note = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 32, 0, 0, 0, 32, 1, 3, 0, 0, 0, 73, 180, 232, 183,
  0, 0, 0, 3, 80, 76, 84, 69, 255, 0, 0, 25, 226, 9, 55, 0, 0,
  0, 12, 73, 68, 65, 84, 120, 218, 99, 96, 24, 220, 0, 0, 0, 160,
  0, 1, 142, 251, 177, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 62, //
  96, 130,
]);

final complex = parse('''
<p><img src="../images/00001.png" /></p>

<p class="calibre8"><span class="calibre11">尽管美国的禁酒令在20世纪20年
代被废除，但自行车还是促成了美国人酒精消费行为的持久性改变——美国的一些县至今仍然流
行“干型酒”。
        <sup class="calibre22"><a href="part0039.html#footnote-39-65" type="noteref" class="calibre"> <img alt="“干型酒”的含糖量在4g/L以下。美国人一般更偏爱糖分更多的“半干型酒”。" class="epub-footnote" src="../images/00001.png" zy-footnote="“干型酒”的含糖量在4g/L以下。美国人一般更偏爱糖分更多的“半干型酒”。"/></a></sup></span></p>

<aside id="footnote-39-65" type="footnote" class="calibre"><ol class="duokan-footnote-content"><li class="duokan-footnote-item">“干型酒”的含糖量在4g/L以下。美国人一般更偏爱糖分更多的“半干型酒”。</li>
</ol>
</aside>

<p>这纯属<b>男性</b>所为</p>

<p>敦请奥尔良公爵登基。<a class="footnote" href="#note485n"><img alt="" height="24" src="../../note.png" width="24"/></a>在72小时的激战之后，七月革命结束了。后来，这72小时在法国历史上以“光荣三日”著称。三天的战斗导致800名平民和200名士兵死亡，4000名平民和800名士兵负伤。革命期间，起义者在巴黎的大街小巷中建了4000多座街垒。<a class="footnote" href="#note486n"><img alt="" height="24" src="../../note.png" width="24"/></a></p>

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
''');
