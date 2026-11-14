# 戦術バリケード（シールドトルーパー）

コード: `rules/skills/tactical_barricade_skill.gd`。テスト: `tests/rules/skills/test_tactical_barricade.gd`。
共通の決まり（使える条件、クールダウンの数え方、イベントの順）は `docs/active-skills.md`。盾そのものは `docs/field-effects.md`。

## いまの仕様

- **周り 8 マス（チェビシェフ距離 1）のどこか 1 マスに、自分の陣営の盾を置く。**
- 置けるのは、盤の中の入れるマスで、駒・環境オブジェクト・ほかの効果が無く、本陣でも結晶泉でもないマス
  （`FieldEffects.can_place_barricade`）。置けるマスが 1 つも無ければ、使えない。
- 盾は耐久力 20。入れない（持ち主の駒も）、射線を遮る、相手が攻撃して削れる。壊されるまで残る。
- 返すイベントは、`SkillUsedEvent`、`BarricadePlacedEvent`、`UnitActedEvent`。経験値は入らない。

## 調整値

| 値 | いま | 場所 |
| --- | --- | --- |
| クールダウン | 4 | `TacticalBarricadeSkill.COOLDOWN` |
| 置ける距離（チェビシェフ） | 1 | `TacticalBarricadeSkill.PLACE_DISTANCE` |
| 盾の耐久力 | 20 | `FieldEffects.BARRICADE_DURABILITY` |

- 盾に期間は無いので、クールダウン 4 だと、壊されなければ 1 体が何枚も並べられる。枚数の上限は付けていない。
  通路をふさぎ続ける使い方が強すぎるようなら、クールダウンを延ばすか、1 体が残せる枚数を決める。

## CPU

`CpuPlayer._barricade_value`。**いま敵の離れた攻撃（射程 2 以上）が味方に届いていて、盾を置くと届かなくなる**ときに置く。

- 届くかどうかは、置く前と置いたあと（複製）で、ルールの `Combat.can_attack` を比べる。
- 価値は、切った射線 1 本につき「その敵の攻撃力 × ダメージの価値（将は 6、ほかは 2）× 0.75」（`BARRICADE_COVER_RATE`）。
  味方の射線を切るぶんは、同じだけ引く。
- 道をふさぐ（近づく敵を止める、本陣を守る）ためには置かない。
