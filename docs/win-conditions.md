# 勝ち負け

コード: `rules/battle.gd`（`winner`、`is_over`、`is_draw`、`capture_turns`、`count_capture`）、`rules/actions/end_phase_action.gd`、
`rules/events/game_won_event.gd`、`rules/events/game_drawn_event.gd`、`rules/events/capture_progress_event.gd`。
テスト: `tests/rules/test_victory.gd`、引き分けは `tests/rules/test_map_objects.gd`。

どちらかが満たされた時点で決着し、`GameWonEvent`（勝った陣営と理由）が出る。決着したあとは、どの行動も受け付けない。

- 決着したかは `Battle.is_over()`、勝った陣営は `Battle.winner`（決着していないか、引き分けなら -1）。

## 敵の将を倒す

- 将が倒れたら、その相手のプレイヤーの勝ち。倒した行動の結果の最後に `GameWonEvent` が付く。
- 誰が倒したかは問わない。起爆樽の爆発（`docs/map-objects.md`）で自分の将を倒したら、相手の勝ち。

## 引き分け

- **1 つの行動で両方の将が倒れたら、引き分け**（起爆樽の爆発に両方の将が巻き込まれたとき）。
- `GameWonEvent` のかわりに、行動の結果の最後に `GameDrawnEvent`（理由）が付く。
- `Battle.is_over()` と `Battle.is_draw()` が真になり、`Battle.winner` は -1 のまま。決着なので、どの行動も受け付けない。

## 敵の本陣を占拠し続ける

- 自分のフェーズの終わり（ターン終了）に、敵の本陣のマスに自分の駒が乗っていれば、占拠の数が 1 進む。
  乗っていなければ 0 に戻る。
- 占拠の数が **3** に達したら、そのプレイヤーの勝ち。そのフェーズのあとへは進まない。
- 入っただけでは数えない（数えるのはフェーズの終わり）。
- 本陣のマスから自分の駒がいなくなったら（動いた・倒された）、その時点で 0 に戻る。
  ただし、その移動を取り消したら、動く前の数に戻る。
- 占拠の数が変わったときに `CaptureProgressEvent`（プレイヤーと、いまの数）が出る。
- 自分の本陣に乗っても数えない。
