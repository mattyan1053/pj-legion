# ターンと行動の流れ

コード: `rules/battle.gd`（ターン・フェーズ・行動中の駒）、`rules/actions/`（`wait_action.gd`、`undo_move_action.gd`、
`end_phase_action.gd`）、`rules/events/`（`phase_started_event.gd`、`unit_acted_event.gd`、`move_undone_event.gd`）。
テスト: `tests/rules/test_turn.gd`。

## ターンとフェーズ

- 対戦はターン 1、プレイヤー1 のフェーズから始まる。
- 1 ターンは **プレイヤー1 → プレイヤー2 → 中立** のフェーズで進み、中立のあとはターンが 1 進んでプレイヤー1 に戻る。
- プレイヤーのフェーズは「ターン終了」（`EndPhaseAction`）でだけ終わる。全部の駒が行動を終えても自動では終わらず、
  未行動の駒が残っていても終えてよい。
- プレイヤー2 のフェーズを終えると、中立のフェーズを続けて進め、次のターンのプレイヤー1 のフェーズまで一度に進む。
  中立のフェーズでは、中立の駒が自分で動いて攻撃し、結晶泉に新しく湧き、中ボスが現れる（`docs/neutral-minion.md`、`docs/neutral-mid-boss.md`）。
  中立の駒の攻撃で決着したら、そこで止まる（次のターンへは進まない）。
- フェーズが始まるたびに `PhaseStartedEvent`（ターン番号と、どの陣営の番か）が出る。
- プレイヤーのフェーズの始めに、回復の泉に乗っているそのプレイヤーの駒が HP を 12（`MapObject.SPRING_HEAL`）まで回復する（最大 HP を超えるぶんは切り捨て。`docs/map-objects.md`）。
  続けて、再生の特性を持つ進化先の駒が回復する（`docs/branch-evolution.md`）。
  そのあと、そのプレイヤーの聖域の中の駒が回復し、そのプレイヤーの煙幕・聖域の残りのターン数が 1 減る（`docs/field-effects.md`）。
  続けて、そのプレイヤーの駒に付いている状態の残りのターン数が 1 減り、0 になった状態は外れる（`docs/unit-statuses.md`）。
  続けて、そのプレイヤーの駒のスキルのクールダウンが 1 減る（`docs/active-skills.md`）。
  最後に、そのプレイヤーの必殺技のゲージがたまる（`docs/tactical-ult.md`）。
- 必殺技（`UseUltAction`）は、自分のフェーズの間ならいつでも、ゲージがいっぱいのときに使える。駒の行動ではなく、どの駒の行動も使わない。

## 駒の行動

- 自分のフェーズに、行動済みでない自分の駒が、1 体ずつ行動する。中立の駒はプレイヤーが動かせず、中立のフェーズにルールが動かす。
- 1 回の行動は「移動（1 回まで。動かなくてもよい）→ 攻撃・回復・スキル・待機のどれか」。
  行動を終えないスキル（シャドウステップ）だけは、「移動 → スキル → 攻撃・待機のどれか」になる（`docs/active-skills.md`）。
  - **待機**（`WaitAction`）: 行動を終え、行動済みになる（`UnitActedEvent`）。
  - **移動の取り消し**（`UndoMoveAction`）: 動いたあと、攻撃も回復もスキルも待機もしていなければ、動く前のマスへ戻り、行動前に戻る（`MoveUndoneEvent`）。動いて外れた照準と、動いて 0 に戻った本陣の占拠の数も戻る（`docs/unit-statuses.md`、`docs/win-conditions.md`）。
    行動を終えないスキルを使ったあとは、取り消せない。
  - **攻撃**（`AttackAction`）: 射程内の敵 1 体を攻撃し、行動済みになる（`docs/combat.md`）。巡航で動いた駒は攻撃できない。
    射程内の起爆樽も攻撃できる（`AttackBarrelAction`。`docs/map-objects.md`）。相手の盾も同じ（`AttackBarricadeAction`。`docs/field-effects.md`）。
  - **回復**（`HealAction`）: 回復役が射程内の味方 1 体を回復し、行動済みになる（`docs/healer-role.md`）。巡航で動いた駒は回復できない。
  - **スキル**（`UseSkillAction`）: 駒の種類ごとのスキルを使い、行動済みになる（`docs/active-skills.md`）。
    クールダウンが残っている駒、使える回数を使い切った駒、巡航で動いた駒は使えない。行動を終えないスキルもある。
- 駒が動いてから行動を終えるまでの間（行動の途中）は、ほかの駒は行動を始められない。
- 行動の途中の駒がいるままフェーズを終えると、その駒は待機したことになる。
- 行動済みの駒は、自分の次のフェーズの始めに行動前に戻る（相手のフェーズでは戻らない）。
  アドレナリン注射（`docs/skills/adrenaline-shot.md`）を受けた駒は、同じフェーズの中で行動前に戻り、もう一度、移動から行動できる（`UnitReactivatedEvent`）。
