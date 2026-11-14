# 勝ち負け

コード: `rules/battle.gd`（`winner`、`capture_turns`、`count_capture`）、`rules/actions/end_phase_action.gd`、
`rules/events/game_won_event.gd`、`rules/events/capture_progress_event.gd`。
テスト: `tests/rules/test_victory.gd`。

どちらかが満たされた時点で決着し、`GameWonEvent`（勝った陣営と理由）が出る。決着したあとは、どの行動も受け付けない。

## 敵の将を倒す

- 将が倒れたら、その相手のプレイヤーの勝ち。倒した行動の結果の最後に `GameWonEvent` が付く。

## 敵の本陣を占拠し続ける

- 自分のフェーズの終わり（ターン終了）に、敵の本陣のマスに自分の駒が乗っていれば、占拠の数が 1 進む。
  乗っていなければ 0 に戻る。
- 占拠の数が **3** に達したら、そのプレイヤーの勝ち。そのフェーズのあとへは進まない。
- 入っただけでは数えない（数えるのはフェーズの終わり）。
- 本陣のマスから自分の駒がいなくなったら（動いた・倒された）、その時点で 0 に戻る。
- 占拠の数が変わったときに `CaptureProgressEvent`（プレイヤーと、いまの数）が出る。
- 自分の本陣に乗っても数えない。
