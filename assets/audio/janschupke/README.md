# Jan Schupke の効果音（Tinysized SFX Library）

クレジット（タイトルの「クレジット」の窓と、書き出しに添える CREDITS.txt）に出す名前・作者・出どころ・ライセンスは、`game/credits.csv` に 1 行ずつ置いてある（`docs/credits.md`）。ここの素材を足したら、そこにも足す。

- 作者: Jan Schupke（OpenGameArt のユーザー「vehicle」。https://opengameart.org/users/vehicle ）
- 配布元: Fantasy Sound Effects (Tinysized SFX) — https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx （`tinysized.zip`）
- ライセンス: CC0 1.0（`LICENSE.txt`）。配布元のページの「License(s)」が CC0 で、zip の `readme.txt` も CC0 と書いている
- 取ってきた日・ライセンスを確かめた日: 2026-11-15
- 改変: 配布元の WAV を、モノラルの Ogg Vorbis（品質 3）にし、後ろを切って短いフェードで消した

| ファイル | 使う音（`game/sound_catalog.gd`） | 元のファイル | 長さ |
| --- | --- | --- | --- |
| `sword-clash-04.ogg` | `critical`（クリティカル。当たった音に重ねる） | `sfx-cc0/sword-clash-04.wav` | 1.32 → 1.0 秒 |
