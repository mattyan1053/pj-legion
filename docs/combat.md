# 戦闘

コード: `rules/combat.gd`（射程・ダメージ）、`rules/actions/attack_action.gd`（攻撃の行動）、
`rules/events/unit_damaged_event.gd`、`rules/events/unit_defeated_event.gd`。
テスト: `tests/rules/test_combat.gd`。

## 攻撃できる相手

- 射程はマンハッタン距離（上下左右の歩数。斜め隣は 2）。射程以内の駒を攻撃できる。
- 地形は射程を遮らない（壁越しに撃てる）。
- ただし、攻撃する駒と相手の間のマスに盾があると届かない（`docs/field-effects.md`。隣からの攻撃は遮られない）。
- 攻撃できるのは敵の駒だけ。中立の駒は両プレイヤーの敵。味方は攻撃できない。
- 回復役（衛生兵・プリースト）は攻撃しない。かわりに味方を回復する（`docs/healer-role.md`）。
- 射程内の起爆樽も攻撃できる。行動は別（`AttackBarrelAction`）で、爆発のダメージの決まりも別（`docs/map-objects.md`）。
- 射程内の相手の盾も攻撃できる。行動は別（`AttackBarricadeAction`。`docs/field-effects.md`）。

## ダメージ

- 攻撃側の攻撃力がそのままダメージになる。
- 守る側が森にいれば 0.8 倍（端数切り捨て）。
- 守る側が自分の陣営の煙幕の中にいて、距離 2 以上から攻撃されたら 0（`docs/field-effects.md`）。
- HP は 0 より下がらない。HP が 0 になった駒は倒れ、盤から取り除かれる。
- 反撃は無い。

## 攻撃の行動

`Battle.apply(AttackAction.new(攻撃する駒の番号, 攻撃される駒の番号))`。

- 行動できる駒が、いまの位置から攻撃する。動いたあとでも、動かずにでもよい。**巡航で動いた駒は攻撃できない。**
- 攻撃すると行動を終える。
- 返すイベントは順に、`UnitDamagedEvent`（与えたダメージと、受けたあとの HP）、
  倒れたなら `UnitDefeatedEvent`、攻撃した駒が育つなら経験値（`ExperienceGainedEvent`、上がれば `LevelUpEvent`。
  `docs/experience-levelup.md`）、最後に `UnitActedEvent`。
- `UnitDamagedEvent` のダメージは計算した値（残り HP より大きくてもそのまま）。`cause` は `ATTACK`。
- 煙幕に阻まれた攻撃は、`UnitDamagedEvent` のかわりに `SmokeBlockedEvent`。経験値は入らず、`UnitActedEvent` で終わる。
- ダメージを与える処理（`Combat.strike`）は、中立の駒の攻撃と同じものを使う。

## まだ入れていないもの

確定クリティカルと、被ダメージを無効にするバリアは、それぞれのスキルの仕様と一緒に入れる。

範囲魔法（ファイアボール）は駒の攻撃ではなく、スキルのダメージ（`docs/skills/fireball.md`、`docs/active-skills.md` の「ダメージのあるスキル」）。
ここの決まり（射程、盾の射線、森の軽減、煙幕）は通らない。
