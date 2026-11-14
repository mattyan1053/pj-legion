# 対戦の状態と行動の受け付け

コード: `rules/battle.gd`（`apply`、`can_apply`、`clone`、`rng`）、`rules/action_result.gd`、
`rules/actions/battle_action.gd`、`rules/events/battle_event.gd`、`rules/state_copy.gd`。
テスト: `tests/rules/test_battle.gd`。

1 回の対戦の状態は `Battle` が持つ。状態を変えるのは `Battle.apply(行動)` だけ
（対戦の準備で駒を置く `add_unit` は除く）。

## 行動とイベント

- 行動はすべて `BattleAction` を継承する。いまの状態で受け付けられるかを `is_valid`、状態を進めて起きたことを返すのを
  `execute` に書く。行動は駒を番号で指す。
- 起きたことはすべて `BattleEvent` を継承する。起きた時点の値を持ち、駒は番号で指す。
- `apply` は `BattleAction` しか受け取らない。イベントや駒を渡すと、スクリプトの読み込みの時点でエラーになる。

## apply の結果

`Battle.apply(行動)` は `ActionResult` を返す。

- `accepted` が偽: 行動は断られた。状態は何も変わらず、`events` は空。
- `accepted` が真: 行動を受け付けた。`events` に起きたことが起きた順に並ぶ。
  受け付けたが何も起きなかった行動では、`events` が空になる（断られた行動とは `accepted` で見分ける）。
- 決着したあとは、どの行動も断る（`docs/win-conditions.md`）。
- `Battle.can_apply(行動)` は、状態を変えずに、いま受け付けるかだけを答える（選べる行動を画面に出すときに使う）。

## 複製

`Battle.clone()` は対戦の状態を丸ごと複製する。戦闘予測と CPU の先読みは、複製に `apply` して結果を見る。

- 複製と元は、どちらに `apply` しても、もう片方は変わらない。盤面、駒（位置・HP・行動の状態）、ターン、フェーズ、
  行動の途中の駒、本陣の占拠の数、勝者、駒の番号の採番、乱数のすべてが別になる。
- 駒の番号は元と同じ。元に向けて作った行動を、そのまま複製に渡せる。
- 複製のあとに置いた駒は、元に置いた場合と同じ番号になる。

## 乱数

- 確率で決まるルールは、`Battle.rng` だけを使う。シードは `Battle.new(盤面, シード)` で渡す（省略すると 0）。
- 同じ盤面・同じシード・同じ行動の列からは、いつも同じ結果になる。
- 複製の乱数は、元がこの先に引くはずだった値を同じ順に引く。複製から引いても、元の乱数は進まない。
- 盤面の生成（`BoardGenerator`）は対戦の前に済むので、自分のシードで引く（`docs/game-board.md`）。
