# 骨太鼓（骸骨鼓手。魔物）

コード: `rules/skills/war_drum_skill.gd`、`rules/cpu/war_drum_cpu.gd`、`rules/status.gd`（突撃）。
テスト: `tests/rules/skills/test_war_drum.gd`。
共通の決まり（使える条件、クールダウンの数え方、イベントの順）は `docs/active-skills.md`。
魔物（ストーリーの話の敵だけ）のスキル。人の側は使わない。

## いまの仕様

- **自分から 3 マス（`WarDrumSkill.RADIUS`。マンハッタン距離）以内の味方（自分は除く）に、突撃を付ける。**
- 突撃は、MILITARY の必殺技の総員突撃と同じ状態（移動力と攻撃力が上がる。`docs/tactical-ult.md`、`docs/unit-statuses.md`）。
  次の自分の番の始めに外れる（`WarDrumSkill.ASSAULT_TURNS`）。
- 対象は自分のマス。動く前でも、動いたあとでも使える。
- もう行動を終えた味方にも付くが、そのフェーズにはもう動けないので、得をしない。

### イベント

`SkillUsedEvent`、届いた味方ごとの `StatusAppliedEvent`（突撃。上の行から、左の列から）、`UnitActedEvent`（鼓手）。

## 決めたこと

- 新しい状態を作らず、総員突撃の突撃を使い回した（画面の見せ方、予測、CPU の危険の見積もりが、そのまま効く）。
- 軍の無い群れは必殺技を持たない（`docs/unit-roster.md` の「魔物」）。そのかわり、鼓手のいる所だけ、一度に押してくる。
  鼓手は脆い（HP 22）ので、先に倒せば止まる。

## 調整値

| 値 | いま | 場所 |
| --- | --- | --- |
| クールダウン | 3 | `WarDrumSkill.COOLDOWN` |
| 届く広さ | 3 | `WarDrumSkill.RADIUS` |
| 突撃の残りのターン数 | 1 | `WarDrumSkill.ASSAULT_TURNS` |

## CPU

`CpuWarDrum`（`rules/cpu/war_drum_cpu.gd`）。

- 鳴らすために立つマスの候補は、いまのマスと、立つマスの価値の高い 3 か所（`CpuWarDrum.TRIES`）。
- 価値は、突撃が付いた味方のうち、このフェーズにまだ動けて、回復役でなく、移動力 + 射程の中に敵の駒がいるものの数 × 20（`CpuWarDrum.ALLY_VALUE`）。
  届く味方が戦えないなら鳴らさない（価値 0）。
- 鼓手は後衛なので、前衛と奇襲より先に動く（`docs/cpu-ai.md` の「駒を動かす順」）。
