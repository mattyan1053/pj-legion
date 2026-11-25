# 経験値とレベルアップ

コード: `rules/growth.gd`（調整値、計算、適用）、`rules/events/experience_gained_event.gd`、`rules/events/level_up_event.gd`。
経験値を渡すのは `rules/actions/attack_action.gd`、`rules/actions/heal_action.gd`、`rules/skills.gd`（ダメージのあるスキル。`Skills.deal_damage`）。伸びた能力値は `rules/unit.gd` の成長の層。
テスト: `tests/rules/test_experience.gd`、`tests/rules/skills/test_fireball.gd`（スキルの経験値）。

駒は自分の行動で経験値を得て、たまるとレベルが上がり、能力値が伸びる。

## 育つ駒

- 育つのは**軍に属する駒**（前衛・後衛・奇襲・回復の役割を持つ駒）だけ。**将と中立の駒は育たない**（経験値が入らず、イベントも出ない）。
- レベルは 1 から始まり、**3（`Growth.MAX_LEVEL`）が上限**。

## 経験値が入るとき

経験値は、行動した駒に入る。

| 出来事 | 経験値 |
| --- | --- |
| 攻撃が当たり、相手が生き残った | 10 |
| 攻撃でプレイヤーの駒を倒した | 50（当たったぶんの 10 は足さない） |
| 攻撃で中立の駒を倒した | 30（同上） |
| 攻撃で中ボス（エリートミニオン）を倒した | 60（同上。`docs/neutral-mid-boss.md`） |
| 味方を回復した | 20（回復した量によらない） |

- 入るのは、駒が自分の行動（`AttackAction`、`HealAction`、ダメージのあるスキル）で相手に何かをしたときだけ。
- **ダメージのあるスキル**（ファイアボール）は、当てた相手ごとに上の表で数え、いちばん多く入る 1 体ぶんだけが入る
  （何体に当てても 1 回。`docs/active-skills.md` の「ダメージのあるスキル」）。
- **起爆樽の爆発では入らない**（樽を攻撃した駒にも、巻き込まれて倒れた駒のぶんも）。回復の泉、中立の駒の攻撃でも入らない。
- **煙幕に阻まれた攻撃と、盾への攻撃でも入らない**（相手に何もしていない。`docs/field-effects.md`）。聖域の回復でも入らない。
- 森の軽減で相手が生き残れば、「当たった」のぶん。
- **バリアに防がれた攻撃（ダメージ 0）も、「当たった」のぶん**（バリアをはがす仕事をした。`docs/unit-statuses.md`）。スキルのダメージでも同じ。

## レベルアップ

- 経験値が 120（`Growth.EXPERIENCE_PER_LEVEL`）たまるとレベルが 1 つ上がり、その量を差し引く。**余りは繰り越す**（必要な量はどのレベルでも同じ）。
- 1 回で 2 レベルぶん以上入れば、そのぶん続けて上がる（いまの量では起きない）。
- 上限のレベルに届いたら、ためた経験値は 0 にする。上限のレベルの駒には、もう入らない（イベントも出ない）。
- 上限のレベルに届いた駒は、進化先を選ぶ（`docs/branch-evolution.md`）。
- 伸びる量は役割で決まる（1 レベルごと）。

  | 役割 | 最大 HP | 攻撃力（回復役は回復量） |
  | --- | --- | --- |
  | 前衛 | +6 | +1 |
  | 後衛 | +3 | +1 |
  | 奇襲 | +3 | +1 |
  | 回復 | +3 | +2 |

- 伸びた量は駒の**成長の層**（`Unit.growth_bonus`。実効値の層 1。`docs/player-loadout.md`）に足す。種類の基本の値は書き換えない。
- **最大 HP が伸びたら、伸びたぶんだけいまの HP も増える**（受けているダメージの量は変わらない）。

## イベント

経験値とレベルアップは、それを起こした行動のイベントの中に、起きた順で並ぶ。

- 攻撃: `AttackDamagedEvent`、（倒れたら）`UnitDefeatedEvent`、`ExperienceGainedEvent`、（上がったら）`LevelUpEvent`、`UnitActedEvent`
- 回復: `HealerHealedEvent`、`ExperienceGainedEvent`、（上がったら）`LevelUpEvent`、`UnitActedEvent`
- ダメージのあるスキル: `SkillUsedEvent`、`SkillDamagedEvent`（当てた数だけ）、（倒れたら）`UnitDefeatedEvent`、`ExperienceGainedEvent`、（上がったら）`LevelUpEvent`、`UnitActedEvent`
- 上限のレベルに届いた `LevelUpEvent` のすぐあとには、`EvolutionOfferedEvent` が入る（`docs/branch-evolution.md`）。

| イベント | 値 |
| --- | --- |
| `ExperienceGainedEvent` | 駒、入った量 `amount`、理由 `reason`（`HIT` / `DEFEAT` / `HEAL`）、足したあとの量 `experience`（レベルアップの前。`EXPERIENCE_PER_LEVEL` 以上なら、このあとに `LevelUpEvent` が続く） |
| `LevelUpEvent` | 駒、上がったあとの `level`、伸びた量 `gains`（能力値 → 量）、伸びたあとの `max_hp`・`hp`・`power`、繰り越したあとの `experience` |

