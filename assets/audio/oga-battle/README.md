# 対戦の曲（OpenGameArt の CC0 の曲を、何人かから集めた）

- 配布元: OpenGameArt（下の表のページ。どれも試聴できる）
- ライセンス: どれも CC0 1.0（`LICENSE.txt`）。各曲のページの「License(s)」が CC0。ライセンスの文の入ったファイルは、どの曲にも付いていない
- 取ってきた日・ライセンスを確かめた日: 2026-11-17（各ページを開いて確かめた）。表の下の 5 曲（Battlegrounds から）は 2026-11-21
- 改変: Ogg Vorbis（品質 2、約 95 kbps、ステレオ、44.1 kHz）にし、メタデータを落とした。音量は変えていない（大きさは `sound_catalog.gd` の `volume_db` でそろえる）。
  ループのために、頭の無音を切ったもの・終わりの無音を切ったもの・終わりを頭へ重ねた（クロスフェード）ものがある（表の「改変」）

| ファイル | 使う場面（`game/sound_catalog.gd`） | 元の曲（作者）— 配布元のページ | 元のファイル | 改変 |
| --- | --- | --- | --- | --- |
| `battle_theme_a_loop.ogg` | 対戦: 草原と、見た目の分からない対戦（`battle`） | Cynic Battle Loop（Ferk。cynicmusic の Battle Theme A をループにしたもの。元の曲も CC0）— https://opengameart.org/content/cynic-battle-loop 、元: https://opengameart.org/content/battle-theme-a | `cynicbattleloop_0.ogg`（1:32） | なし |
| `great_labyrinth.ogg` | 対戦: 石の遺跡（`battle_ruins`） | Great Labyrinth（MintoDog）— https://opengameart.org/content/great-labyrinthorchestral-dungeon-music | `great_labyrinth_bpm160.flac`（2:13） | なし |
| `sigil.ogg` | 対戦: 結晶の森（`battle_crystal`） | Sigil（Kistol）— https://opengameart.org/content/sigil | `Sigil_3.ogg`（4:19） | 終わりの無音（約 8 秒）を切り、終わり 0.6 秒を頭へ重ねた（4:10） |
| `determined_pursuit_loop.ogg` | 守り切る戦い（`battle_tense`） | Determined Pursuit（Emma_MA）— https://opengameart.org/content/determined-pursuit-epic-orchestra-loop | `determined_pursuit_loop.wav`（1:48） | なし |
| `the_fire_dragon_loop.ogg` | 中ボスを倒す戦い（`battle_boss`） | The Fire Dragon（Umplix）— https://opengameart.org/content/the-fire-dragon | `the_fire_dragon_loopv2.wav`（1:51） | 頭の無音 0.94 秒を切った |
| `qazijamjam.ogg` | 敵を全滅させる戦い（`battle_rout`） | QaziJamJam（Emma_MA）— https://opengameart.org/content/qazijamjam-orchestral-battle-theme | `QaziJamJam.wav`（3:54） | 頭と終わりの無音を切り、終わり 1.5 秒を頭へ重ねた（3:52） |
| `the_march_of_devils_dome.ogg` | 魔物（骸骨の軍）との戦い（`battle_undead`） | The March of Devils Dome（Eldritch Grim）— https://opengameart.org/content/the-march-of-devils-dome | `the_march_of_devils_dome.wav`（2:14） | 頭の無音 0.6 秒を切り、終わりのフェード 1.5 秒を頭へ重ねた（2:12） |
| `epic_boss_battle_loop.ogg` | 終盤（`battle_climax`。どちらかの将の HP が半分を切ったら替わる） | Epic Boss Battle [Seamlessly Looping]（Juhani Junkala。OpenGameArt のユーザー SubspaceAudio）— https://opengameart.org/content/boss-battle-music | `Juhani Junkala - Epic Boss Battle [Seamlessly Looping].wav`（2:03） | なし |
| `fantasy_battlegrounds.ogg` | 対戦: 峠（`battle_fields`） | Fantasy - Battlegrounds（doge。作者のタグは Fantasy・orchestra・strings・percussion・woodwinds）— https://opengameart.org/content/fantasy-battlegrounds | `battleground_remastered_0.mp3`（1:34。配布は MP3 だけ） | なし |
| `the_battlefield.ogg` | 対戦: 尾根・採掘場（`battle_march`） | The Battlefield（Umplix。ホルン・小太鼓・シンバル）— https://opengameart.org/content/the-battlefield | `the_battlefield.wav`（1:52） | 頭の無音 0.05 秒を切った |
| `a_knights_challenge.ogg` | 対戦: 演習場・深い森（`battle_knight`） | A Knight's Challenge（Umplix。作者の説明は「勇ましいが親しみのある」）— https://opengameart.org/content/a-knights-challenge | `a_knights_challenge.wav`（1:02） | なし |
| `laments_of_the_war.ogg` | 魔物: 古戦場・縫い目の谷（`battle_lament`） | Laments of the War（cethiel。合唱と太鼓）— https://opengameart.org/content/laments-of-the-war | `Lament of the War - Lossless FLAC.flac`（3:48） | なし |
| `the_final_battle.ogg` | 終盤: 物語の最後の話（`battle_final`。話のファイルの `climax_music`） | The Final Battle（skrjablin）— https://opengameart.org/content/the-final-battle | `the_final_battle.ogg`（2:26） | 終わりの無音を切った（2:25） |

