# Kenney : Mini Characters 2.0

駒の見た目の組「ミニ」（`game/looks/mini_look.gd`）の素材。

- 作者: Kenney（https://www.kenney.nl）
- 配布元: https://opengameart.org/content/mini-characters （`kenney_mini-characters_2.0.zip`。投稿者は作者本人）
- ライセンス: CC0 1.0（`LICENSE.txt`。zip に入っていた `License.txt` をそのまま置いた。配布元のページの「License(s)」も CC0）。商用・改変・再配布が自由で、クレジット表記は任意
- 取ってきた日・ライセンスを確かめた日: 2026-11-21
- 改変: なし（`Models/GLB format/` の GLB のまま）。陣営の色への塗り替えは実行時にしている（`Textures/colormap.png` の色の帯を書き換えた写しを使う。ファイルは変えない）

人物はどれも同じ骨（7 本）と 32 の動き（idle・walk・attack-melee-right・holding-right-shoot・die・emote-yes など）を持つ。被弾の動きは無い。
絵は全部の人物と小物で共通の 1 枚（`Textures/colormap.png`。GLB が外のファイルとして指す）。

| ファイル | 使い道（`mini_look.gd` の `KINDS`・`ITEMS`） |
| --- | --- |
| `character-knight.glb` | 将（大きく）、パラディン |
| `character-soldier.glb` | シールドトルーパー |
| `character-female-c.glb` | スナイパー |
| `character-raider.glb` | コマンドー |
| `character-female-e.glb` | 衛生兵 |
| `character-male-b.glb` | プリースト |
| `character-female-a.glb` | スペルブレード |
| `character-female-d.glb` | ソーサラー |
| `weapon-sword.glb` | 剣 |
| `weapon-bow.glb` | 弓 |
| `weapon-shooter.glb` | 銃 |
| `shield-round.glb`・`shield-rectangle.glb` | 盾 |
| `aid-defibrillator-red.glb` | 救急の道具（衛生兵） |

魔法の杖（ソーサラー・プリースト）は素材に無いので、コードで組んでいる（素材ではない）。
魔物（骸骨）はこの組でも Quaternius の骸骨（`assets/quaternius/monsters/`。`game/looks/quaternius_skeleton.gd`）を使う。
前は代わりにゾンビ・ロボット・宇宙人と杖（`aid-cane`）を入れていたが、骸骨に替えたので外した（2026-11-21）。
