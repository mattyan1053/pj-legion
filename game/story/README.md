# ストーリーの台本

<!-- 生成物。手で書かない。話を足す・並べ替える・名前を変えたら `tools/write_story_script.sh` で作り直す。 -->

話の順に並べた目次。会話は、それぞれの話のファイルにそのまま書いてある（ここには写さない）。

- `[before]`: 対戦の前の会話。`[after]`: 勝ったあとの会話。1 行が「話し手: 文」。
- `[cues]`: 対戦の途中の台詞。頭の括弧が出るとき（`(turn 3)` はターン 3 の始め、`(fallen ally)` は味方が初めて倒れたとき、
  `(king_half enemy)` は敵の将の HP が半分を切ったとき、`(ult_ready ally)` は必殺技が使えるようになったとき）。
- 上のほうの `[episode]`・`[ally]`・`[enemy]` は、マップ・勝ち方・話し手・敵の部隊（書式は `docs/story.md` の「話のファイル」）。
- 登場人物は `docs/story.md` の「世界と登場人物」。

## ベルク連邦の物語（MILITARY）

1. （演習）[はじめの一歩](episodes/drill_first_steps.txt)
2. （演習）[撃ち合い](episodes/drill_sniper.txt)
3. （演習）[手当て](episodes/drill_medic.txt)
4. （演習）[スキルと必殺技](episodes/drill_skills.txt)
5. （演習）[結晶の番人](episodes/drill_shrine.txt)
6. （演習）[本陣を取れ](episodes/drill_capture.txt)
7. [尾根の小道](episodes/ridge_path.txt)
8. [尾根の待ち伏せ](episodes/ridge_ambush.txt)
9. [尾根の籠城](episodes/ridge_hold.txt)
10. [岩山の掃討](episodes/gorge_rout.txt)
11. [古戦場の亡者](episodes/barrow_rout.txt)
12. [墓守](episodes/barrow_knight.txt)
13. [もう一人の番人](episodes/warden_twin.txt)
14. [最後の演習](episodes/drill_last.txt)
15. [縫い目の発破](episodes/quarry_blast.txt)

## リュエル騎士領の物語（FANTASY）

1. （演習）[少数精鋭](episodes/trial_first_steps.txt)
2. （演習）[火球](episodes/trial_fireball.txt)
3. （演習）[盾と祈り](episodes/trial_ward.txt)
4. （演習）[影渡り](episodes/trial_shadow_step.txt)
5. （演習）[魔力解放](episodes/trial_eruption.txt)
6. （演習）[分かれ道](episodes/trial_evolution.txt)
7. [岩山越え](episodes/gorge_crossing.txt)
8. [岩山の合流](episodes/gorge_rejoin.txt)
9. [尾根の砦](episodes/ridge_siege.txt)
10. [古戦場の祈り](episodes/barrow_vigil.txt)
11. [骨の太鼓](episodes/crag_drums.txt)
12. [峠の番人](episodes/boulder_warden.txt)
13. [森の守り](episodes/mist_forest.txt)
14. [尾根の骨](episodes/ridge_bones.txt)
15. [墓守の眠り](episodes/vale_keeper.txt)
