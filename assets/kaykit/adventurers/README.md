# KayKit : Adventurers Character Pack 1.0

クレジット（タイトルの「クレジット」の窓と、書き出しに添える CREDITS.txt）に出す名前・作者・出どころ・ライセンスは、`game/credits.csv` に 1 行ずつ置いてある（`docs/credits.md`）。ここの素材を足したら、そこにも足す。

- 作者: Kay Lousberg（https://www.kaylousberg.com）
- 入手元: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 （コミット 672074b）
- ライセンス: CC0 1.0（`LICENSE.txt`）。商用・改変・再配布が自由で、クレジット表記は任意
- 入れたもの: `addons/kaykit_character_pack_adventures/Characters/gltf/` の `Knight.glb` / `Barbarian.glb` / `Mage.glb` / `Rogue.glb` / `Rogue_Hooded.glb`。**無改変**
- `Rogue_Hooded.glb`（3.5 MB）は 2026-11-22 に同じコミット（672074b）から取ってきた。ライセンスは入手元の `LICENSE.txt`（リポジトリの直下と `addons/kaykit_character_pack_adventures/` の下の 2 つ。どちらも CC0 1.0 で、ここの `LICENSE.txt` と同じ文）を同じ日に確かめた

| ファイル | 使い道（`game/looks/kaykit_look.gd`） |
| --- | --- |
| `Knight.glb` | 将・盾兵・パラディン。ドーソン・イェルダ・ヴァルト・教導隊員の体 |
| `Barbarian.glb` | スペルブレード。ドーソンとウルの頭（禿げ頭とひげ） |
| `Mage.glb` | ソーサラー・メディック・プリースト。マルタとウルの体 |
| `Rogue.glb` | スナイパー・コマンドー。マルタ・イェルダ・セリス・ヴァルト・教導隊員の頭（髪の長い女の頭）、セリスの体 |
| `Rogue_Hooded.glb` | ピップ（頭巾の軽装。`rogue_hooded`） |

名前のある人物の形は、これらのキャラクターの部品（頭・兜・帽子・小物）を、実行時に付け替えて組む（ファイルは変えない）。
どのキャラクターも同じ骨組み（骨 41 本、名前と並びが同じ）なので、部品をそのまま付け替えられる。

各ファイルに武器・盾などの小物と 76 個のアニメーションが入っている。
使う小物の出し分けは `game/looks/kaykit_look.gd` でやっている。

`*_texture.png` とその `.import` は、Godot が `.glb` を取り込むときに中から取り出したもの（中身は同じ）。
エディタを開くたびに作られるので、差分が出ないようにコミットしてある。
陣営の色への塗り替えは、実行時にこのテクスチャの差し色の部分だけを書き換えている（ファイルは変えない）。
