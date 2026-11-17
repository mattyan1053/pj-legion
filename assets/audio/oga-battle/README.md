# 対戦の曲（OpenGameArt の CC0 の曲を、何人かから集めた）

- 配布元: OpenGameArt（下の表のページ。どれも試聴できる）
- ライセンス: どれも CC0 1.0（`LICENSE.txt`）。各曲のページの「License(s)」が CC0。ライセンスの文の入ったファイルは、どの曲にも付いていない
- 取ってきた日・ライセンスを確かめた日: 2026-11-17（各ページを開いて確かめた）
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

## 次点（入れていない。耳で「違う」となったら、取ってきて `sound_catalog.gd` の `path` を替える）

どれも CC0（2026-11-17 にページで確かめた）。

| 場面 | 次点 1 | 次点 2 |
| --- | --- | --- |
| 草原（`battle`） | Fantasy - Battlegrounds（doge）https://opengameart.org/content/fantasy-battlegrounds | Battle Theme（wolfgang）https://opengameart.org/content/battle-theme-0 |
| 石の遺跡（`battle_ruins`） | Laments of the War（cethiel）https://opengameart.org/content/laments-of-the-war | The Battlefield（Umplix）https://opengameart.org/content/the-battlefield |
| 結晶の森（`battle_crystal`） | Fall of Nightmares（nene）https://opengameart.org/content/fall-of-nightmares-epic-orchestral | Arcanum（vitalezzz）https://opengameart.org/content/arcanum |
| 守り切る（`battle_tense`） | The Final Battle（skrjablin）https://opengameart.org/content/the-final-battle | Call to War（Umplix）https://opengameart.org/content/call-to-war |
| 中ボス（`battle_boss`） | The Final Battle（skrjablin）https://opengameart.org/content/the-final-battle | Evil Approach（nene。1:08 と短い）https://opengameart.org/content/evil-approach |
| 全滅（`battle_rout`） | Fantasy - Battlegrounds（doge）https://opengameart.org/content/fantasy-battlegrounds | To Battle!（Umplix）https://opengameart.org/content/to-battle |
| 魔物（`battle_undead`） | Raiders March（bobjt。ループ版あり。1:02 と短い）https://opengameart.org/content/raiders-march | Epic March Loop（Eldritch Grim。いまの曲の行進の部分だけのループ。0:44）https://opengameart.org/content/epic-march-loop |
| 終盤（`battle_climax`） | The Final Battle（skrjablin）https://opengameart.org/content/the-final-battle | Fall of Nightmares（nene。合唱と金管。1:28）https://opengameart.org/content/fall-of-nightmares-epic-orchestral |

見送ったもの: Heartfelt Battle（request。CC0 だが、作者が「Kingdom Hearts の曲を下敷きにした」と書いていて、元の曲の権利がはっきりしない）。

どの曲をどの場面で鳴らすかは `game/sound_catalog.gd` と `docs/sound.md`。
