# 兵の見た目の組を足す

兵の見た目の組（`docs/battle-view.md` の「駒の見た目の組」）を、新しい素材で 1 つ足すときの受け皿。
いまの組は「人形」（`kaykit`）の 1 つだけ（ほかの組は 11/25 に外した）。組を替える仕組み（`game/unit_looks.gd` の `SETS`、`game/looks/look_set.gd`）は残してある。
ありものの素材でも、生成の道具（Tripo など）で作った素材でも同じ手順。生成の道具そのものは、このリポジトリの道具に入れない。

## 入れる前に確かめること

- **再配布してよいか。** リポジトリは public で、exe にも埋め込む。生成の道具で作ったものは、その道具の利用の条件で
  「作った物を public のリポジトリに置き、改変して、ゲームに入れて配ってよい」ことを確かめる（料金のプランで条件が変わる道具が多い。
  無料の枠では作った物が公開・CC BY などになる、など）。確かめた条件の文（ページの URL と、確かめた日）を `assets/<出どころ>/README.md` に書く。
- **出どころ**: ありものは作者・配布元・ライセンス（`add-asset` のスキル）。生成の物は、道具の名前・版、作った日、元にした絵や文
  （自分で書いた指示か、他人の絵を元にしていないか）。他人の絵やキャラクターを元にした物は入れない。
- 条件がはっきりしない物は入れない。入れる PR は自分でマージせず、人間に見てもらう（`CLAUDE.md` の「Git」）。
- **大きさ**: 素材の合計（`assets/`）はいま 100 MB 前後。1 つの組で増やすのは 15 MB まで。
  人物 1 人の GLB は 1 MB 前後を目安にする（絵は 512 px 程度に縮め、表情の形（blend shape）など使わない物は外す）。

## 組に要るもの

- **人物ごとの GLB**（`assets/<出どころ>/`）。兵種 9 種（`UnitKind` の将・前衛・後衛・奇襲・回復）と、
  名前のある人物 11 人（`game/unit_looks.gd` の `PERSONS`）を描き分けられる数。足りない人物は、髪の色・持ち物・大きさの替えで分ける。
  魔物と将の別の姿（`UnitLooks.KING_LOOKS`）は、「人形」の組のもの（KayKit の骸骨。`kaykit_look.gd` の `KINDS` と `KING_LOOKS`）を借りてよい。
- **骨組み**: 人の形の骨（腰・背・胸・頭・両腕 3 本・両脚 3 本）。足元が原点で、+Z が前。向きが違えば組の中で回す。
- **動き**: 立つ・走る・攻撃（種類ごと）・被弾・倒れる・身ぶりの 6 つ（`game/looks/model_body.gd` の動きの名前の表）。
  素材に無い動きは、次のどちらか。
  - 同じ骨組みの動きのファイルを、体に足す（AnimationLibrary を読み、体の AnimationPlayer に足す。前にあった「人形 2」の組は、
    KayKit Character Animations の `Rig_Medium` をこうして足していた）。
  - 骨組みが違う人の形なら、動きの付いた別の人の形の骨組みを隠して動きを回し、骨ごとの回り（休みの姿からの差）を毎コマ写す。
    VRoid の見本と KayKit 2.0 の骨組みで試し、立つ・走る・攻撃とも崩れずに動いた（Issue #46 の 11/23 の候補探し）。持ち物は、写した手の位置に、元の骨組みの付け所の向きで置く。
- **陣営の色**: 服の一部（外套・帽子・腰の布など、上から見える所）を陣営の色に塗る。足元の円盤だけでは、盤の上で敵味方を見分けにくい。
  絵の色見本を塗り替える（`kaykit_look.gd` の `accent`）か、面の色を掛け合わせる。
- **大きさ**: 体を足元の円盤（`unit_view.gd` の `BASE_RADIUS`）に収め、体の高さ（`body_height`）を正しく返す。将の冠をその高さに置く。

## 足すファイル

- `game/looks/<組>_look.gd`: `look_set.gd` を継ぎ、`build`・`has_person`・`icon_dir` を書く。
- `game/unit_looks.gd`: `SETS` に足す（既定の組 `DEFAULT` は替えない）。
- 組が 2 つ以上になったら、オプションの「兵の見た目」の行を戻す: `game/settings.gd` の `ITEMS` に選択肢（値は組の並びの番号。前の版が書いた
  `unit_look` の値と食い違わないよう、番号は 0 = `kaykit` から振り直してよい）、`game/text/menus.csv` の項目と選択肢の名前（`settings.unit_look.<組>`）、
  `game/app.gd` の `go` で場面を作るときに `UnitLooks.use` を呼ぶ（場面の途中では替えない）、`docs/system-menu.md` の表の行。
- `assets/<出どころ>/README.md` と `LICENSE.txt`（`add-asset` のスキル）。
- アイコン: `tools/unit_icons.sh godot <組>` で `assets/unit_icons/<組>/` に書く（兵種・陣営・進化の前後、人物、将の別の姿）。
- `docs/battle-view.md` の「駒の見た目の組」に、組の 1 項目（素材・種類ごとの形・人物の描き分け・陣営の色）。

`tests/game/test_unit_looks.gd` が、どの組も全部の兵種と人物の体を作れること・アイコンがそろうことを確かめる（`SETS` の全部を回すので、足した組も見る）。
人間に見てもらう絵は、`tools/screenshots.sh godot <出力> wide,story_start,story_rivals_ridge,battle_unit_detail --unit-look=<組>`（盤の全景・寄り・会話・ステータスの窓とアイコン）。
