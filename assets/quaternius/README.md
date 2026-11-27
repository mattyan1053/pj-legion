# Quaternius

クレジット（タイトルの「クレジット」の窓と、書き出しに添える CREDITS.txt）に出す名前・作者・出どころ・ライセンスは、`game/credits.csv` に 1 行ずつ置いてある（`docs/credits.md`）。ここの素材を足したら、そこにも足す。

骸骨でない魔物（`monsters/` の Bat・Slime・Dragon と、`cute/` の Crab・Mushroom）と骸骨旗手（`monsters/` の Skeleton）の素材（`game/looks/monster_body.gd`、`game/looks/quaternius_skeleton.gd`）。
2026-11-25 に、駒の見た目の組「人物」を外したので、その組だけが使っていた `characters/`（Ultimate Animated Character Pack）と `weapons/`（RPG Characters の武器）を消した。

- 作者: Quaternius（https://quaternius.com）
- ライセンス: CC0 1.0（`LICENSE.txt`。前に入れていた RPG Characters の zip に入っていた `License.txt` をそのまま置いた）。商用・改変・再配布が自由で、クレジット表記は任意
- 取ってきた日・ライセンスを確かめた日: 2026-11-17（配布元のページの「License(s)」が CC0 で、投稿者が作者本人であることを確かめた）
- 改変: なし（FBX のまま。陣営の色の塗り替えは実行時にしている）

## monsters/（Animated Monster Pack - Aug 2018）

- 配布元: https://opengameart.org/content/lowpoly-animated-monsters （`Animated Monster Pack by @Quaternius.zip`。投稿者は作者本人）
- ライセンス: CC0 1.0。配布元のページの「License(s)」が CC0 で、zip の `License.txt` も CC0 1.0 Universal（`monsters/LICENSE.txt` にそのまま置いた。クレジットは任意）
- 取ってきた日・ライセンスを確かめた日: 2026-11-21
- 改変: なし（FBX のまま。骨の色、旗、腰の布は実行時に付けている）
- 2026-11-23 に、同じ zip から `Bat.fbx`・`Slime.fbx` を足した（改変なし。面の色の塗り替えと、浮かせる・回すのは実行時）。
- 2026-11-23 に、同じ zip から `Dragon.fbx` を足した（改変なし。配布元のページが CC0 のままであることを取り直して確かめた）。
- 骨は 17 本（Skeleton）。腕の骨は素材の中で `L.UpperLeg.001`・`L.DownLeg.001` などの名前（脚と同じ名前に `.001` が付いたもの）。
  動きは Skeleton_Idle・Skeleton_Running・Skeleton_Attack・Skeleton_Death・Skeleton_Spawn の 5 つ。

| ファイル | 使い道 |
| --- | --- |
| `Skeleton.fbx` | 骸骨旗手（どの組でも。`game/looks/quaternius_skeleton.gd`、`game/looks/monster_body.gd`） |
| `Bat.fbx` | 大蝙蝠（どの組でも。`game/looks/monster_body.gd`）。動きは Bat_Flying・Bat_Attack・Bat_Attack2・Bat_Hit・Bat_Death |
| `Slime.fbx` | ほつれ（どの組でも。`game/looks/monster_body.gd`）。動きは Slime_Idle・Slime_Walk・Slime_Attack・Slime_Death |
| `Dragon.fbx` | 糸喰い（どの組でも。`game/looks/monster_body.gd`）。動きは Dragon_Flying・Dragon_Attack・Dragon_Attack2・Dragon_Hit・Dragon_Death |

## cute/（Cute Animated Monsters - Aug 2020。配布元のページの題は「Textured Cute Monster Pack」）

- 配布元: https://opengameart.org/content/textured-cute-monster-pack （`cute_animated_monsters_-_aug_2020.zip`。投稿者は作者本人）
- ライセンス: CC0 1.0。配布元のページの「License(s)」が CC0（本文も「free to use in personal and commercial projects」）。
  zip にライセンスの文は入っていない。CC0 1.0 の文は `LICENSE.txt`（同じ作者の RPG Characters の zip のもの）。
- 取ってきた日・ライセンスを確かめた日: 2026-11-24
- 改変: なし（FBX と絵のまま。FBX は絵を中に持たないので、実行時に貼る。絵の決まった色合いの所を陣営の色に塗り替えるのも実行時。`game/looks/team_recolor.gdshader`）
- 入れたもの: 21 体のうち 2 体（`FBX/` と `Textures/` から）。どれも骨は同じ形（MonsterArmature）。

| ファイル | 使い道（`game/looks/monster_body.gd` の `MODELS`） |
| --- | --- |
| `Crab.fbx`・`Crab_Texture.png` | 殻蟹（どの組でも）。殻の赤を陣営の色に。動きは Idle・Walk・Bite_Front・HitRecieve・Death など 10 |
| `Mushroom.fbx`・`Mushroom_Texture.png` | 糸茸（どの組でも）。笠の茶色を陣営の色に。素材の動きは Idle だけ（ほかは代わりの動き） |
