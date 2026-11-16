# KayKit : Character Pack : Skeletons 1.0

- 作者: Kay Lousberg（https://www.kaylousberg.com）
- 入手元: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 （コミット 15b62b9）
- ライセンス: CC0 1.0（`LICENSE.txt`。入手元の `LICENSE.txt` をそのまま）。商用・改変・再配布が自由で、クレジット表記は任意
- 取ってきた日・ライセンスを確かめた日: 2026-11-16
- 改変: なし（ファイルは無改変。陣営の色への塗り替えは、実行時にテクスチャの差し色の部分だけを書き換えている）

入れたもの（`addons/kaykit_character_pack_skeletons/` の下から。使う分だけ）:

| ファイル | 元のパス | 使い道（`game/unit_view.gd`） |
| --- | --- | --- |
| `Skeleton_Minion.glb` | `Characters/gltf/` | 骸骨兵（`skeleton_minion`） |
| `Skeleton_Rogue.glb` | `Characters/gltf/` | 骸骨射手（`skeleton_rogue`） |
| `Skeleton_Warrior.glb` | `Characters/gltf/` | 骸骨重兵（`skeleton_warrior`） |
| `Skeleton_Blade.gltf` / `.bin` | `Assets/gltf/` | 骸骨兵の剣（`HELD_PROPS` の `blade`） |
| `Skeleton_Crossbow.gltf` / `.bin` | `Assets/gltf/` | 骸骨射手のクロスボウ（`crossbow`） |
| `Skeleton_Axe.gltf` / `.bin` | `Assets/gltf/` | 骸骨重兵の斧（`axe`） |
| `Skeleton_Shield_Large_A.gltf` / `.bin` | `Assets/gltf/` | 骸骨重兵の大盾（`large_shield`） |
| `skeleton_texture.png` | `Assets/gltf/` | 武器の `.gltf` が読むテクスチャ |

キャラクターの `.glb` には 95 個のアニメーションが入っているが、武器・盾は入っていない（別のファイル）。
武器は、`unit_view.gd` が手の骨（`handslot.r` / `handslot.l`）に付ける。

`Skeleton_*_skeleton_texture.png` とその `.import` は、Godot が `.glb` を取り込むときに中から取り出したもの（中身は `skeleton_texture.png` と同じ）。
エディタを開くたびに作られるので、差分が出ないようにコミットしてある。
