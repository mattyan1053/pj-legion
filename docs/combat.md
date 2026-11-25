# 戦闘

コード: `rules/combat.gd`（射程・ダメージ）、`rules/hit.gd`（ダメージの解決）、`rules/actions/attack_action.gd`（攻撃の行動）、
`rules/events/unit_damaged_event.gd`、`rules/events/attack_damaged_event.gd`、`rules/events/smoke_blocked_event.gd`、`rules/events/unit_defeated_event.gd`。
テスト: `tests/rules/test_combat.gd`、`tests/rules/test_statuses.gd`（解決への割り込み）。

## 攻撃できる相手

- 射程はマンハッタン距離（上下左右の歩数。斜め隣は 2）。射程以内の駒を攻撃できる。
- 地形は射程を遮らない（壁越しに撃てる）。
- ただし、攻撃する駒と相手の間のマスに盾があると届かない（`docs/field-effects.md`。隣からの攻撃は遮られない）。
- 攻撃できるのは敵の駒だけ。中立の駒は両プレイヤーの敵。味方は攻撃できない。
- 回復役（衛生兵・プリースト）の攻撃は、回復量でなく回復役の攻撃の強さで当たる（`docs/healer-role.md` の「回復役の攻撃」）。
- 魔物の殻蟹は、距離 2（`RANGED_DISTANCE`）以上からの攻撃では狙えない（`docs/monsters.md`）。
- 射程内の起爆樽も攻撃できる。行動は別（`AttackBarrelAction`）で、爆発のダメージの決まりも別（`docs/map-objects.md`）。
- 射程内の相手の盾も攻撃できる。行動は別（`AttackBarricadeAction`。`docs/field-effects.md`）。

## ダメージ

- 攻撃側の攻撃力がそのままダメージになる。
- **確定クリティカル**: 攻撃側に照準（`docs/unit-statuses.md`）が付いていれば、攻撃力に照準の倍率を掛ける
  （倍率は `docs/skills/precision-aim.md`）。倍率を掛けるのは一時的な補正（突撃・注射）の前の攻撃力で、一時的な補正はそのあとに足す。
  攻撃を 1 回すると、照準は消える。
- 守る側が森にいれば 80%（`FOREST_DAMAGE_RATE_PERCENT`）にする（端数切り捨て。クリティカルの倍率を掛けたあと）。
- 攻撃側が、敵の糸茸の周り 8 マスにいれば、隊列（部隊の特徴）のあとに胞子のぶんを引く（0 より下にはならない。`docs/monsters.md`）。
- 守る側が自分の陣営の煙幕の中にいて、距離 2（`RANGED_DISTANCE`）以上から攻撃されたら 0（`docs/field-effects.md`）。
- **バリア**: 守る側にバリア（`docs/unit-statuses.md`）が付いていれば 0。バリアは、その 1 回で消える。
  煙幕に阻まれた攻撃は、バリアまで届かない（バリアは残る）。
- HP は 0 より下がらない。HP が 0 になった駒は倒れ、盤から取り除かれる。
- 反撃は無い。

## 攻撃の行動

`Battle.apply(AttackAction.new(攻撃する駒の番号, 攻撃される駒の番号))`。

- 行動できる駒が、いまの位置から攻撃する。動いたあとでも、動かずにでもよい。**巡航で動いた駒は攻撃できない。**
- 攻撃すると行動を終える。
- 返すイベントは順に、`AttackDamagedEvent`（`UnitDamagedEvent` の子。与えたダメージと、受けたあとの HP。`critical`、`forest`、`blocked_by`、`attacker_id`）、
  バリアが防いだなら守る側の `StatusRemovedEvent`（`CONSUMED`）、照準で撃ったなら攻撃側の `StatusRemovedEvent`（`CONSUMED`）、
  倒れたなら `UnitDefeatedEvent`（中ボスなら続けて `MidBossDefeatedEvent` と、聖遺物を受け取れば `RelicGainedEvent`。`docs/neutral-mid-boss.md`、`docs/relic-buff.md`）、
  攻撃した駒が育つなら経験値（`ExperienceGainedEvent`、上がれば `LevelUpEvent`、最大のレベルに届けば `EvolutionOfferedEvent`。
  `docs/experience-levelup.md`）、最後に `UnitActedEvent`。
  そのあとに `Battle.apply` が、決着（`GameWonEvent` など。`docs/win-conditions.md`）と `UltReadyEvent` を足す（`docs/battle.md`）。
