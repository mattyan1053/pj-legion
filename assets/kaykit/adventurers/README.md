# KayKit : Adventurers Character Pack 1.0

- 作者: Kay Lousberg（https://www.kaylousberg.com）
- 入手元: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 （コミット 672074b）
- ライセンス: CC0 1.0（`LICENSE.txt`）。商用・改変・再配布が自由で、クレジット表記は任意
- 入れたもの: `Characters/gltf/` の `Knight.glb` / `Barbarian.glb` / `Mage.glb` / `Rogue.glb`。**無改変**

各ファイルに武器・盾などの小物と 76 個のアニメーションが入っている。
使う小物の出し分けは `game/unit_view.gd` でやっている。

`*_texture.png` とその `.import` は、Godot が `.glb` を取り込むときに中から取り出したもの（中身は同じ）。
エディタを開くたびに作られるので、差分が出ないようにコミットしてある。
陣営の色への塗り替えは、実行時にこのテクスチャの差し色の部分だけを書き換えている（ファイルは変えない）。
