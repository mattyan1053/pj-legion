# タイトルの曲（OpenGameArt の CC0 の曲）

- 作者: Joth（OpenGameArt のユーザー）
- 配布元: https://opengameart.org/content/fantasy-orchestral-theme （試聴できる）
- ライセンス: CC0 1.0（`LICENSE.txt`）。ページの「License(s)」が CC0。ライセンスの文の入ったファイルは付いていない
- 取ってきた日・ライセンスを確かめた日: 2026-11-22（ページを開いて確かめた）
- 作者の説明: 「旋律のはっきりしたオーケストラの曲。少しだけゲームらしい音がある。ゆっくり静かに始まり、高まって終わる。ゲームのオープニングの曲として作った」
- 改変: 終わりの無音（約 3.7 秒）を切り、最後の 0.6 秒をフェードアウトした（3:08）。Ogg Vorbis（品質 2、約 80 kbps、ステレオ、44.1 kHz）にし、メタデータを落とした。
  音量は変えていない（大きさは `sound_catalog.gd` の `volume_db` でそろえる）

| ファイル | 使う場面（`game/sound_catalog.gd`） | 元のファイル |
| --- | --- | --- |
| `fantasy_orchestral_theme.ogg` | タイトル（`title`） | `FantasyOrchestralTheme_1.mp3`（3:12） |

## 選び方と次点

人間の言葉（11/22。Issue #46）: 「タイトル画面の BGM は、もっとテーマソングっぽいのがいい。今のは、何か選択中の BGM っぽい」。
求めたもの: 旋律がはっきりした、オーケストラ寄りの、始まりの高まりがあるもの。ファンタジー寄り、ビット音源は使わない、シンセが前に出すぎない。

OpenGameArt の CC0 の曲から 5 曲を取ってきて測った（10 秒ごとの音量と音色の明るさ）。

| 曲 | 長さ | 大きさ | 形 | 判断 |
| --- | --- | --- | --- | --- |
| **Fantasy Orchestral Theme**（Joth） | 3:12 | -15.3 LUFS | 静か（-16 dB）に始まり、2 分すぎに山（-12 dB）、静かな終わり（-25 dB） | 入れた。作者がオープニングの曲として作った |
| The Ancient Legend（vitalezzz）https://opengameart.org/content/the-ancient-legend | 3:06 | -15.7 LUFS | 小さく（-22 dB）始まり、だんだん高まる。終わりは静か | 次点 1。オーケストラ。始まりがより控えめ |
| Rise of the Early Dawn（antonioraymond71）https://opengameart.org/content/rise-of-the-early-dawn | 1:42 | -16.6 LUFS | 明るく始まり、途中で一度沈む。頭と終わりの大きさが近い（ループ向き） | 次点 2。作者いわく「Elder Scrolls に着想を得た、朝の山の景色」。短い |
| Journey With No Name（iamoneabe）https://opengameart.org/content/journey-with-no-name | 2:08 | -17.3 LUFS | 初めから終わりまで同じ大きさ | 見送り。高まりが無い |
| Tale on the Late (Main Theme)（Loyalty Freak Music）https://opengameart.org/content/tale-on-the-late-main-theme | 1:16 | -12.0 LUFS | 音色が明るい（ほかの倍） | 見送り。軽く、シンセ寄りに聞こえそう |

差し替えるときは、取ってきて `sound_catalog.gd` の `title` の `path` と `volume_db` を替える
（大きさは、-15 LUFS ほどの曲で -4 dB。`menu` の曲（-11.5 LUFS、-8 dB）と同じくらいに聞こえるように合わせた）。
