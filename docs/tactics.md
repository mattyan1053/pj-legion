# 作戦（試しの決まり）

コード: `rules/tactics.gd`（札の種類、手札、使う、調整値）、`rules/actions/use_tactic_action.gd`、
`rules/events/tactic_used_event.gd`、`rules/events/tactic_healed_event.gd`、`rules/battle.gd`（`tactics`、`tactics_used`）、
`rules/status.gd`（強行軍）、`rules/cpu_player.gd`（CPU が使うか）。
テスト: `tests/rules/test_tactics.gd`、`tests/game/test_match_choice.gd`、`tests/game/test_match_setup_panel.gd`。

対戦の前に選んだ札を、対戦中に 1 回ずつ使う。編成に「いつ切るか」を選ぶ要素を足す試し（Issue #47 の「デッキ編成的な要素」）。
**試しの決まり `TrialRules.TACTICS` が入の対戦にだけある**（`docs/match-setup.md` の「試しの決まり」。既定は切）。切の対戦では、手札が空で、何も起きない。

## 手札

- プレイヤーごとに、札を 2 枚（`Tactics.HAND_SIZE`）選ぶ。**予算の外**（コストは無い。部隊の編成とは別に選ぶ）。札は両方の軍に共通。
- 選ぶのは対戦設定（`MatchSetup.tactics`。画面では、軍の行の右の札のボタン）。選ばなかったぶんは、既定の札（強行軍、補給。`Tactics.DEFAULT_HAND`）で埋める
  （`Tactics.hand_from`。知らない札と重なりは捨て、枚数まで）。CPU の手札は、対戦設定の CPU の行で選んだもの（選ばなければ既定）。
- 対戦は、手札（`Battle.tactics`）と、使った札（`Battle.tactics_used`）を持つ。`Battle.clone()` はどちらも写す。
- 相手の手札は隠さない（いまは、どちらの手札も対戦設定で見える）。

## 使う

`Battle.apply(UseTacticAction.new(札))`。いまのフェーズのプレイヤーが、手札の札を 1 枚使う。駒も対象も指さない。

- 使えるのは、**自分のフェーズで、手札にあり、まだ使っていない札**（`Tactics.can_use`）。決着のあとと、進化先を選ぶのを待っている間は使えない。
- **同じ札は、1 回の対戦に 1 回だけ。** 同じフェーズに、ほかの札は使える。
- **駒の行動を使わない**（必殺技と同じ「プレイヤーの行動」。`docs/tactical-ult.md`）。駒が行動の途中でも使え、そのあとの移動の取り消しもできる。作戦そのものは取り消せない。
- イベントは順に、`TacticUsedEvent`（陣営、札）、効果のイベント。

## 札

| 札 | 効果 | 効果のイベント |
| --- | --- | --- |
| 強行軍（`MARCH`） | 軍の全員の移動力 +2（`Tactics.MARCH_MOVE`）。このフェーズの間だけ | 駒ごとの `StatusAppliedEvent`（状態「強行軍」。`Status.Type.MARCH`） |
| 補給（`SUPPLY`） | 軍の全員が HP を 8（`Tactics.SUPPLY_HEAL`）回復（最大 HP は超えない） | 回復した駒ごとの `TacticHealedEvent`（減っていない駒には出ない） |
| 号令（`RALLY`） | 必殺技のゲージ +25%（`Tactics.RALLY_GAIN` = 250） | いっぱいになったら、最後に `UltReadyEvent` |
| 加護（`WARD`） | 将にバリア（次に受けるダメージを 1 回だけ防ぐ。2 ターン（`Tactics.WARD_TURNS`）。`docs/unit-statuses.md`） | `StatusAppliedEvent` |

- 強行軍は、総員突撃の突撃と同じ数え方（次の自分の番の始めに外れる。もう行動を終えた駒には、得が無い）。攻撃力は変わらない。突撃と重なれば、両方が足される。
- 号令は、必殺技を持たないプレイヤー（軍の決まっていない群れ）には何も起きない。
- どの札も、対象を選ばない。

## CPU

CPU は、まだ動かす駒を決めていないとき（駒の行動の途中でないとき）に、手札の札を順に見て、いま使うのが得なら使う（`CpuPlayer.TACTIC_USES`。札 → 決めるメソッド）。

| 札 | 使うとき |
| --- | --- |
| 強行軍 | まだ動いていない戦う駒（前衛・後衛・奇襲。1 体もいなければ将）のうち、いまの移動力 + 射程では敵に届かず、+2 すれば届く駒が 2 体（`MARCH_MIN_UNITS`）以上。戦う駒がそれより少なければ、その全員 |
| 補給 | 回復する HP の合計が 20（`SUPPLY_MIN_HEAL`）以上。駒が少なければ、全員が 1 回ぶんずつ減っているとき |
| 号令 | たまるぶんで、ゲージがいっぱいになるとき。ターン 12（`RALLY_BY_TURN`）からは、持ち越さずに使う |
| 加護 | 将がバリアを持たず、いまのマスで次の相手の番に 8（`WARD_MIN_DANGER`）以上のダメージを受けうるとき（危険の見積もり。`docs/cpu-ai.md`） |

- 距離はマンハッタン距離の目安（地形は見ない。総員突撃の使いどころと同じ）。
- **相手の札は読まない。** 相手が強行軍で伸ばしてくる移動力は、危険の見積もりに入れていない（必殺技は読む。`docs/tactical-ult.md` の「CPU」）。
- 入のときの CPU どうしの実測は `docs/cpu-ai.md` の「いまの集計」。

## 画面

- 対戦設定: 「試しの決まり」の行の「作戦」を押して入にすると、軍の行の右に札のボタンが並ぶ（押してあるものが手札。3 枚目を押すと、先に選んだものが外れる。マウスを乗せると説明）。
- 対戦: 下の帯のすぐ上の右端に、手札の札のボタン（自分の番に押せる。マウスを乗せると説明）。取り消せないので、1 回目は確かめるだけ（「もう一度押して使う」）で、もう一度押すと使う。
  確かめは 4 秒ほどで消える。使った札は「（使用済み）」になり、押せない。
- 使うと、中央に知らせ（「作戦: 強行軍」）。効果は、必殺技と同じに、全員ぶんを一度に見せる。ログに 1 行。

## 札を足すとき

1. `Tactics.Id` に 1 つ足し、`Tactics.ALL` に並べ、`Tactics.use` に効果を書く（調整値は `rules/tactics.gd` の先頭）。
2. 名前と説明を `game/text/names.csv` の `tactic.<id>` と `tactic.<id>.summary` に書く（差し込む値は `Tactics.summary_args`）。
3. `CpuPlayer.TACTIC_USES` に 1 行と、いま使うかを決めるメソッドを足す。
