# 盤の上の効果（盾、煙幕、聖域、結び目）

コード: `rules/field_effect.gd`（効果 1 つの状態）、`rules/field_effects.gd`（置く・消す・期間を進める処理と、効果の計算。調整値）、
`rules/board.gd`（どこに何があるか）、`rules/combat.gd`（射線と煙幕）、`rules/actions/attack_barricade_action.gd`、
`rules/events/`（`field_effect_placed_event.gd`、`barricade_placed_event.gd`、`area_effect_placed_event.gd`、
`field_effect_ticked_event.gd`、`field_effect_removed_event.gd`、`barricade_damaged_event.gd`、`smoke_blocked_event.gd`、
`sanctuary_healed_event.gd`、`knot_placed_event.gd`）、`rules/monsters.gd`（結び目を置く・ほどく・立ち直る）。
テスト: `tests/rules/test_field_effects.gd`、`tests/rules/test_monster_falls.gd`。

スキルが盤のマスに一定の間だけ置くもの（結び目だけは、倒れた魔物が残す。`docs/monsters.md`）。ここにあるのは効果の側の約束だけで、**誰が・いつ・どこへ置くか（スキル、クールダウン）は
スキルの側が決める**（`docs/active-skills.md`、`docs/skills/`）。

## 層

- 地形とも環境オブジェクト（`docs/map-objects.md`）とも別の層。置いても地形とオブジェクトは変わらない（森の上の煙幕は、森のまま）。
- 盤面（`Board.field_effects`）が持つ。対戦の複製（`Battle.clone()`）では効果ごと別になり、番号の採番も同じ続きになる。
- 効果は番号（`FieldEffect.id`）で指す。1 から、置いた順に振る。
- 問い合わせ: `Board.field_effects_at(マス)`（そのマスの効果。番号の小さい順）、`Board.barricade_at(マス)`、`Board.field_effect_by_id(番号)`。
  効果の種類（`type`）、持ち主の陣営（`side`）、入れるか（`is_walkable()`）、射線を遮るか（`blocks_line_of_fire()`）を持つ。

| 種類 | 広さ | 入れるか | 射線 | 消えるとき | 効果 |
| --- | --- | --- | --- | --- | --- |
| 盾 | 1 マス | 入れない（持ち主の駒も） | 遮る | 耐久力（20）が 0 | 攻撃して削れる |
| 煙幕 | 中心の周りの 3 x 3 | 入れる | 遮らない | 残りのターン数が 0 | 中の持ち主の駒への、離れたところからの攻撃を無効にする |
| 聖域 | 中心の周りの 3 x 3 | 入れる | 遮らない | 残りのターン数が 0 | 持ち主のフェーズの始めに、中の持ち主の駒を回復する |
| 結び目 | 1 マス | 入れる | 遮らない | 相手の駒が乗っている（ほどける）か、残りのターン数が 0（立ち直る） | 倒れたほつれ（魔物）が残す。立ち直ると、そこにほつれが現れる（`docs/monsters.md`） |

残りのターン数の値は「調整値」。煙幕と聖域の 3 x 3 は、盤の外にはみ出したぶんを除く。壁や駒のマスにも広がる。

## 置く入口

スキルの行動は、次の関数を呼ぶ（置けなければ何もせずに空の列を返す。呼ぶ前に確かめるなら `can_place_*`）。
持ち主はプレイヤーだけ（中立の陣営では置けない）。

| 関数 | 置ける条件 | 返すイベント |
| --- | --- | --- |
| `FieldEffects.place_barricade(battle, 陣営, マス)` | `can_place_barricade`: 盤の中の入れるマスで、駒・環境オブジェクト・ほかの効果が無く、本陣でも結晶泉でもない | `BarricadePlacedEvent` |
| `FieldEffects.place_smoke(battle, 陣営, 中心)` | `can_place_area`: 中心が盤の中 | `AreaEffectPlacedEvent` |
| `FieldEffects.place_sanctuary(battle, 陣営, 中心)` | 同上 | `AreaEffectPlacedEvent` |

スキルの射程（どこまで離れて置けるか）は、置く側（スキル）が決める。
本陣と結晶泉に盾を置けないのは、本陣の占拠（勝ち方の 1 つ）と中立の駒の湧きを盾でふさげないようにするため。

## 盾

