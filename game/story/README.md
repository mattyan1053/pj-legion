# ストーリーの台本

<!-- 生成物。手で書かない。話を足す・並べ替える・名前を変えたら `tools/write_story_script.sh` で作り直す。 -->

話の順に並べた目次。会話は、それぞれの話のファイルにそのまま書いてある（ここには写さない）。

- `[before]`: 対戦の前の会話。`[after]`: 勝ったあとの会話。`[lost]`: 負けたときの台詞（決着の画面に出す）。1 行が「話し手: 文」（頭が `>` の行は地の文）。
- `[cues]`: 対戦の途中の台詞。頭の括弧が出るとき（`(turn 3)` はターン 3 の始め、`(fallen ally)` は味方が初めて倒れたとき、
  `(king_half enemy)` は敵の将の HP が半分を切ったとき、`(ult_ready ally)` は必殺技が使えるようになったとき）。
- 頭の `[episode]` は話の名前・マップ・勝ち方、`[cast]` は話し手（`ally` が遊ぶ人の軍、`enemy` が敵の軍。後ろは会話に立つ姿）。
- 「ここから下は、戦いの設定」の線より下は、部隊・初期位置・クリアで増えるもの（書式は `docs/story.md` の「話のファイル」）。
- 物語を足すときは、`_template/` のフォルダを写す（`docs/story.md` の「物語を 1 つ足す」）。
- 登場人物は `docs/story.md` の「世界と登場人物」。

## ベルク連邦の物語（MILITARY）

物語のファイル: [military/story.txt](military/story.txt)

1. （演習）[はじめの一歩](military/drill_first_steps.txt)
2. （演習）[撃ち合い](military/drill_sniper.txt)
3. （演習）[手当て](military/drill_medic.txt)
4. （演習）[スキルと必殺技](military/drill_skills.txt)
5. （演習）[結晶の番人](military/drill_shrine.txt)
6. （演習）[本陣を取れ](military/drill_capture.txt)
7. [尾根の小道](military/ridge_path.txt)
8. [尾根の待ち伏せ](military/ridge_ambush.txt)
9. [尾根の籠城](military/ridge_hold.txt)
10. [岩山の掃討](military/gorge_rout.txt)
11. [古戦場の亡者](military/barrow_rout.txt)
12. [墓守](military/barrow_knight.txt)
13. [もう一人の番人](military/warden_twin.txt)
14. [最後の演習](military/drill_last.txt)
15. [縫い目の発破](military/quarry_blast.txt)

## リュエル騎士領の物語（FANTASY）

物語のファイル: [fantasy/story.txt](fantasy/story.txt)

1. （演習）[少数精鋭](fantasy/trial_first_steps.txt)
2. （演習）[火球](fantasy/trial_fireball.txt)
3. （演習）[盾と祈り](fantasy/trial_ward.txt)
4. （演習）[影渡り](fantasy/trial_shadow_step.txt)
5. （演習）[魔力解放](fantasy/trial_eruption.txt)
6. （演習）[分かれ道](fantasy/trial_evolution.txt)
7. [岩山越え](fantasy/gorge_crossing.txt)
8. [岩山の合流](fantasy/gorge_rejoin.txt)
9. [尾根の砦](fantasy/ridge_siege.txt)
10. [古戦場の祈り](fantasy/barrow_vigil.txt)
11. [亡者の太鼓](fantasy/crag_drums.txt)
12. [峠の番人](fantasy/boulder_warden.txt)
13. [森の守り](fantasy/mist_forest.txt)
14. [尾根の亡者](fantasy/ridge_bones.txt)
15. [墓守の眠り](fantasy/vale_keeper.txt)

## 番外　縫い代の見回り（MILITARY）

物語のファイル: [berk_patrol/story.txt](berk_patrol/story.txt)

1. [岩山の蝙蝠](berk_patrol/patrol_crags.txt)
2. [ほつれた野](berk_patrol/patrol_knots.txt)
3. [針の峠](berk_patrol/patrol_needles.txt)
4. [石喰いの採掘場](berk_patrol/patrol_eaters.txt)
5. [迎えを待つ谷](berk_patrol/patrol_shells.txt)
