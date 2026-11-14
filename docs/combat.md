# 戦闘

コード: `rules/combat.gd`（射程・ダメージ）、`rules/actions/attack_action.gd`（攻撃の行動）、
`rules/events/unit_damaged_event.gd`、`rules/events/unit_defeated_event.gd`。
テスト: `tests/rules/test_combat.gd`。

## 攻撃できる相手

- 射程はマンハッタン距離（上下左右の歩数。斜め隣は 2）。射程以内の駒を攻撃できる。
- 地形は射程を遮らない（壁越しに撃てる）。
- 攻撃できるのは敵の駒だけ。中立の駒は両プレイヤーの敵。味方は攻撃できない。
- 回復役（衛生兵・プリースト）は攻撃しない。かわりに味方を回復する（`docs/healer-role.md`）。
- 射程内の起爆樽も攻撃できる。行動は別（`AttackBarrelAction`）で、爆発のダメージの決まりも別（`docs/map-objects.md`）。

## ダメージ

- 攻撃側の攻撃力がそのままダメージになる。
- 守る側が森にいれば 0.8 倍（端数切り捨て）。
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

## まだ入れていないもの

確定クリティカル、被ダメージを無効にするバリア、範囲魔法、煙幕、盾（バリケード）は、
それぞれのスキルの仕様と一緒に入れる。
