# ファイアボール（ソーサラー）

コード: `rules/skills/fireball_skill.gd`。テスト: `tests/rules/skills/test_fireball.gd`。
共通の決まり（使える条件、クールダウンの数え方、イベントの順、ダメージのあるスキルの入口）は `docs/active-skills.md`。

「ダメージのあるスキル」（同じ文書）。ダメージの与え方と経験値は、共通の入口（`Skills.deal_damage`）を通す。

## いまの仕様

- **3 マス（`FireballSkill.CENTER_RANGE`）以内（マンハッタン距離。自分のマスも選べる）のマスを中心に、十字（中心と上下左右。盤の外は除く）の敵へ 8 ダメージ（`FireballSkill.DAMAGE`）。**
- 当たるのは**敵**（相手の陣営の駒と、中立の駒）だけ。**味方には当たらない。**
- **樽にも盾にも当たらない**（樽は爆発せず、盾は削れない。盾を削るのは駒の攻撃だけ。`docs/field-effects.md`）。
- ダメージは固定。使う駒の攻撃力（成長、装備、進化）にはよらない。**森の軽減は無い。**
- **壁にも盾にも遮られない。** 中心は盤の中ならどこでもよい（壁のマス、誰もいないマスでもよい）。
- **煙幕では防げない**（煙幕が防ぐのは駒の攻撃。ファイアボールは樽の爆発と同じく、攻撃ではない）。
- **バリアには防がれる**（その駒には 0 で、バリアが消える。`docs/skills/divine-shield.md`）。
- 範囲に誰もいなくても使える（クールダウンは付き、行動は終わる）。
- 範囲の全員に**同時に**当たる。倒れた駒は、全員のダメージのあとに取り除く。将を倒せば勝ち（ほかの行動と同じ）。
- 効果が及ぶマス（`affected_cells`）は、十字のマス。

### 経験値

- 使った駒に、**当てた相手のうち、いちばん多く入る 1 体ぶん**だけ入る（何体に当てても 1 回）。
  量は駒の攻撃と同じ表（`Growth.damage_experience`。`docs/experience-levelup.md`）: 当たって生き残れば 10（`Growth.HIT_EXPERIENCE`）、
  プレイヤーの駒を倒せば 50（`Growth.DEFEAT_EXPERIENCE`）、中立の駒を倒せば 30（`Growth.NEUTRAL_DEFEAT_EXPERIENCE`）、
  中ボスを倒せば 60（`Growth.MID_BOSS_DEFEAT_EXPERIENCE`）。
- 誰にも当たらなければ入らない。

### イベント

`SkillUsedEvent`、当てた駒ごとの `SkillDamagedEvent`（上の行から、左の列から）、倒れた駒の `UnitDefeatedEvent`（同じ並び）、
`ExperienceGainedEvent`（と、上がれば `LevelUpEvent`）、`UnitActedEvent`。

### 脅威範囲

`docs/threat-range.md`。選べる中心のどれかの十字に入るマスすべてに、このダメージが届きうる（`threat_damage`。煙幕に防がれない）。

## 調整値

| 値 | いま | 場所 |
| --- | --- | --- |
| クールダウン | 4 | `FireballSkill.COOLDOWN` |
| 中心に選べる距離（マンハッタン） | 3 | `FireballSkill.CENTER_RANGE` |
| ダメージ（1 体ずつ） | 8 | `FireballSkill.DAMAGE` |
| 範囲（中心からの上下左右のマス数） | 1（十字 5 マス） | `FireballSkill.ARM` |

- 十字の端のマスは、中心の距離より 1 マス先まで届く。ソーサラーの攻撃より遠く、後衛の射程に近い距離から撃ち返せる。
  届く距離を残し、量と回数で抑えている。
- 1 体へのダメージはソーサラーの攻撃より少なく、クールダウンも長い。
- 味方を巻き込まないのは、CPU と人の両方で「撃てる場面」を読みやすくするため。範囲に味方が混じる場面でも撃てる。

## CPU

スキルごとの価値の見積もりは無い（`rules/cpu/fireball_cpu.gd` は、対象を絞る `targets` だけ）。複製の上で使ってみて、`SkillDamagedEvent`（`UnitDamagedEvent` として読む）と
経験値のイベントから、攻撃と同じ表で価値を読む（`docs/cpu-ai.md`）。

- 1 体へは攻撃のほうが価値が高いので、ふつうは攻撃を選ぶ。2 体以上に当たるとき、倒せるとき、攻撃が届かないときに使う。
- 撃つために立つマスを探す（共通の決まり。`docs/cpu-ai.md`）。試す中心は、敵（中立の駒も）のどれかに当たるマス
  （`CpuFireball.targets`。十字は対称なので、敵のマスを中心にしたときに効果が及ぶマスが、その敵に当たる中心になる）。
  中心ごとに、そこへ届く立てるマスのうち、立つマスの価値がいちばん高い 1 つから撃つ手を比べる。
