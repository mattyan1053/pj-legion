# 会話の静かな曲（OpenGameArt の CC0 の曲を、何人かから集めた）

- 配布元: OpenGameArt（下の表のページ。どれも試聴できる）
- ライセンス: どれも CC0 1.0（`LICENSE.txt`）。各曲のページの「License(s)」が CC0。ライセンスの文の入ったファイルは、どの曲にも付いていない
- 取ってきた日・ライセンスを確かめた日: 2026-11-21（各ページを開いて確かめた）
- 改変: Ogg Vorbis（品質 2、約 95 kbps、ステレオ、44.1 kHz）にし、メタデータを落とした。頭と終わりの無音を切った（表の「改変」）。
  音量は変えていない（大きさは `sound_catalog.gd` の `volume_db` でそろえる）。どれもループ用の曲ではないので、終わりの余韻のあと頭へ戻る

| ファイル | 使う場面（`game/sound_catalog.gd`） | 元の曲（作者）— 配布元のページ | 元のファイル | 改変 |
| --- | --- | --- | --- | --- |
| `waiting_ii.ogg` | ストーリーの会話: 落ち着いた（`talk_calm`） | Waiting II（Kistol。ピアノと弦）— https://opengameart.org/content/waiting-ii | `Waiting II_0.ogg`（1:38） | 終わりの無音 1 秒を切った（1:37） |
| `the_confrontation.ogg` | ストーリーの会話: 不穏（`talk_dark`） | The Confrontation（Umplix。作者の説明は「対決、突然の真実、闇への転落」）— https://opengameart.org/content/the-confrontation | `i_killed_your_brother_0.wav`（1:20） | 頭の無音 0.2 秒と終わりの無音を切った（1:18） |
| `aftermath.ogg` | ストーリーの会話: 戦いのあとの重さ（`talk_aftermath`） | Aftermath（indieteur。作者のタグは ending・war・sad）— https://opengameart.org/content/aftermath | `Aftermath.wav`（2:04） | 終わりの無音を切った（2:01） |

どの曲をどの場面で鳴らすかは `game/sound_catalog.gd` と `docs/sound.md`。
