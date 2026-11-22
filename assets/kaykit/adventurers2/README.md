# KayKit : Adventurers 2.0 と Character Animations 1.1

駒の見た目の組「人形 2」（`game/looks/kaykit2_look.gd`）の素材。

- 作者: Kay Lousberg（https://www.kaylousberg.com）
- ライセンス: CC0 1.0（`LICENSE.txt`。商用・改変・再配布が自由で、クレジット表記は任意）
- 入手元: 作者の配布元（https://kaylousberg.itch.io/）は、このコンテナの通信で取れなかった。作者の「The Complete KayKit Collection v6」を
  そのまま置いた GitHub の写し https://github.com/GeorgeQLe/assets-kaykit-3d-characters （コミット `af08a62`）から取った。
  `LICENSE.txt` は、その写しの `LICENSES/KayKit-CC0-License.txt`（作者がコレクションに入れたライセンスの文。CC0 と、作者の名前・作成日が書いてある）をそのまま置いた。
  作者の GitHub（https://github.com/KayKit-Game-Assets）に 2.0 は無い（1.0 だけ。「人形」の組の `assets/kaykit/adventurers/` はそこから取った）。
- 取ってきた日・ライセンスを確かめた日: 2026-11-22
- 改変: なし（ファイルは無改変。陣営の色と髪の色の塗り替え、頭の付け替え、持ち物の付け所は実行時にしている）

## 人物（写しの `assets/kaykit/adventurers-2.0/Characters/gltf/`）

どれも同じ骨組み（`Rig_Medium`、骨 23 本）で、体が部品（頭・兜・帽子・マント・腕・脚・背負い物）に分かれている。テクスチャは中に入っている
（`*_<人物>_texture.png` は Godot が取り込むときに取り出したもの。中身は同じ）。

| ファイル | 使い道（`kaykit2_look.gd` の `KINDS`・`PERSONS`） |
| --- | --- |
| `Knight.glb` | 将・シールドトルーパー・パラディン。ハーデン・ドーソン・イェルダ・ヴァルト・教導隊員の体。ティオの頭（若い顔） |
| `Rogue.glb` | ノエ・セリスの体。マルタ・イェルダ・ヴァルト・教導隊員の頭（女の頭） |
| `Rogue_Hooded.glb` | コマンドー（覆面の頭巾）。ピップの体 |
| `Mage.glb` | ソーサラー。ウル・ティオの体。セリスの頭（長い黒髪） |
| `Ranger.glb` | スナイパー。ピップの頭 |
| `Engineer.glb` | 衛生兵（背負い物）。マルタの体。ドーソンの頭（ひげ） |
| `Barbarian.glb` | スペルブレード（熊の帽子）。ウルの頭（禿げ頭と白いひげ） |
| `Druid.glb` | プリースト |

## props/（写しの `assets/kaykit/adventurers-2.0/Assets/gltf/`）

手の付け所の骨（`handslot.r`・`handslot.l`）に付ける持ち物。`.gltf` と `.bin` と、絵（人物と同じ `*_texture.png`。持ち物はこれを外から読む）。

| ファイル | 使い道 |
| --- | --- |
| `sword_1handed` | シールドトルーパー・パラディン・ドーソン・イェルダ・教導隊員 |
| `sword_2handed` | 将・スペルブレード・セリス |
| `shield_square` | シールドトルーパー・教導隊員 |
| `shield_badge` | パラディン・ドーソン・イェルダ |
| `shotgun` | スナイパー・ノエ・ヴァルト（連邦の長い銃） |
| `dagger` | コマンドー・ピップ（2 本） |
| `potion_medium_red` | 衛生兵・マルタ |
| `staff` | ソーサラー・ウル |
| `wand` | ティオ |
| `spellbook_open` | ウル |
| `druid_staff` | プリースト |
| `*_texture.png`（7 つ） | 上の持ち物の絵 |

## animations/（Character Animations 1.1。写しの `assets/kaykit/character-animations-1.1/Animations/gltf/Rig_Medium/`）

人物のファイルは動きを持たないので、同じ骨組みの動きのファイルを実行時に体に足す（`kaykit2_look.gd` の `ANIMATION_FILES`）。

| ファイル | 使う動き |
| --- | --- |
| `Rig_Medium_General.glb` | Idle_A（立つ）・Hit_A（被弾）・Death_A（倒れる）・Interact（身ぶり） |
| `Rig_Medium_MovementBasic.glb` | Running_A（走る） |
| `Rig_Medium_CombatMelee.glb` | 剣・短剣の攻撃、両手剣の構え |
| `Rig_Medium_CombatRanged.glb` | 銃の構えと射撃、魔法の攻撃 |
