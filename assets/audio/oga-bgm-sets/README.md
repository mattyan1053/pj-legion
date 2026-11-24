# BGM の組の候補（OpenGameArt の CC0 の曲を、何人かから集めた）

オプションの「BGM の組」（`game/sound_catalog.gd` の `MUSIC_SETS`）で、いまの曲と聴き比べるための曲。既定（いまの組）では鳴らない。

- 配布元: OpenGameArt（下の表のページ。どれも試聴できる）
- ライセンス: どれも CC0 1.0（`LICENSE.txt`）。各曲のページの「License(s)」が CC0。ライセンスの文の入ったファイルは、どの曲にも付いていない
- 取ってきた日・ライセンスを確かめた日: 2026-11-24（各ページを開いて確かめた）
- 改変: Ogg Vorbis（品質 4、約 128 kbps、ステレオ、44.1 kHz）にし、メタデータを落とした（`some_militaristic_tune.ogg` だけは元のファイルのまま）。
  音量は変えていない（大きさは `sound_catalog.gd` の `volume_db` でそろえる）。頭と終わりの無音を切ったもの、端にフェードを付けたものがある（表の「改変」）
- 曲は聴いていない。選んだ根拠は、作者の説明とタグ、スペクトルの見立て（生楽器ふうか）、つなぎ目の測り（下）

| ファイル | 組と役（`MUSIC_SETS`） | 元の曲（作者）— 配布元のページ | 元のファイル | 改変 |
| --- | --- | --- | --- | --- |
| `a_legend_will_rise.ogg` | A: タイトル（`title`） | A Legend Will Rise (Orchestral)（CodeManu）— https://opengameart.org/content/a-legend-will-rise-orchestral | `A Legend Will Rise.mp3`（1:10） | なし |
| `the_last_horn.ogg` | B: タイトル（`title`） | The Last Horn（redFireMeat）— https://opengameart.org/content/the-last-horn | `the_last_horn.mp3`（3:47） | 終わりの無音を 1 秒残して切った（3:46） |
| `last_journey.ogg` | C: タイトル（`title`） | Last Journey（Crocdent）— https://opengameart.org/content/last-journey | `last_journey_0.mp3`（1:06） | 終わりの無音を 1 秒残して切った（1:03） |
| `beautiful_forest.ogg` | A: 落ち着いた会話（`talk_calm`） | Beautiful Forest [Orchestra]（nene）— https://opengameart.org/content/beautiful-forest-orchestra | `beautiful_forest_16bit_44.1khz_1.wav`（1:10） | なし |
| `prologue_theme.ogg` | B: 落ち着いた会話（`talk_calm`） | Prologue Theme（CleytonKauffman）— https://opengameart.org/content/prologue-theme | `Prologue Theme.zip` の `Prologue Theme.wav`（1:22） | なし |
| `kings_feast_loop.ogg` | C: 軽い会話（`talk`） | Medieval: King's Feast（RandomMind）— https://opengameart.org/content/medieval-kings-feast | `Loop_Kings_Feast_0.wav`（ループ版。1:21） | なし |
| `hope_orchestral_battle.ogg` | A: 対戦・草原（`battle`） | Hope (Orchestral battle music)（MintoDog）— https://opengameart.org/content/hopeorchestral-battle-music | `hope_orchestral_battle_music_bpm165.flac`（1:10） | なし |
| `some_militaristic_tune.ogg` | A: 対戦・尾根と採掘場（`battle_march`） | Some Militaristic Tune（Spring Spring）— https://opengameart.org/content/some-militaristic-tune | `march2_0.ogg`（3:56） | なし（元のファイルのまま） |
| `final_stand.ogg` | B: 対戦・草原（`battle`） | Final Stand（iamoneabe）— https://opengameart.org/content/final-stand | `final_stand.wav`（1:04） | 頭と終わりに 0.03 秒のフェード（つなぎ目の段差を消す） |
| `col_legno.ogg` | B: 対戦・尾根と採掘場（`battle_march`） | Col Legno（Vehicle）— https://opengameart.org/content/col-legno | `Vehicle - OGA - Col Legno.wav`（1:12） | 終わりに 0.03 秒のフェード |
| `epic_endgame_cinematic.ogg` | A: 終盤・中ボス（`battle_climax`・`battle_boss`） | Epic Endgame Cinematic（cynicmusic）— https://opengameart.org/content/epic-endgame-cinematic | `ChoirChordsBassMaster.wav`（1:31） | なし |
| `duel_of_the_dungeons.ogg` | B: 終盤・中ボス（`battle_climax`・`battle_boss`） | Duel of the Dungeons（Umplix）— https://opengameart.org/content/duel-of-the-dungeons | `duel_of_the_dungeons_0.wav`（1:18） | 頭に 0.03 秒、終わりに 2 秒のフェード（つなぎ目が合わないので、静まってから頭へ戻す） |
| `victory_umplix.ogg` | A: 勝ち（`victory`） | Victory（Umplix）— https://opengameart.org/content/victory-4 | `victory_0.wav`（0:13） | 頭の無音を切り、終わりの無音を 0.5 秒残して切った（0:10） |
| `victory_fanfare_short.ogg` | B: 勝ち（`victory`） | Victory Fanfare Short（cynicmusic）— https://opengameart.org/content/victory-fanfare-short | `Heavy_ConceptB.wav`（0:12） | 頭の無音を切った |
| `game_over_kistol.ogg` | A: 負け（`defeat`） | Game Over（Kistol）— https://opengameart.org/content/game-over | `Game Over.flac`（0:15） | なし |
| `bittersweet.ogg` | B: 負け（`defeat`） | Bittersweet（Emma_MA）— https://opengameart.org/content/bittersweet | `bittersweet_0.mp3`（0:34） | 頭の無音（1.6 秒）を切り、終わりの無音を 0.5 秒残して切った（0:31） |
| `lose_game_short.ogg` | C: 負け（`defeat`） | Lose Game Short Music Clip（Robin Lamb。パブリックドメインの生楽器の音源 VSCO 2 CE・VCSL で作ったと作者が書いている）— https://opengameart.org/content/lose-game-short-music-clip | `losegamemusic.wav`（0:07） | 頭の無音を切った |

