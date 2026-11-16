# RandomMind の曲（BGM と決着の曲）

- 作者: RandomMind（OpenGameArt のユーザー。https://opengameart.org/users/randommind ）
- ライセンス: CC0 1.0（`LICENSE.txt`）。各曲のページの「License(s)」が CC0。作者は「クレジットはうれしいが要らない」と書いている
- 取ってきた日・ライセンスを確かめた日: 2026-11-15（各ページを開いて確かめた）。下の表の後ろ 4 曲は 2026-11-16
- 改変: 配布元の WAV を Ogg Vorbis（品質 4、約 120 kbps）に変換し、メタデータを落とした。長さ・音量・継ぎ目は変えていない（CC0 なので改変してよい）
- 2026-11-16 に足した 4 曲は、Ogg Vorbis の品質 3（約 110 kbps。Rising Moon だけ長いので品質 0、約 50 kbps）。ステレオのまま、音量は変えていない。
  ループ版の無い 2 曲は、終わりの無音を切った: Battle は 72.5 秒まで（最後の 0.5 秒でフェード）、Rising Moon は 219 秒まで（最後の 2 秒でフェード）

| ファイル | 使う場面 | 元の曲（配布元のページ = 試聴できる） | 元のファイル |
| --- | --- | --- | --- |
| `medieval_exploration.ogg` | タイトル・部隊の編成・対戦の設定（`menu`） | Medieval: Exploration — https://opengameart.org/content/medieval-exploration | `Exploration.wav`（3:54） |
| `medieval_minstrel_dance_loop.ogg` | 対戦: 草原の見た目と、見た目の分からない対戦（`battle`） | Medieval: Minstrel Dance（ループ版） — https://opengameart.org/content/medieval-minstrel-dance | `Loop_Minstrel_Dance_0.wav`（0:56） |
| `medieval_victory_theme.ogg` | 決着: 勝ち（`victory`） | Medieval: Victory Theme — https://opengameart.org/content/medieval-victory-theme | `victory.wav`（0:32） |
| `medieval_defeat_theme.ogg` | 決着: 負け・引き分け（`defeat`） | Medieval: Defeat Theme — https://opengameart.org/content/medieval-defeat-theme | `defeat.wav`（0:45） |
| `medieval_the_bards_tale_loop.ogg` | 対戦: 石の遺跡の見た目（`battle_ruins`） | Medieval: The Bard's Tale（ループ版） — https://opengameart.org/content/medieval-the-bards-tale | `Loop_The_Bards_Tale.wav`（0:58） |
| `fantasy_rising_moon.ogg` | 対戦: 結晶の森の見た目（`battle_crystal`） | Fantasy: Rising Moon — https://opengameart.org/content/fantasy-rising-moon | `Rising_Moon_0.mp3`（3:45。3:39 で切った） |
| `medieval_battle.ogg` | 対戦: 緊迫した戦い（`battle_tense`。ストーリーの守り切る話） | Medieval: Battle — https://opengameart.org/content/medieval-battle | `battle_1.wav`（1:19。1:12.5 で切った） |
| `medieval_the_old_tower_inn_loop.ogg` | ストーリーの会話（`talk`） | Medieval: The Old Tower Inn（ループ版） — https://opengameart.org/content/medieval-the-old-tower-inn | `Loop_The_Old_Tower_Inn.wav`（0:50） |

どの曲をどの場面で鳴らすかは `game/sound_catalog.gd` と `game/scene_flow.gd`（`docs/sound.md`）。