- **入れない**。通り抜けも、止まるのも、駒を置くこともできない（`Board.is_walkable` が偽）。持ち主の駒も同じ。
- **射線を遮る**: 攻撃する駒と相手の「間のマス」に盾があると、攻撃は届かない（攻撃の対象に選べない）。
  駒への攻撃、起爆樽への攻撃、盾への攻撃のどれも同じ（`Combat.reaches`）。中立の駒の攻撃も同じ。
  - 間のマスは、2 つのマスの中心を結ぶ線分が内側を通るマス（両端は含まない。`Combat.cells_between`）。
    縦か横に並んでいれば、その間に並ぶマス。斜めにちょうど並んでいれば、対角線上のマス。マスの角に触れるだけのマスは含まない。
    どちら向きに測っても同じ。
  - 隣り合うマス（距離 1）の間のマスは無いので、隣からの攻撃は遮られない。
  - 地形（壁）は、いままでどおり遮らない。
  - **回復は遮らない**（撃つのではないので。`docs/healer-role.md` の射程のまま）。
- **攻撃して削れる**（`AttackBarricadeAction.new(攻撃する駒の番号, 盾のマス)`）:
  - 攻撃できるのは、盾の持ち主でない陣営の駒。巡航で動いた駒は攻撃できない。動いたあとでも、動かずにでもよい。
  - 届くかどうかは駒への攻撃と同じ（射程と、間の盾）。
  - 耐久力が攻撃力のぶん減る（`FieldEffects.barricade_damage`）。森の軽減は無い（駒ではない）。
    照準の駒の攻撃なら、確定クリティカルの倍率が掛かり、照準は消える（`docs/unit-statuses.md`）。
  - 耐久力が 0 になったら、盾は消える。そのマスはまた通れて、射線も通る。
  - 攻撃すると行動を終える。**経験値は入らない**（駒に何かをしたのではない。`docs/experience-levelup.md`）。
  - 返すイベントは順に、`BarricadeDamagedEvent`（攻撃した駒、盾、減った量、あとの耐久力）、
    0 になったら `FieldEffectRemovedEvent`（`DESTROYED`）、攻撃で消える状態（照準）があれば `StatusRemovedEvent`（`CONSUMED`）、`UnitActedEvent`。
- 樽の爆発は盾に当たらない（盾を削るのは駒の攻撃だけ）。
- 期間は無い（壊されるまで残る）。

## 煙幕

- 煙幕の中にいる、**煙幕の持ち主の駒**への、**離れたところからの攻撃**（距離 2（`Combat.RANGED_DISTANCE`）以上）は、ダメージが 0 になる（`FieldEffects.smoke_covering`）。
  - 距離は攻撃する駒の位置から測る。離れて撃てる駒でも、隣から撃てば当たる。
    隣にしか届かない駒の攻撃は、防げない。
  - 相手の陣営の駒と中立の駒は、煙幕の中にいても守られない。
  - 攻撃はできる（対象に選べて、受け付けられる）。無効になっても行動は終わる。**経験値は入らない**。
  - 返すイベントは、`AttackDamagedEvent` のかわりに `SmokeBlockedEvent`（攻撃した駒、相手、煙幕）。HP は変わらない。
  - 戦闘予測は `Combat.damage` が 0 を返すことで知る。
- 起爆樽の爆発とファイアボール（`docs/skills/fireball.md`）は防がない（駒の攻撃ではない）。
- 入れる。移動は妨げない。射線も遮らない。回復も遮らない（`Healing.can_heal` は煙幕を見ない）。

## 聖域

- 聖域の持ち主のフェーズの始めに、聖域の中にいる持ち主の駒の HP が 5（`SANCTUARY_HEAL`）回復する。最大 HP の実効値は超えない。
  - 相手のフェーズと中立のフェーズには回復しない。相手の陣営の駒と中立の駒は回復しない。
  - いくつ重なっていても、1 体につき 1 回（番号のいちばん小さい聖域が回復させる）。
  - HP が満タンの駒には、イベントは出ない。
  - 返すイベントは `SanctuaryHealedEvent`（`UnitHealedEvent` の子。`cause` は `SANCTUARY`。`effect_id` が聖域）。
    上の行から、左の列から。経験値は入らない。
- 入れる。移動は妨げない。射線も遮らない。

## 期間の数え方

煙幕と聖域は「残りのターン数」を持つ（置いたときの値は、煙幕 2（`SMOKE_TURNS`）、聖域 3（`SANCTUARY_TURNS`））。

- **持ち主のフェーズの始め**に、残りが 1 減る。0 になったら消える。相手のフェーズと中立のフェーズでは減らない。
- 聖域は、その同じフェーズの始めに、**回復してから**減る。
- 置いたフェーズの中では減らない（置いたフェーズの始めはもう過ぎている）。

例えばターン 1 のプレイヤー1 が置いた煙幕は、ターン 2 のプレイヤー1 の始めに残り 1、ターン 3 のプレイヤー1 の始めに消える。
つまり相手のフェーズを 2 回守る。ターン 1 のプレイヤー1 が置いた聖域は、ターン 2・3・4 のプレイヤー1 の始めに回復し、
ターン 4 の回復のあとに消える。

