# 回復役の回復

コード: `rules/healing.gd`（対象・回復量）、`rules/actions/heal_action.gd`（回復の行動）、
`rules/events/healer_healed_event.gd`（親は `rules/events/unit_healed_event.gd`）。
テスト: `tests/rules/test_healing.gd`。

回復役（衛生兵・プリースト）は味方を回復する。治す相手がいないときのために、弱い攻撃も持つ（下の「回復役の攻撃」）。

## 回復できる相手

- 回復できるのは回復役だけ。相手は**同じ陣営のほかの駒** 1 体。敵と中立の駒は回復できない。
- **自分自身は回復できない。** 回復役どうしは回復し合える。
- **HP が最大 HP に届いている駒は回復できない**（行動を断る）。
- 射程は攻撃と同じ測り方（マンハッタン距離。斜め隣は 2。地形は遮らない）。回復役の射程の実効値
  （`Unit.attack_range()`）以内の駒を回復できる。盾と煙幕も遮らない（`docs/field-effects.md`）。
- `Healing.targets(対戦, 回復役)` が、いまの位置から回復できる駒を返す（盤面の上の行から、左の列から）。

## 回復量

| 種類 | 回復量 | 射程 |
| --- | --- | --- |
| 衛生兵 | 15 | 1 |
| プリースト | 14 | 2 |

- 回復量は回復役の `Unit.power()`（成長・進化・装備・聖遺物・一時的な補正の層を通った実効値。`docs/player-loadout.md`）。
  基本の値は種類の表（`docs/unit-roster.md`）。
- 回復後の HP は、回復される駒の最大 HP の実効値（`Unit.max_hp()`）を超えない。超えるぶんは切り捨てる。
- 地形は回復量を変えない。
- `Healing.amount(回復役, 相手)` が、実際に増える HP（切り捨てたあとの値）を、状態を変えずに返す。

## 回復の行動

`Battle.apply(HealAction.new(回復役の番号, 回復される駒の番号))`。

- 行動できる回復役が、いまの位置から回復する。動いたあとでも、動かずにでもよい。
  **巡航で動いた駒は回復できない**（攻撃と同じ扱い）。
- 回復すると行動を終える。
- 返すイベントは順に、`HealerHealedEvent`（`UnitHealedEvent` の子。回復した駒 `healer_id`、実際に増えた HP と、受けたあとの HP。`cause` は `HEAL`）、
  経験値（`ExperienceGainedEvent`、上がれば `LevelUpEvent`。`docs/experience-levelup.md`）、`UnitActedEvent`。
- 回復する相手がいなくても、待機（`WaitAction`）はできる。

## 回復役の攻撃

- 回復役も、ほかの駒と同じに敵を攻撃できる（`AttackAction`。起爆樽と盾も撃てる）。射程は回復と同じ（`Unit.attack_range()`）。
- 強さは回復量（`Unit.power()`）とは別の値（`UnitKind.healer_strike`）。成長・進化・装備・聖遺物で増えるのは回復量だけで、
  攻撃の強さには、一時的な補正（必殺技の総員突撃など。`Unit` の層 3）だけが乗る（`Combat.attack_power`）。
- ほかの攻撃と同じに、森の軽減、煙幕、バリア、経験値（当たり・撃破）が効く。

| 種類 | 攻撃の強さ（いま） | 定数 |
| --- | --- | --- |
| 衛生兵 | 4 | `UnitKind.MEDIC_STRIKE` |
| プリースト | 4 | `UnitKind.PRIEST_STRIKE` |

- 前衛（シールドトルーパー 6、パラディン 8）の半分ほど。2 体目からの回復役が、治す相手のいない番に何もできない（手番の 7 割ほど）のを埋める。
  強くすると、回復役を並べた部隊が攻める部隊と同じになるので、弱いままにする。数を選んだ実測は `docs/cpu-ai.md` の「いまの集計」。
- CPU は、その番に治せる味方がいないときだけ撃つ（`docs/cpu-ai.md` の「役割ごとの目標」）。

## 回復役のスキル

回復役のスキルは、ふつうの回復とは別の行動（`docs/active-skills.md`）。衛生兵はアドレナリン注射（`docs/skills/adrenaline-shot.md`）、
プリーストはセイントプレイス（`docs/skills/saint-place.md`）。