## 計算と適用

状態を変えない計算（戦闘予測もこれを使う）:

- `Growth.attack_experience(対戦, 攻撃する駒, 攻撃される駒)`: その攻撃で入る量（倒せるかは `Combat.damage` で見る）。
- `Growth.heal_experience()`: 回復で入る量。
- `Growth.damage_experience(相手, あとの HP)`: 相手の HP をそこまで減らしたときに入る量（攻撃とスキルが同じ表を使う）。
- `Growth.preview(駒, 量)`: 実際に入る量、足したあとのレベルとためた量、上がるレベルの数、進化先を選ぶことになるか（`Growth.Outcome`）。

適用は `Growth.gain(駒, 量, 理由)` で、同じ計算を通してイベントを返す。複製（`Battle.clone()`）は、レベル・経験値・成長の層も駒ごとに写す。

## 始めのレベル

ストーリーの話は、駒をレベル 1 より上や、経験値をためた状態から始められる（戦いの定義の `start_growth`。`docs/scenario.md`）。
`Growth.start_at(駒, レベル, 経験値)` が、レベルアップと同じ量だけ伸ばす（イベントは出さない）。上限のレベルと、レベルが上がる量には届かせない。

## 進化とのつなぎ

`Growth.level_up` でレベルが `Growth.MAX_LEVEL` に届いた駒は、進化先を選ぶのを待つ状態になり（`Unit.evolution_ready`）、
`Growth.gain` がその `LevelUpEvent` のあとに `EvolutionOfferedEvent` を足す。その先は `docs/branch-evolution.md`。
伸びる量（`Growth.GAINS`）は役割ごとの表のまま。進化先ごとの能力値の増減は、進化の側（`Evolution`）が別に持つ。

## 調整値

ゲーム性で選んだ値。すべて `rules/growth.gd` の先頭にある。

| 値 | いまの値 | 選んだ理由 |
| --- | --- | --- |
| `HIT_EXPERIENCE` | 10 | 毎ターン当て続けても、レベル 2 まで十数ターンかかる。当てるだけでは育ちきらない |
| `DEFEAT_EXPERIENCE` | 50（当たりのぶんは足さない） | 止めを刺した 1 体に寄せる。撃破 1〜2 回と当たり何回かでレベル 2 に届き、十数ターンの対戦で各軍に何度かレベルアップが起きる |
| `NEUTRAL_DEFEAT_EXPERIENCE` | 30 | コアは 1〜2 回の攻撃で倒せ、湧き直す（`docs/neutral-minion.md`）。大きくすると、コアを狩れるマップで序盤のうちに進化が出そろう。当たり 3 回ぶんにして、通りがかりに狩る得は残し、狩り続けて育つ道は細くした |
| `MID_BOSS_DEFEAT_EXPERIENCE` | 60（当たりのぶんは足さない） | 中ボスは、何体かで何ターンも削る（`docs/neutral-mid-boss.md`）。削るたびの当たりのぶんが狩りに加わった駒へ散って入り、止めの 1 体にはプレイヤーの駒の撃破より少し多く入る |
| `HEAL_EXPERIENCE` | 20 | 回復役の攻撃は弱く、撃破のぶんはほとんど入らない。当たりの倍にして、攻撃役と同じくらいの速さで育つようにした。満タンの味方は回復できないので、空回しでは稼げない |
| `EXPERIENCE_PER_LEVEL` | 120、どのレベルでも同じ | 最初の進化が対戦の後半、1 局に 1〜2 回になる量。レベルごとに必要な量を増やさないかわりに、上限を低くして差を抑える |
| 繰り越し | する。レベル 3 に届いたら捨てる | 撃破のような大きい獲得が無駄にならない。上限の先にためても使い道が無い |
| `MAX_LEVEL` | 3 | 届いた駒は進化先を選ぶ（`docs/branch-evolution.md`） |
| `GAINS`（伸びる量） | 上の表 | 1 レベルで、最大 HP は基本の値の 1〜2 割、攻撃力は 1 割ほど。上限のレベルでも、ほかの駒を 1 回で倒せるようになる伸びは無い（攻撃力の伸びより、相手の最大 HP の伸びのほうが大きい。レベル 1 のスナイパーだけは、育った奇襲・ソーサラーの一撃で倒れる）。前衛は HP を厚く、回復役は回復量を厚くした |
| 将は育たない | 将には入らない | 将は守る駒。将が撃破で育つと、将を前に出すほど強くなり、守る形が崩れる |
| 中立の駒は育たない | 入らない | プレイヤーの駒を倒すほど強くなる中立は、狩りの的として扱いにくい |
| 樽・泉では入らない | 駒の行動でない | 樽の爆発は敵味方を問わない。入れると、味方を巻き込む爆発でも得になる |
| 最大 HP が伸びたときの HP | 伸びたぶん増える | レベルアップが回復を兼ねすぎず、損もしない。聖遺物（`docs/relic-buff.md`）でも同じ扱い（`Unit.follow_max_hp`） |

