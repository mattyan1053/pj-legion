# 戦いの定義

コード: `rules/scenario.gd`（`Scenario`）。テスト: `tests/rules/test_scenario.gd`。

1 回の戦いの、作り置きの変わらないところ。対戦設定（`MatchSetup`。`docs/match-setup.md`）が 1 つ持ち、
対戦を作るとき（`MatchSetup.create_battle()`）だけ読む。
種、人が選んだ部隊、誰が動かすかは 1 回ぶんの選択なので、対戦設定の側に置く。

対戦モード（`game/versus_fields.gd` の `scenario_of`）もストーリーの 1 話（`game/story_battle.gd`）も、戦いの定義を 1 つ渡して対戦を作る。

## 持つもの

添字はプレイヤー番号（0 = プレイヤー1、1 = プレイヤー2）。

| 値 | 中身 |
| --- | --- |
| `title` | 画面に出す名前 |
| `hand_map` | 盤の出どころ（手で作ったマップ）。`HandMap`（`docs/hand-map.md`）。あれば、下の 2 つは使わない |
| `stage`、`board_size` | 盤の出どころ（生成）。生成するマップ（`BoardGenerator.Stage`）と盤の大きさ（`docs/game-board.md`） |
| `deploy_cells` | プレイヤーごとの初期位置。将でない駒を置くマスの列（編成の並びの順に使う）。空なら、いつもの「本陣の前」の置き方 |
| `fixed_decks` | プレイヤーごとの決め打ちの部隊（`Deck`）。`null` なら、対戦設定で選んだ編成を出す |
| `win_conditions` | プレイヤーごとの勝ちの条件の列（`GameWonEvent.Reason`。`docs/win-conditions.md`）。既定は両方とも `STANDARD_WIN_CONDITIONS`（将の撃破と本陣の占拠） |
| `hold_turns` | 「守り切る」のターン数（`docs/win-conditions.md`）。0 なら働かない |
| `start_growth` | プレイヤーごとの、駒の始めのレベルと経験値（`[レベル, 経験値]` の列。部隊の並びの順に、将でない駒へ当てる。列より後ろの駒はいつもどおり）。既定は空。`set_start_growth(プレイヤー, 列)` で決める。対戦を作るとき、置いた駒へ写す（`Growth.start_at`。下の「始めのレベル」）。対戦モードは使わない |
| `start_gauge` | プレイヤーごとの、対戦の始めの必殺技のゲージ（`docs/tactical-ult.md`）。既定は 0。`set_start_gauge(プレイヤー, 量)` で決める（0 から `Ults.GAUGE_MAX` に収める）。対戦を作るときに対戦へ写す。対戦モードの定義（`Scenario.versus`、`Scenario.on_map`）は、先手だけ `Ults.FIRST_PLAYER_START_GAUGE`（先手の埋め合わせ。`docs/tactical-ult.md`）。ストーリーの話は、話の `start_gauge` で置き換える |

- 盤は `make_board(種)` が作る。作れなければ `null`（`can_make_board()`）。生成は、大きさが `BoardGenerator.MIN_SIZE` より小さいと作れない。
  手で作ったマップは、マップの検査（`HandMap.problems()`）を通らないと作れない。種と `board_size` は使わず、いつも同じ盤になる。
- **初期位置**（`set_deploy_cells(プレイヤー, マスの列)`）は、マップではなく戦いの定義が持つ。同じマップを、初期位置を変えて使い回せる。
  将はいつも本陣に置く。置き方は `Deployment`（`docs/player-loadout.md`）。
- **決め打ちの部隊**（`fix_deck(プレイヤー, 部隊)`）は、編成の決まりの検査（`Deck.problems()`。`docs/deck-building.md`）を通さず、
  書いたとおりに置く。数・コスト上限・ロスターの決まりを超えた敵（数で押す敵）を作れる。置き方はいつもと同じ（`Deployment`）。
  そのプレイヤーの選んだ編成（`MatchSetup.decks`。CPU の編成を含む）は使わない。誰が動かすかは、対戦設定が決める。

- **勝ちの条件**（`set_win_conditions(プレイヤー, 条件の列)`）も、マップではなく戦いの定義が持つ。同じマップを、勝ち方を変えて使い回せる。
  対戦を作るとき（`create_battle()`）に対戦へ写す。対戦の側の列を変えても、定義は変わらない。
  `hold_for(プレイヤー, ターン数)` は、そのプレイヤーを守る側にする（勝ちの条件に守り切るを足し、`hold_turns` を決める）。

### 始めのレベル

進化の選び方を教える話（`docs/story.md`）が、あと少しで進化する駒から始めるために使う。

- 置いた駒を、レベルアップと同じ量（`Growth.GAINS`）だけ伸ばし、そのレベルと経験値にする。HP も伸びたぶん増える。イベントは出さない（対戦の前なので）。
- 進化は対戦の中で選ぶ（`docs/branch-evolution.md`）。レベルは上限の 1 つ手前まで、経験値は 1 レベルに要る量の 1 つ手前までに収める（置いた直後にレベルが上がらない）。
- 育たない駒（将、中立の駒）には当てない。置けずに飛ばした駒があると、後ろの駒へずれる（話のファイルの検査が、置けないマスを弾く）。

## 作り方

- `Scenario.versus(マップ)`（下の「対戦モード」）。
- `Scenario.on_map(マップ, 名前)`: 手で作ったマップの定義。初期位置と決め打ちの部隊は無し（あとから足す）。対戦モードの手で作ったマップと、ストーリーの話が使う。

## 対戦モード

生成のマップは `Scenario.versus(マップ)`: 名前は空（画面が、マップから画面の文の表の名前を引いて入れる。`game/versus_fields.gd`）、盤はそのマップの生成（大きさは既定）、
決め打ちの部隊は無し（両方とも、対戦設定で選ぶ）、勝ちの条件は既定、先手の必殺技のゲージは 75% から（`start_gauge`。先手の埋め合わせ。`docs/tactical-ult.md`）。
手で作ったマップは `Scenario.on_map`（名前はマップのファイルの `title`）で、ほかは同じ。どちらを選べるかは `game/versus_fields.gd`（`docs/map-select.md`）。
`MatchSetup.versus_cpu` / `versus_human` は、これを持った対戦設定を作る。
