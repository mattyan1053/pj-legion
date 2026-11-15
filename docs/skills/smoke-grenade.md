# スモークグレネード（コマンドー）

コード: `rules/skills/smoke_grenade_skill.gd`。テスト: `tests/rules/skills/test_smoke_grenade.gd`。
共通の決まり（使える条件、クールダウンの数え方、イベントの順）は `docs/active-skills.md`。煙幕そのものは `docs/field-effects.md`。

## いまの仕様

- **3 マス（`SmokeGrenadeSkill.CENTER_RANGE`）以内（マンハッタン距離。自分のマスも選べる）のマスを中心に、自分の陣営の煙幕を置く。**
- 中心は盤の中ならどこでもよい（障害物、駒のいるマス、盾のマスでもよい）。盾は遮らない（投げ込むので）。
- 煙幕は中心の周りの 3 x 3（盤の外にはみ出したぶんを除く）。中にいる持ち主の駒への、距離 2（`Combat.RANGED_DISTANCE`）以上からの攻撃を無効にする。
  2 ターン（`FieldEffects.SMOKE_TURNS`）残る（そのターン数と同じ回数、相手のフェーズを守る）。
- 効果が及ぶマス（`affected_cells`）は、煙幕のマス。
- 返すイベントは、`SkillUsedEvent`、`AreaEffectPlacedEvent`、`UnitActedEvent`。経験値は入らない。
- ファイアボールは防がない（駒の攻撃ではない。`docs/skills/fireball.md`）。

## 調整値

| 値 | いま | 場所 |
| --- | --- | --- |
| クールダウン | 3 | `SmokeGrenadeSkill.COOLDOWN` |
| 中心に選べる距離（マンハッタン） | 3 | `SmokeGrenadeSkill.CENTER_RANGE` |
| 煙幕の期間、広さ | 2 ターン、3 x 3 | `FieldEffects.SMOKE_TURNS`（`docs/field-effects.md`） |

- クールダウンは期間より少しだけ長い。置き続ければ、ほとんどのターンに煙幕がある。
- 中心の距離は、移動力の大きい奇襲が、前に出たあと後ろの味方へ投げ返せる距離。

## CPU

`CpuSmokeGrenade.value`（`rules/cpu/smoke_grenade_cpu.gd`）。**置く煙幕の中に、次の相手の番に、煙幕が防ぐ攻撃（離れたところからしか届かない攻撃）に
狙われうる味方が 2 体（`CpuSmokeGrenade.MIN_UNITS`）以上いる**か、**1 体でも、防げるぶんの価値が 20（`CpuSmokeGrenade.MIN_VALUE`）以上**（離れた敵 2 体に狙われている、など）のときに置く。

- 狙われうるかは、CPU の危険の見積もり（`docs/cpu-ai.md`）で見る。隣まで寄れる敵の攻撃と、スキルのダメージ（ファイアボール）は、
  煙幕では防げないので数えない。
- もう自分の煙幕の中にいる味方は数えない（重ねない）。
- 置くために立つマスも探す（共通の決まり。`docs/cpu-ai.md`）。試す中心は、狙われている味方を中に入れられるマス（`CpuSmokeGrenade.targets`）。
- 価値は、数えた味方ごとに「防げるダメージ（その味方の HP まで）× ダメージの価値（将は 6（`CpuPlayer.KING_DAMAGE_VALUE`）、
  ほかは 2（`CpuPlayer.DAMAGE_VALUE`））× 0.75（`CpuSmokeGrenade.COVER_RATE`。敵は狙いを替えられるので、1 より小さい）」の合計。
- 自分の煙幕の中のマスの危険の見積もりも、同じ数え方になる（煙幕の中へ下がる、煙幕の中から撃つ、を選びやすくなる）。
- CPU が使う回数は多くない（回数は `docs/cpu-ai.md` の「いまの集計」）。相手の FANTASY の離れた駒はソーサラーだけで、射程が短く、
  隣まで寄られることが多いため。
  人が使う強さ（スナイパーの列を守る、本陣に乗った将を守る）は、集計には出ていない。