**スキルのクールダウンも、同じ数え方（持ち主のフェーズの始めに 1 減る）**（`docs/active-skills.md`）。

フェーズの始めに起きることの順は、`PhaseStartedEvent`、回復の泉、再生の特性（`docs/turn-phase.md`）、聖域の回復、
効果の残りが減る（`FieldEffectTickedEvent`。0 になったものは、かわりに `FieldEffectRemovedEvent`（`EXPIRED`））、
駒に付いている状態の期限（`docs/unit-statuses.md`）、スキルのクールダウン。
同じフェーズの始めの効果どうしは、効果の番号の順。

## イベント

| イベント | 中身 |
| --- | --- |
| `FieldEffectPlacedEvent`（親） | 効果の番号、種類、持ち主、マス、中心。見た目は、この値だけで効果を描ける |
| `BarricadePlacedEvent` | 盾。置いたときの耐久力（`durability`） |
| `AreaEffectPlacedEvent` | 煙幕・聖域。置いたときの残りのターン数（`turns_left`） |
| `FieldEffectTickedEvent` | 残りのターン数が減った（効果の番号、あとの残り） |
| `FieldEffectRemovedEvent` | 消えた（効果の番号、種類、マス、理由 `EXPIRED` / `DESTROYED`） |
| `BarricadeDamagedEvent` | 盾が攻撃で削れた（攻撃した駒、盾、マス、減った量、あとの耐久力） |
| `SmokeBlockedEvent` | 攻撃が煙幕に阻まれた（攻撃した駒、相手、煙幕） |
| `SanctuaryHealedEvent` | 聖域で回復した（`UnitHealedEvent`。聖域の番号） |

## 選べること

`Battle.options()` の `barricade_cells` に、いまの位置から攻撃できる相手の盾のマスが載る（`docs/battle.md`）。
攻撃できる相手（`attack_target_ids`）と樽（`barrel_cells`）からは、間に盾があるものが外れる。煙幕に守られた相手は載る（攻撃はできる）。

## CPU

- 盾を削る手、壊す手にも価値を付ける（`docs/cpu-ai.md`）。駒を攻撃できないときに、道をふさぐ盾を壊しに行く程度の小さい値。
- 攻撃する手で立つマスは、ルールの問い合わせ（`Combat.reaches`、`FieldEffects.smoke_covering`）で、間に盾があるマスと、
  相手が煙幕に守られるマスを除いて選ぶ。煙幕の中の相手には、隣まで寄って撃つ。
- 歩数の表は、盾が置かれた・消えたら作り直す（`Board.walkable_revision`）。
- 次の相手の番の危険の見積もりは、盾（相手が通れない、離れた攻撃の間にあれば届かない）と、自分の煙幕（中のマスは、
  隣まで寄っての攻撃とスキルのダメージだけを数える）を見る（`docs/cpu-ai.md` の「危険の見積もり」）。

## 中立の駒

中立の駒も、盾には入れず、盾越しには攻撃できない（同じルールを通す。`Combat.reaches`）。動く先も、盾越しでなく撃てるマスを選ぶ
（`docs/neutral-minion.md` の「中立のフェーズ」）。中立の駒は盾を攻撃しない。
中立の駒の攻撃も、煙幕に阻まれる（`Combat.strike`）。エナジー・コアは隣からしか撃てない（射程が 1）ので関わらないが、
中ボス（`docs/neutral-mid-boss.md`）は離れたところから撃てるので、盾越しには撃てず、煙幕の中の駒を離れて撃つと阻まれる。

## 調整値

`rules/field_effects.gd` の先頭。

| 値 | いま | 場所 |
| --- | --- | --- |
| 盾の耐久力 | 20 | `BARRICADE_DURABILITY` |
| 煙幕の残りのターン数 | 2 | `SMOKE_TURNS` |
| 聖域の残りのターン数 | 3 | `SANCTUARY_TURNS` |
| 聖域の回復量 | 5 | `SANCTUARY_HEAL` |
| 煙幕・聖域の広がり | 中心からチェビシェフ距離 1（3 x 3） | `AREA_RADIUS` |

煙幕が防ぐ「離れたところ」の距離（2（`Combat.RANGED_DISTANCE`）以上）は `rules/combat.gd`。
CPU の、盾を削る価値（耐久力 1 あたり 0.5（`BARRICADE_DAMAGE_VALUE`））と壊す価値（10（`BARRICADE_BREAK_VALUE`））は `rules/cpu/cpu_player_base.gd`。
