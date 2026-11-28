# 駒に付く状態

コード: `rules/status.gd`（状態の種類と、種類ごとの決まり）、`rules/statuses.gd`（付ける・外す・期限）、
`rules/unit.gd`（`statuses`、`statuses_before_move`、`temporary_bonus`）、
`rules/events/status_applied_event.gd`、`rules/events/status_removed_event.gd`。
テスト: `tests/rules/test_statuses.gd`。

スキルと必殺技（と倒れた骸骨旗手）が駒に一定の間だけ付けるもの（バリア、照準、反動、突撃、奮起、絡み）。盤のマスに置く効果（`docs/field-effects.md`）とは別で、駒と一緒に動く。
ここにあるのは状態の側の約束だけで、**誰が・いつ付けるか（スキル、クールダウン、数値）はスキルごとの文書**（`docs/skills/`。突撃は `docs/tactical-ult.md` と `docs/skills/war-drum.md`）。

## 持ち方

- 駒が「種類 → 残りのターン数」で持つ（`Unit.statuses`）。**1 体に、同じ種類は 1 つまで。** 違う種類は一緒に付く。
- 付ける・外すのは `Statuses.add` / `Statuses.remove` だけ。もう付いている種類を付けると、残りのターン数を付け直す（効果は重ならない）。
- `Battle.clone()` は、状態も写す（`Unit.copy` が、駒の変数を名前で拾って写す。`docs/battle.md`）。

## いまある状態

| 状態 | 付いている間 | 外れるとき | 付けるスキル |
| --- | --- | --- | --- |
| バリア（`BARRIER`） | 次に受けるダメージを 1 回だけ 0 にする | ダメージを防いだ、期限 | ディバインシールド |
| 照準（`AIM`） | 射程が伸びる。次の攻撃 1 回が確定クリティカルになる | 攻撃を 1 回した、ほかのマスへ動いた、期限 | 精密照準 |
| 反動（`FATIGUE`） | 攻撃力（回復役は回復量と回復役の攻撃）が下がる | 期限 | アドレナリン注射（受けた駒に付く） |
| 突撃（`ASSAULT`） | 移動力と攻撃力（回復役は回復量と回復役の攻撃）が上がる | 期限 | 必殺技の総員突撃（`docs/tactical-ult.md`。軍の全員に付く）、骨太鼓（`docs/skills/war-drum.md`。周りの味方に付く） |
| 奮起（`RESOLVE`） | 攻撃力（回復役は回復量と回復役の攻撃）が上がる | 期限 | 骸骨旗手が倒れたとき（`docs/monsters.md`。周りの味方に付く） |
| 絡み（`SNARE`） | 動けない（移動力 0。ポータルでも動かない。攻撃とスキルはできる。`Unit.is_rooted`） | 期限（相手の番に付き、付いた駒の次の番の終わりまで） | 魔物の糸蜘蛛の攻撃（`docs/monsters.md`。スキルではない） |

状態がダメージをどう変えるか（バリア、確定クリティカル）は `docs/combat.md` の「ダメージの解決」。

## 期限

- **持ち主のフェーズの始め**に、残りのターン数が 1 減る。0 になったら外れる（`StatusRemovedEvent`、`EXPIRED`）。
  相手のフェーズと中立のフェーズでは減らない。付けたフェーズの中では減らない。
  スキルのクールダウン、盤の上の効果と同じ数え方（`docs/active-skills.md`、`docs/field-effects.md`）。
- つまり、N ターンの状態は、**付けたターンの N ターン後の、自分の番の始めに外れる**。
  1 ターンなら、次の相手の番の間だけ。2 ターンなら、次の自分の番の間も残り、その次の自分の番の始めに外れる。
- フェーズの始めに起きることの順は、`PhaseStartedEvent`、回復の泉、再生の特性、盤の上の効果、**状態の期限**、クールダウン、最後に必殺技のゲージ（`docs/turn-phase.md`）。
  外れる順は、駒の番号の順、同じ駒なら種類の番号の順。

## 能力値の補正（一時的な補正の層）

- 能力値の補正のある状態（`Status.bonus`。いまは照準の射程、反動の攻撃力、突撃の移動力と攻撃力、奮起の攻撃力）は、付いている間だけ、駒の実効値の 3 つめの層
  「一時的な補正」（`Unit.temporary_bonus`。`docs/player-loadout.md`）に足される。
- **足すのは付けたとき、引くのは外れたとき**で、どちらも `Statuses.add` / `Statuses.remove` の中でだけ起きる。
  状態が外れる道（期限、使い切り、移動）は、どれも `Statuses.remove` を通るので、**補正の期限は、状態の期限そのもの**になる。
  補正だけを別に数えることはしない。
- 補正で最大 HP が変わる状態を足したときも、HP は決まりどおりに合う（`Unit.follow_max_hp`）。
- 補正を足すときは、状態の種類を 1 つ足し、`Status.bonus` に量を書き、`Statuses.add(駒, 種類, ターン数)` で付ける
  （反動、突撃が、この形）。期限と複製は、そのまま乗る。
- 補正は負でもよい。実効値は 0 を下回らない（最大 HP は 1。`Unit.stat`）。もとの値（層 1）は書き換えない。

## 動くと外れる状態

- 動くと外れる状態（`Status.breaks_on_move`。いまは照準）は、駒が**ほかのマスへ動いたとき**に外れる
  （`MoveAction` が、移動のイベントのあとに `StatusRemovedEvent`、`MOVED`）。巡航でも、ポータルを通っても同じ。
