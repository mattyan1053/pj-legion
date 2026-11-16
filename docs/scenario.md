# 戦いの定義

コード: `rules/scenario.gd`（`Scenario`）。テスト: `tests/rules/test_scenario.gd`。

1 回の戦いの、作り置きの変わらないところ。対戦の設定（`MatchSetup`。`docs/match-setup.md`）が 1 つ持ち、
対戦を作るとき（`MatchSetup.create_battle()`）だけ読む。
種、人が選んだ部隊、誰が動かすかは 1 回ぶんの選択なので、対戦の設定の側に置く。

対戦モードもストーリーの 1 話も、戦いの定義を 1 つ渡すだけで対戦を作れるようにするための土台（Issue #49）。
欄は、使う機能が入るときに足す（いまある勝ち方や初期位置の決め方は、まだ定義の欄になっていない）。

## 持つもの

添字はプレイヤー番号（0 = プレイヤー1、1 = プレイヤー2）。

| 値 | 中身 |
| --- | --- |
| `title` | 画面に出す名前 |
| `stage`、`board_size` | 盤の出どころ。生成するステージ（`BoardGenerator.Stage`）と盤の大きさ（`docs/game-board.md`） |
| `fixed_decks` | プレイヤーごとの決め打ちの部隊（`Deck`）。`null` なら、対戦の設定で選んだ編成を出す |

- 盤は `make_board(種)` が作る。作れない大きさ（`BoardGenerator.MIN_SIZE` より小さい）なら `null`（`can_make_board()`）。
- **決め打ちの部隊**（`fix_deck(プレイヤー, 部隊)`）は、編成の決まりの検査（`Deck.problems()`。`docs/deck-building.md`）を通さず、
  書いたとおりに置く。数・予算・ロスターの決まりを超えた敵（数で押す敵）を作れる。置き方はいつもと同じ（`Deployment`）。
  そのプレイヤーの選んだ編成（`MatchSetup.decks`。CPU の編成を含む）は使わない。誰が動かすかは、対戦の設定が決める。

## 対戦モード

`Scenario.versus(ステージ)`: 名前はステージの名前（`MatchSetup.stage_name()`）、盤はそのステージの生成（大きさは既定）、
決め打ちの部隊は無し（両方とも、対戦の設定で選ぶ）。
`MatchSetup.versus_cpu` / `versus_human` は、これを持った対戦の設定を作る。