## 次点（入れていない。耳で「違う」となったら、取ってきて `sound_catalog.gd` の `path` を替える）

どれも CC0（2026-11-17 にページで確かめた。To Battle!・Rocky Cliffs・Massive Battle・Dramatic Boss Encounter は 2026-11-21）。

| 場面 | 次点 1 | 次点 2 |
| --- | --- | --- |
| 草原（`battle`） | Battle Theme（wolfgang。1:56）https://opengameart.org/content/battle-theme-0 | Call to War（Umplix。1:16）https://opengameart.org/content/call-to-war |
| 石の遺跡（`battle_ruins`） | To Battle!（Umplix。1:31）https://opengameart.org/content/to-battle | Battle! (Rocky Cliffs)（Umplix。合唱。1:43）https://opengameart.org/content/battle-rocky-cliffs |
| 結晶の森（`battle_crystal`） | Fall of Nightmares（nene）https://opengameart.org/content/fall-of-nightmares-epic-orchestral | Arcanum（vitalezzz）https://opengameart.org/content/arcanum |
| 守り切る（`battle_tense`） | Call to War（Umplix）https://opengameart.org/content/call-to-war | Battle Theme（wolfgang）https://opengameart.org/content/battle-theme-0 |
| 中ボス（`battle_boss`） | Dramatic Boss Encounter（cynicmusic）https://opengameart.org/content/dramatic-boss-encounter | Evil Approach（nene。1:08 と短い）https://opengameart.org/content/evil-approach |
| 全滅（`battle_rout`） | Massive Battle（Eldritch Grim。0:31 と短い）https://opengameart.org/content/massive-battle | To Battle!（Umplix）https://opengameart.org/content/to-battle |
| 魔物（`battle_undead`） | Raiders March（bobjt。ループ版あり。1:02 と短い）https://opengameart.org/content/raiders-march | Epic March Loop（Eldritch Grim。いまの曲の行進の部分だけのループ。0:44）https://opengameart.org/content/epic-march-loop |
| 終盤（`battle_climax`） | Dramatic Boss Encounter（cynicmusic）https://opengameart.org/content/dramatic-boss-encounter | Fall of Nightmares（nene。合唱と金管。1:28）https://opengameart.org/content/fall-of-nightmares-epic-orchestral |

見送ったもの: Heartfelt Battle（request。CC0 だが、作者が「Kingdom Hearts の曲を下敷きにした」と書いていて、元の曲の権利がはっきりしない）。

どの曲をどの場面で鳴らすかは `game/sound_catalog.gd` と `docs/sound.md`。