- **動かない移動（いまのマスを行き先にする）では外れない。**
- **移動を取り消すと戻る。** 外す前の状態を駒が覚えていて（`Unit.statuses_before_move`）、`UndoMoveAction` が
  残りのターン数ごと付け直す（`MoveUndoneEvent` のあとに `StatusAppliedEvent`）。
- **移動のほかの形でマスが変わったとき**（シャドウステップで跳んだ、入れ替えられた）も外れる（`Statuses.displace`。`MOVED`）。
  こちらは移動ではないので、取り消しでは戻らない。相手の構えたスナイパーと入れ替われば、照準を解ける。
- 動いたあとの値を、動かずに知るには `Statuses.stat_after_move(駒, 能力値)`（CPU が、動いてから撃つ手の射程に使う）。

## 攻撃で外れる状態

攻撃で外れる状態（`Status.ends_on_attack`。いまは照準）は、駒が攻撃を 1 回したら外れる（`StatusRemovedEvent`、`CONSUMED`）。
駒への攻撃、樽への攻撃、盾への攻撃のどれでも、煙幕に阻まれた攻撃でも外れる（`Statuses.after_attack`）。スキルを使っても外れない。

## イベント

| イベント | 中身 |
| --- | --- |
| `StatusAppliedEvent` | 駒に状態が付いた（駒、種類、残りのターン数）。付け直しと、移動の取り消しで戻ったときにも出る |
| `StatusRemovedEvent` | 駒の状態が外れた（駒、種類、理由: `EXPIRED` 期限 / `CONSUMED` 使い切った / `MOVED` 動いた） |

倒れた駒の状態には、何も出ない（駒ごと盤からいなくなる）。

## 状態を足すとき

### 触るファイル

1. `rules/status.gd`: `Type` に 1 つ（数の小さい順に期限が切れる）。当てはまる決まりの関数に書く（`bonus`、`blocks_damage`、`critical_percent`、
   `ends_on_attack`、`breaks_on_move`、`roots`）。数値は、付ける側（スキル・必殺技・`Monsters`）のファイルの調整値を読む。`rules/statuses.gd` は直さない。
2. 付ける所で `Statuses.add` を呼ぶ（スキルの `apply`、必殺技、`rules/monsters.gd` など）。
3. 文: `game/text/names.csv` の `status.<id>` と `status.<id>.summary`。説明に数を差し込むなら、`game/names.gd` の `status_summary` の表に値を足す。
4. ダメージの解決への新しい割り込み方が要るなら、段を足す。順は `docs/combat.md` の「ダメージの解決」。
   - 攻撃にだけ掛かるなら、`rules/combat.gd` の `hit` の、合う段の位置に。
   - 原因を問わず（攻撃・爆発・スキル）掛かるなら、`rules/hit.gd` の `resolve` の、バリアの前に。
   - 段の順は `tests/rules/test_damage_order.gd` が固定し、予測 = 実際 は `tests/game/test_forecast_matches.gd` が重ねた場面で比べる。新しい段は、両方に場面を足す。
   - 内訳を予測とログに出すなら: `Hit` の欄、`rules/events/unit_damaged_event.gd` の欄と `_fill`、`rules/forecast.gd` の `UnitOutcome` の欄と写す所、
     `game/forecast_text.gd` の注、`game/battle_log/log_base.gd` の `_damage_text` と `battle.csv` の `battle.log.note.<x>`。
5. 回復の量を変える状態なら、HP を増やす 5 か所（泉・再生・回復役・聖域・補給線）をどれも直す（共通の道が無い。`docs/code-health.md` の表の 9）。

期限、複製、移動の取り消し、駒の情報の札は、足した状態にそのまま効く。
付いたときの再生は状態の名前を出す（スキルで付いたものは、反動のほかは出さない。`docs/battle-view.md` の出来事の表）。

### 足し忘れても検査が落ちない所

- `status_summary` の値が無い: 説明に `{x}` がそのまま出る（`{` が残らないかを見るのは、スキル・必殺技・聖遺物だけ）。
- **CPU の危険の読み**（`rules/cpu/cpu_threats.gd`）は、駒の攻撃の量をダメージの解決（`Combat.hit_from`）に聞くので、`Hit.resolve` か `Combat.hit_from` の段に足した状態は知る。
  ただし、0 にする状態（バリア）は「いちばん弱い 1 回を防ぐ」と別に数えるので、`Hit.unblocked`（防がれる前の量）には、減らす段を入れ、0 にする段は入れない。
  攻める側は攻撃力（`bonus` の `POWER`）なら数える（脅威範囲も同じ）。それ以外の増え方は数えない。
- CPU の手の価値（`rules/cpu/cpu_outcome_value.gd`）は、攻撃で付ける状態のうち絡みにしか値を付けない。ほかは 0。
- 内訳の欄を写し忘れても、数そのものは合う。予測とログの注だけが出ない。予測 = 実際 のテスト（`test_forecast_matches.gd`）は、比べる欄（いまはダメージ・HP・状態・軍略の増減）に足さないと、新しい内訳の食い違いを拾わない。

### 確かめ方

- `tools/check.sh <godot>`。テストだけなら `run_tests.gd -- --only=test_statuses,test_names,test_unit_info_text,test_wrap_audit,test_combat,test_damage_order,test_forecast`。
- 付けた兵の情報の札（スクリーンショットの `battle_unit_detail`）。
- 釣り合いが動くなら `measure-balance`。
