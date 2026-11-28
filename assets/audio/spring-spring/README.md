# spring-spring の効果音

クレジット（タイトルの「クレジット」の窓と、書き出しに添える CREDITS.txt）に出す名前・作者・出どころ・ライセンスは、`game/credits.csv` に 1 行ずつ置いてある（`docs/credits.md`）。ここの素材を足したら、そこにも足す。

- 作者: spring-spring（OpenGameArt のユーザー。https://opengameart.org/users/spring-spring ）
- 配布元: Magic Words + Healing Sound Effect — https://opengameart.org/content/magic-words-healing-sound-effect
- ライセンス: CC0 1.0（`LICENSE.txt`）。配布元のページの「License(s)」が CC0
- 取ってきた日・ライセンスを確かめた日: 2026-11-15
- 改変: 配布元の WAV を、モノラルの Ogg Vorbis（品質 3）にし、後ろを切って短いフェードで消した

| ファイル | 使う音（`game/sound_catalog.gd`） | 元のファイル | 長さ |
| --- | --- | --- | --- |
| `health_restore.ogg` | `level_up`（レベルが上がった。配布元の説明では「竪琴のような音」） | `health_restore.wav` | 3.04 → 1.8 秒 |