## ループのつなぎ目（測り。耳では確かめていない）

終わりと頭のつなぎ目の、隣り合う標本の差を、まわりの差（99.5 パーセンタイル）と比べた。

- そのままつながる: Hope（作者が「ループできる」）、Some Militaristic Tune、King's Feast（ループ版）。Prologue Theme（作者が「つなぎ目なし」）は差がまわりの 2 倍ほどで、小さな音が出るかもしれない。
- 静かに終わって頭へ戻る（いまのタイトルの曲と同じ）: A Legend Will Rise、The Last Horn、Last Journey、Beautiful Forest、Epic Endgame Cinematic、Col Legno。
- 段差があった: Final Stand（作者が「ループできる」。64 秒ちょうど）は端に 0.03 秒のフェードを付けた。Duel of the Dungeons は終わりと頭の大きさも合わないので、終わり 2 秒をフェードで消した。

## 見送ったもの

候補の表（Issue #46 のコメント「[案] CC0 の素材の候補（2 回目）」）の CC0 の曲のうち、次の 2 曲は入れていない（ページは CC0 と確かめた）。

- intense boss battle（haruta）: 作者の説明に楽器が無く、タグも `bgm` だけ。スペクトルで、揺れの無い音の高さが四角く並ぶ（打ち込みの電子音・ビット音源に近い形）。
- Win Fanfare（gchoc）: 作者の説明に楽器が無い。スペクトルで、倍音がきれいに並んだまま高さが滑る（合成音に近い形）。

CC-BY の候補（Epic Orchestral Fantasy Theme、Sylvan Waltz、To arms!、Final Confrontation）は、クレジットの画面の要否を人間が決めるまで入れない。

どの曲をどの場面で鳴らすかは `game/sound_catalog.gd` と `docs/sound.md`。
