# RandomMind の曲（BGM と決着の曲）

- 作者: RandomMind（OpenGameArt のユーザー。https://opengameart.org/users/randommind ）
- ライセンス: CC0 1.0（`LICENSE.txt`）。各曲のページの「License(s)」が CC0。作者は「クレジットはうれしいが要らない」と書いている
- 取ってきた日・ライセンスを確かめた日: 2026-11-15（各ページを開いて確かめた）。The Old Tower Inn は 2026-11-16
- 改変: 配布元の WAV を Ogg Vorbis（品質 4、約 120 kbps）に変換し、メタデータを落とした。長さ・音量・継ぎ目は変えていない（CC0 なので改変してよい）
- 2026-11-16 に足した The Old Tower Inn は、Ogg Vorbis の品質 3（約 110 kbps）。ステレオのまま、音量は変えていない
- 対戦の曲（Minstrel Dance、The Bard's Tale、Rising Moon、Battle）は、2026-11-17 に戦いの曲（`assets/audio/oga-battle/`）へ替えて、消した

| ファイル | 使う場面 | 元の曲（配布元のページ = 試聴できる） | 元のファイル |
| --- | --- | --- | --- |
| `medieval_exploration.ogg` | タイトル・部隊の編成・対戦の設定（`menu`） | Medieval: Exploration — https://opengameart.org/content/medieval-exploration | `Exploration.wav`（3:54） |
| `medieval_victory_theme.ogg` | 決着: 勝ち（`victory`） | Medieval: Victory Theme — https://opengameart.org/content/medieval-victory-theme | `victory.wav`（0:32） |
| `medieval_defeat_theme.ogg` | 決着: 負け・引き分け（`defeat`） | Medieval: Defeat Theme — https://opengameart.org/content/medieval-defeat-theme | `defeat.wav`（0:45） |
| `medieval_the_old_tower_inn_loop.ogg` | ストーリーの会話（`talk`） | Medieval: The Old Tower Inn（ループ版） — https://opengameart.org/content/medieval-the-old-tower-inn | `Loop_The_Old_Tower_Inn.wav`（0:50） |

どの曲をどの場面で鳴らすかは `game/sound_catalog.gd` と `game/scene_flow.gd`（`docs/sound.md`）。
