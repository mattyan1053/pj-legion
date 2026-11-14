# 駒に付く状態

コード: `rules/status.gd`（状態の種類と、種類ごとの決まり）、`rules/statuses.gd`（付ける・外す・期限）、
`rules/unit.gd`（`statuses`、`statuses_before_move`、`temporary_bonus`）、
`rules/events/status_applied_event.gd`、`rules/events/status_removed_event.gd`。
テスト: `tests/rules/test_statuses.gd`。

スキルが駒に一定の間だけ付けるもの（バリア、照準）。盤のマスに置く効果（`docs/field-effects.md`）とは別で、駒と一緒に動く。
ここにあるのは状態の側の約束だけで、**誰が・いつ付けるか（スキル、クールダウン、数値）はスキルごとの文書**（`docs/skills/`）。

## 持ち方

- 駒が「種類 → 残りのターン数」で持つ（`Unit.statuses`）。**1 体に、同じ種類は 1 つまで。** 違う種類は一緒に付く。
- 付ける・外すのは `Statuses.add` / `Statuses.remove` だけ。もう付いている種類を付けると、残りのターン数を付け直す（効果は重ならない）。
- `Battle.clone()` は、状態も写す（`Unit.copy` が、駒の変数を名前で拾って写す。`docs/battle.md`）。

## いまある状態

| 状態 | 付いている間 | 外れるとき | 付けるスキル |
| --- | --- | --- | --- |
| バリア（`BARRIER`） | 次に受けるダメージを 1 回だけ 0 にする | ダメージを防いだ、期限 | ディバインシールド |
| 照準（`AIM`） | 射程が伸びる。次の攻撃 1 回が確定クリティカルになる | 攻撃を 1 回した、ほかのマスへ動いた、期限 | 精密照準 |

状態がダメージをどう変えるか（バリア、確定クリティカル）は `docs/combat.md` の「ダメージの解決」。

## 期限

- **持ち主のフェーズの始め**に、残りのターン数が 1 減る。0 になったら外れる（`StatusRemovedEvent`、`EXPIRED`）。
  相手のフェーズと中立のフェーズでは減らない。付けたフェーズの中では減らない。
  スキルのクールダウン、盤の上の効果と同じ数え方（`docs/active-skills.md`、`docs/field-effects.md`）。
- つまり、N ターンの状態は、**付けたターンの N ターン後の、自分の番の始めに外れる**。
  1 ターンなら、次の相手の番の間だけ。2 ターンなら、次の自分の番の間も残り、その次の自分の番の始めに外れる。
- フェーズの始めに起きることの順は、`PhaseStartedEvent`、回復の泉、再生の特性、盤の上の効果、**状態の期限**、最後にクールダウン。
  外れる順は、駒の番号の順、同じ駒なら種類の番号の順。

## 能力値の補正（一時的な補正の層）

- 能力値の補正のある状態（`Status.bonus`。いまは照準の射程）は、付いている間だけ、駒の実効値の 3 つめの層
  「一時的な補正」（`Unit.temporary_bonus`。`docs/player-loadout.md`）に足される。
- **足すのは付けたとき、引くのは外れたとき**で、どちらも `Statuses.add` / `Statuses.remove` の中でだけ起きる。
  状態が外れる道（期限、使い切り、移動）は、どれも `Statuses.remove` を通るので、**補正の期限は、状態の期限そのもの**になる。
  補正だけを別に数えることはしない。
- 補正で最大 HP が変わる状態を足したときも、HP は決まりどおりに合う（`Unit.follow_max_hp`）。
- 後から足す補正（たとえば「次のターンのあいだ攻撃力 −3」）は、状態の種類を 1 つ足し、`Status.bonus` に量を書き、
  `Statuses.add(駒, 種類, ターン数)` で付ける。期限と複製は、そのまま乗る。

## 動くと外れる状態

- 動くと外れる状態（`Status.breaks_on_move`。いまは照準）は、駒が**ほかのマスへ動いたとき**に外れる
  （`MoveAction` が、移動のイベントのあとに `StatusRemovedEvent`、`MOVED`）。巡航でも、ポータルを通っても同じ。
- **動かない移動（いまのマスを行き先にする）では外れない。**
- **移動を取り消すと戻る。** 外す前の状態を駒が覚えていて（`Unit.statuses_before_move`）、`UndoMoveAction` が
  残りのターン数ごと付け直す（`MoveUndoneEvent` のあとに `StatusAppliedEvent`）。
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

1. `Status.Type` に 1 つ足し、名前（`display_name`）と、当てはまる決まり（`bonus`、`blocks_damage`、`critical_percent`、
   `ends_on_attack`、`breaks_on_move`）に書く。数値は、付けるスキルのファイルの調整値を読む。
2. 付けるスキルの効果（`Skill.apply`）で `Statuses.add` を呼ぶ。
3. ダメージの解決への新しい割り込み方が要るなら、`Hit`（`docs/combat.md` の「ダメージの解決」）に段を足す。

期限、複製、移動の取り消し、画面の再生（状態の名前を出す）と駒の情報は、足した状態にそのまま効く。
