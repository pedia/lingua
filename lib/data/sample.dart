import '../epub/epub.dart';

final sample = Book(
  title: 'Sample',
  author: 'dev',
  chapters: [
    Chapter.cache(
      href: "",
      title: "Chapter 1",
      lines: [
        TextBlock.single(
          'For some reason, there was one of them at the funeral.',
          lang: 'en',
        ),
        TextBlock.single('出於某種原因，葬禮上有他們之一。', lang: 'zh'),
        TextBlock.single(
          'Ever since Callum Wells was young he’d seen things. People. Things that were people, or people that were things. The not-quite-human. They were not very common, but not so vanishingly rare that he could write it off as imagination. He’d mentioned it, once, as a child, and the doctors had prescribed pills. Callum Sr., paranoid soul that he was, had stopped his son from taking them after a week when they did no more than make him fuzzy and stupid.',
          lang: 'en',
        ),
        TextBlock.single(
          '卡勒姆·威爾斯從小就見過很多東西。人們。物即人，人即物。不完全是人類。它們並不常見，但也沒有罕見到他可以將其視為想像。他小時候曾提過一次，醫生開了藥。老卡勒姆，一個偏執的靈魂，在一周後阻止了他的兒子服用這些藥物，因為這些藥物只會讓他變得模糊和愚蠢。',
          lang: 'zh',
        ),
        TextBlock.single(
          'Callum didn’t mention what he saw again. But that didn’t mean he stopped seeing them. Mostly, it was people with the wrong color skin, the wrong ears, the wrong eyes. The wrong proportions. Sometimes it was just people that nobody else seemed to notice, walking as if they were invisible.',
          lang: 'en',
        ),
        TextBlock.single(
          '卡勒姆沒有再提及他所看到的事情。但這並不意味著他不再見到他們。大多數情況下，這些人的膚色、耳朵、眼睛都不對勁。比例錯誤。有時，只是一些其他人似乎沒有註意到的人，他們走路就像是隱形的。',
          lang: 'zh',
        ),
        TextBlock.single(
          'It was one of the invisible people who had come by, walking around the edges of the small crowd. The person in question was a short man, looking entirely human but dressed in bright blue and wearing a beret, which was one reason Callum knew he was neither a mourner nor even visible. At least some people should have glanced at the flamboyant man but nobody did. Nor did the man really seem to pay attention to the mourners, instead wandering between them and the coffins and kneeling down to inspect something on one of the nearby gravestones. He glanced up and made eye contact with Callum. Immediately Callum relaxed his gaze, looking past the not-person.',
          lang: 'en',
        ),
        TextBlock.single(
          '這是走過來的隱形人之一，在一小群人的邊緣走來走去。這個人是個矮個子，看起來完全是人類，但穿著亮藍色衣服，戴著貝雷帽，這就是卡勒姆知道他既不是哀悼者也不是可見的原因之一。至少應該有人多看一眼這個浮誇的男人，但沒有人看。該男子似乎也沒有真正關注哀悼者，而是在他們和棺材之間徘徊，跪下來檢查附近墓碑上的東西。他抬起頭，與卡勒姆目光接觸。卡勒姆立刻放鬆了目光，目光越過了非人。',
          lang: 'zh',
        ),
        TextBlock.single(
          'It was a skill he’d had to learn in lieu of the drugs. People stared off into space a lot, but they didn’t focus on things that weren’t there. The invisible man frowned at Callum, leaned to one side, and when Callum’s eyes didn’t track him, shrugged and continued onward. Irrational anger kindled in Callum’s gut at the man’s disrespect. Even if he was invisible to everyone else, he could have at least waited half an hour for the funeral to be over. He was lucky Callum was not in as dark a mood as he might have been at his parent’s graves.',
          lang: 'en',
        ),
        TextBlock.single(
          '這是他必須學習的技能，以代替毒品。人們經常凝視太空，但他們並沒有關注那些不存在的事物。隱形人對卡勒姆皺起眉頭，向一側傾斜，當卡勒姆的目光沒有追蹤到他時，他聳聳肩，繼續前進。對於這個男人的不尊重，卡勒姆的內心燃起了非理性的憤怒。就算別人看不到他，他至少可以等半小時，葬禮才能結束。他很幸運，卡勒姆的心情不像在父母的墳墓前那麼陰鬱。',
          lang: 'zh',
        ),
        TextBlock.single(
          'In a way the funeral was a mere formality. There was pain, yes, but it was a dull ache rather than anything sharp. His parents had been pushing ninety and he’d visited them in hospice for years before they’d finally passed away. It hadn’t been a surprise, and he’d done most of his mourning before medical science caught up with what was already certain.',
          lang: 'en',
        ),
        TextBlock.single(
          '從某種意義上說，葬禮只是一種形式。是的，確實有疼痛，但那是一種鈍痛，而不是任何尖銳的疼痛。他的父母已經九十多歲了，在他們最終去世之前，他已經在臨終關懷醫院探望了他們很多年。這並不奇怪，在醫學科學趕上已經確定的事情之前，他已經完成了大部分哀悼。',
          lang: 'zh',
        ),
        TextBlock.single(
          'He was aware, and had been since he was young enough to count, that their relative ages meant that his parents had either flouted biological law or were taking care of a grandchild. Considering how much he looked like Callum, Sr., adoption was not a possibility. His birth certificate claimed Callum Sr. and Mary as his parents, and he’d decided he was fine with that.',
          lang: 'en',
        ),
        TextBlock.single(
          '他知道，而且從他還年輕的時候就知道，他們的相對年齡意味著他的父母要么藐視生物法則，要么正在照顧孫子。考慮到他長得很像老卡勒姆，收養是不可能的。他的出生證明上寫著老卡勒姆和瑪麗是他的父母，他認為自己對此沒有意見。',
          lang: 'zh',
        ),
        TextBlock.single(
          'In the end, it wasn’t important. He didn’t feel the need to muse on such unweighty matters, especially not during the funeral. Especially when he was distracted by carefully not looking at the invisible man snooping around the graveyard.',
          lang: 'en',
        ),
        TextBlock.single(
          '最後，這並不重要。他覺得沒有必要去思考這些無關緊要的事情，尤其是在葬禮期間。尤其是當他因為小心翼翼地不看那個在墓地周圍窺探的隱形人而分心時。',
          lang: 'zh',
        ),
        TextBlock.single(
          '“Callum?” He blinked, and looked at Miss Mosley, one of his parent’s friends who was practically an aunt and an octogenarian herself. She reached out to take his hand and patted it soothingly. “It’s okay, dear.”',
          lang: 'en',
        ),
        TextBlock.single(
          '「卡勒姆？」他眨了眨眼，看著莫斯利小姐，她是他父母的朋友之一，她自己實際上已經是一位阿姨，而且已經是八十多歲的老人了。她伸手握住他的手，安撫地拍了拍。 “沒關係，親愛的。”',
          lang: 'zh',
        ),
        TextBlock.single(
          '“Thank you, Miss Mosley,” Callum said, properly going back to ignoring the man crashing the funeral. “We all knew it was coming, but now that it’s here…”',
          lang: 'en',
        ),
        TextBlock.single(
          '「謝謝你，莫斯利小姐，」卡勒姆說，然後又適當地忽略了那個闖入葬禮的男人。 “我們都知道它會來，但現在它就在這裡……”',
          lang: 'zh',
        ),
        TextBlock.single(
          '“Yes, I know. When you get to my age, you go to so many funerals.” Miss Mosely said, a little sadly.',
          lang: 'en',
        ),
        TextBlock.single(
          '「是的，我知道。當你到了我這個年紀，你會參加很多葬禮。」莫斯利小姐有些悲傷地說。',
          lang: 'zh',
        ),
        TextBlock.single(
          "“Zorian’s eyes abruptly shot open as a sharp pain erupted from his stomach. His whole body convulsed, buckling against the object that fell on him, and suddenly he was wide awake, not a trace of drowsiness in his mind.”",
          lang: "en",
        ),
        TextBlock.single(
          "“佐里安的眼睛猛地睁开，腹部传来一阵剧痛。他全身抽搐，抵住了落在他身上的物体，猛然间他就彻底清醒了，脑子里没有一丝睡意。”",
          lang: 'zh',
        ),
      ],
    ),
  ],
);
