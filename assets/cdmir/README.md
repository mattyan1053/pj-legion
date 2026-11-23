# CDmir

魔物の糸蜘蛛の体（`game/looks/monster_body.gd` の `MODELS`）の素材。どの見た目の組でも同じ形。

- 作者: CDmir（OpenGameArt の投稿者。作者と投稿者が同じ）
- 配布元: https://opengameart.org/content/alien-bug-animated （`alien-bug.zip`）
- ライセンス: CC0 1.0。配布元のページの「License(s)」が CC0（作者の集め「All CC0 - Uploader: CDmir」にも入っている）。
  zip にライセンスの文は入っていないので、配布元のページの表記を `LICENSE.txt` に書き写した。クレジットは不要
- 取ってきた日・ライセンスを確かめた日: 2026-11-23
- 改変: なし（`alien-bug.glb` のまま。体の絵に糸の色を掛けるのは実行時）。
  `alien-bug_bug-*.png` は、Godot が取り込みのときに glb の中の絵を書き出したもの（中身は glb と同じ）。
- 入れなかったもの: zip の `bug.blend` と `tex/`（glb が同じ絵を中に持つ）。

| ファイル | 元の名前 | 使い道 |
| --- | --- | --- |
| `alien-bug/alien-bug.glb` | `alien-bug.glb` | 糸蜘蛛（`UnitKind.Id.SPIDER`）。動きは Idle・Run・Attack.000・Attack.001（倒れる動きは無い） |
