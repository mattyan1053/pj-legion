# セイントプレイス（プリースト）

コード: `rules/skills/saint_place_skill.gd`。テスト: `tests/rules/skills/test_saint_place.gd`。
共通の決まり（使える条件、クールダウンの数え方、イベントの順）は `docs/active-skills.md`。聖域そのものは `docs/field-effects.md`。

## いまの仕様

- **2 マス（`SaintPlaceSkill.CENTER_RANGE`）以内（マンハッタン距離。自分のマスも選べる）のマスを中心に、自分の陣営の聖域を置く。**
- 中心は盤の中ならどこでもよい（障害物、駒のいるマス、盾のマスでもよい）。盾は遮らない（撃つのではないので。回復と同じ）。
- 聖域は中心の周りの 3 x 3（盤の外にはみ出したぶんを除く）。持ち主のフェーズの始めに、中にいる持ち主の駒が HP 5（`FieldEffects.SANCTUARY_HEAL`）回復する。
  3 ターン（`FieldEffects.SANCTUARY_TURNS`）残る（置いた次の自分のフェーズから、そのターン数と同じ回数、回復する）。
- 効果が及ぶマス（`affected_cells`）は、聖域のマス。
- 返すイベントは、`SkillUsedEvent`、`AreaEffectPlacedEvent`、`UnitActedEvent`。経験値は入らない（回復役の経験値は、ふつうの回復から）。
- 回復役のふつうの回復（`docs/healer-role.md`）とは別の行動。同じ行動では、どちらか片方。

## 調整値

| 値 | いま | 場所 |
| --- | --- | --- |
| クールダウン | 4 | `SaintPlaceSkill.COOLDOWN` |
| 中心に選べる距離（マンハッタン） | 2 | `SaintPlaceSkill.CENTER_RANGE` |
| 聖域の期間、回復量、広さ | 3 ターン、5、3 x 3 | `FieldEffects.SANCTUARY_TURNS`、`FieldEffects.SANCTUARY_HEAL`（`docs/field-effects.md`） |

- 中心の距離は、プリーストの回復の射程にそろえた。自分を聖域に入れるか、1 歩下がって前の味方だけを入れるかを選べる。
- クールダウンは期間より少しだけ長い。置き続ければ、ほとんどのターンに聖域がある。

## CPU

`CpuPlayer._sanctuary_value`。**置く聖域の中に、HP の減っている味方が 2 体（`CpuPlayer.SANCTUARY_MIN_UNITS`）以上いる**ときに置く。

- もう自分の聖域の中にいる味方は数えない（重ねない）。
- 置くために立つマスも探す（共通の決まり。`docs/cpu-ai.md`）。試す中心は、減っている味方を中に入れられるマス（`_sanctuary_targets`）。
- 価値は、数えた味方ごとの「減っている HP（上限は聖域の回復 2 回（`CpuPlayer.SANCTUARY_EXPECTED_HEALS`）ぶん）」の合計
  × 回復の価値 2（`CpuPlayer.HEAL_VALUE`）。
- 減っている味方が 1 体だけなら 0。ふつうの回復のほうが早い。
