# RandomMind の曲（BGM と決着の曲）

- 作者: RandomMind（OpenGameArt のユーザー。https://opengameart.org/users/randommind ）
- ライセンス: CC0 1.0（`LICENSE.txt`）。各曲のページの「License(s)」が CC0。作者は「クレジットはうれしいが要らない」と書いている
- 取ってきた日・ライセンスを確かめた日: 2026-11-15（各ページを開いて確かめた）。The Old Tower Inn は 2026-11-16
- 改変: 配布元の WAV を Ogg Vorbis（品質 4、約 120 kbps）に変換し、メタデータを落とした。長さ・音量・継ぎ目は変えていない（CC0 なので改変してよい）
- 2026-11-16 に足した The Old Tower Inn は、Ogg Vorbis の品質 3（約 110 kbps）。ステレオのまま、音量は変えていない
- 2026-11-21 に足した Rejoicing と Lament for a Warrior's Soul は、Ogg Vorbis の品質 2（約 95 kbps）。Rejoicing は配布元のループ版の WAV をそのまま、Lament は配布元の MP3（ほかの形式が無い）から、頭の無音 1.4 秒と終わりの無音を切った（2:35）。音量は変えていない
- 対戦の曲（Minstrel Dance、The Bard's Tale、Rising Moon、Battle）は、2026-11-17 に戦いの曲（`assets/audio/oga-battle/`）へ替えて、消した

| ファイル | 使う場面 | 元の曲（配布元のページ = 試聴できる） | 元のファイル |
| --- | --- | --- | --- |
| `medieval_exploration.ogg` | タイトル・部隊の編成・対戦の設定（`menu`） | Medieval: Exploration — https://opengameart.org/content/medieval-exploration | `Exploration.wav`（3:54） |
| `medieval_victory_theme.ogg` | 決着: 勝ち（`victory`） | Medieval: Victory Theme — https://opengameart.org/content/medieval-victory-theme | `victory.wav`（0:32） |
| `medieval_defeat_theme.ogg` | 決着: 負け・引き分け（`defeat`） | Medieval: Defeat Theme — https://opengameart.org/content/medieval-defeat-theme | `defeat.wav`（0:45） |
| `medieval_the_old_tower_inn_loop.ogg` | ストーリーの会話: 軽い（`talk`） | Medieval: The Old Tower Inn（ループ版） — https://opengameart.org/content/medieval-the-old-tower-inn | `Loop_The_Old_Tower_Inn.wav`（0:50） |
| `medieval_rejoicing_loop.ogg` | ストーリーの会話: 勝って明るい（`talk_bright`） | Medieval: Rejoicing（ループ版） — https://opengameart.org/content/medieval-rejoicing | `Loop_Rejoicing.wav`（0:42） |
| `fantasy_lament_for_a_warriors_soul.ogg` | ストーリーの会話: 悲しい（`talk_sad`） | Fantasy: Lament for a Warrior's Soul — https://opengameart.org/content/fantasy-lament-for-a-warriors-soul | `Lament_for_a_Warriors_Soul_REUPLOAD.mp3`（2:43。作者が「時間と音を直した」と書いた新しいほう） |

どの曲をどの場面で鳴らすかは `game/sound_catalog.gd` と `game/scene_flow.gd`（`docs/sound.md`）。