- `UnitDamagedEvent` のダメージは計算した値（残り HP より大きくてもそのまま）。`cause` は `ATTACK`。
- 煙幕に阻まれた攻撃は、`AttackDamagedEvent` のかわりに `SmokeBlockedEvent`。照準は外れる（攻撃側の `StatusRemovedEvent`）。経験値は入らず、`UnitActedEvent` で終わる。
- ダメージを与える処理（`Combat.strike`）は、中立の駒の攻撃と同じものを使う。

## ダメージの解決（割り込む仕組み）

**駒の HP を減らすものは、原因が何でも、1 回ぶんずつ `Hit`（`rules/hit.gd`）を通す。** 計算と適用に分かれている。

- 計算（状態を変えない）: `Combat.hit(対戦, 攻撃する駒, 相手)`、`MapObject.blast_hit(駒)`、`Hit.resolve(与えた駒, 受ける駒, 量, 原因)`。
  返ってくる `Hit` に、実際に減る量（`amount`）、あとの HP（`hp_after`）、確定クリティカルか（`critical`）、
  防いだ状態（`blocked_by`）、阻んだ煙幕（`smoke`）が入っている。
- 適用: `Hit.apply()`。HP を減らし、防いだ状態を外す。ダメージのイベントは、適用した `Hit` から作る。
  実際に減った HP（`lost`。残りの HP を超えたぶんは入らない）も入る。必殺技のゲージは、これでたまる（`docs/tactical-ult.md`）。

| 原因 | 入口 | 通る段（上から順に） |
| --- | --- | --- |
| 駒の攻撃（プレイヤーの駒、中立の駒） | `Combat.hit` / `Combat.strike` | 煙幕 → 攻撃力（確定クリティカル）→ 部隊の特徴で足すもの（集中砲火・仇討ち・誓い・単騎。`docs/troop-traits.md`）→ 森 → 部隊の特徴で引くもの（隊列）→ 胞子（糸茸）→ 受ける側の状態 |
| 起爆樽の爆発 | `MapObject.blast_hit` | 固定の量 → 受ける側の状態 |
| スキルのダメージ | `Skills.deal_damage` | スキルが決めた量 → 受ける側の状態 |

- **受ける側の状態**（バリア）は `Hit.resolve` の中にあり、どの原因にも同じに効く。
- **攻撃する側の割り込み**（確定クリティカル）は、駒の攻撃だけのものなので `Combat.hit` が、`Hit.resolve` に渡す前の量に掛ける
  （`Combat.attack_power`。盾への攻撃も同じ値を使う）。
- **予測と CPU** は、計算だけを呼ぶ（`Combat.damage`、`MapObject.blast_damage` は `Hit` の `amount`）か、
  複製の上で適用まで走らせる（戦闘予測 `Forecast`。`docs/battle-forecast.md`。CPU の先読み）。どちらも同じ `Hit` を通るので、
  実際と同じ結果になる。`Hit`（とダメージのイベント）は、クリティカルか・森で減ったか・胞子で減ったか・何に防がれたかを持つ。
- 同時に当たるダメージ（爆発、スキル）は、全員ぶんのダメージのイベントを並べたあとに、状態が外れるイベント、倒れた駒、の順。

### 後で足すものの置き場所

- **隣の味方の身代わり**（`docs/branch-evolution.md` で見送ったもの）: `Hit.resolve` の最初の段として、受ける駒（`Hit.target`）を
  差し替える。あとの段（バリアなど）は、差し替えたあとの駒で見る。イベントは `Hit` から作るので、実際に受けた駒が載る。
  森の軽減と煙幕は `Combat.hit` が先に見ているので、「どちらの駒のマスで測るか」を決めて、差し替えを `Combat.hit` の前へ出すか、
  森と煙幕を `Hit.resolve` の段へ移すことになる。
- **ノックバック**: `Hit` に「押し出す先」を足し、計算で決め、`Hit.apply` のあとに呼ぶ側が動かす（倒れた駒を取り除くのと同じ位置）。
  予測は、同じ `Hit` から押し出す先を読める。
- **被ダメージを減らす特性・状態**（割合や固定値）: `Hit.resolve` の「受ける側の状態」の段に足す。

範囲魔法（ファイアボール）は駒の攻撃ではなく、スキルのダメージ（`docs/skills/fireball.md`、`docs/active-skills.md` の「ダメージのあるスキル」）。
射程、盾の射線、森の軽減、煙幕は通らない。バリアは通る。
