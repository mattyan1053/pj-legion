# 対戦の設定

コード: `rules/match_setup.gd`（`MatchSetup`）。テスト: `tests/rules/test_match_setup.gd`。
シーンの遷移（タイトル、ステージ選択、編成の画面、リザルト）は画面の話なので、ここには無い（`docs/scene-flow.md`、`docs/deck-screen.md`）。

## 持つもの

1 回の対戦を始めるのに要るものを、1 つの値にまとめる。添字はプレイヤー番号（0 = プレイヤー1 = 先手、1 = プレイヤー2 = 後手）。

| 値 | 中身 |
| --- | --- |
| `stage` | ステージ（`BoardGenerator.Stage`）。名前は `MatchSetup.stage_name()`（中央平原・迷宮回廊・双子結晶） |
| `battle_seed` | 盤面の生成と、対戦の乱数（`Battle.rng`）の両方に使う種 |
| `board_size` | 盤面の大きさ（既定は `BoardGenerator.DEFAULT_SIZE`） |
| `decks` | プレイヤーごとの編成（`Deck`。軍を含む） |
| `controllers` | プレイヤーごとに、人（`HUMAN`）が動かすか CPU（`CPU`）が動かすか |

- **先手・後手**は、どちらのプレイヤー番号を人が動かすかで表す。ルールでは、いつもプレイヤー1 から動く（`docs/turn-phase.md`）。
- **CPU の編成**は、その軍の CPU の編成（`CpuDeck`。`docs/cpu-ai.md`）。`set_cpu(プレイヤー, 軍)` が作る。
  CPU の軍は、対戦を始める側が選ぶ。
- **人の編成**は、渡したもの（`set_human(プレイヤー, 編成)`）。試作では、編成の画面で組んで取っておいた部隊か、
  軍ごとの既定の編成 `MatchSetup.default_deck(軍)`（中身は CPU の編成と同じ。予算どおり）。
- よく使う組み合わせ: `MatchSetup.versus_cpu(ステージ, 種, 人の編成, CPU の軍, 人のプレイヤー)`、
  `MatchSetup.versus_human(ステージ, 種, 先手の編成, 後手の編成)`。
- 読むもの: `is_cpu(プレイヤー)`、`cpu_sides()`（CPU が動かすプレイヤー番号の並び。小さい順）、
  `army_of(プレイヤー)`（編成が無ければ `Army.NONE`）。

## 対戦を作る

`create_battle()` が、盤面を作り（`docs/game-board.md`）、両方の軍を本陣に置いた（`Deployment`。`docs/player-loadout.md`）、
ターン 1・プレイヤー1 の番の対戦を返す。設定は変えないので、同じ設定から何度でも同じ対戦が作れる。

**対戦はこの入口だけから作る。** 試作の画面、検査の自動の対戦（`game/autoplay.gd` の通しの対戦）、
CPU どうしの集計の道具（`tools/cpu_matches.gd`）が同じ入口を通る。
例外は、テストと、自動の対戦の中の場面ごとの小さな盤面（`Battle.new` で直に作る）だけ。

始められない設定なら、何も作らずに `null`。理由は `problems()`（空なら `is_valid()`）。

| 理由（`MatchSetup.Problem`） | 条件 |
| --- | --- |
| `NO_DECK` | 編成の無いプレイヤーがいる |
| `INVALID_DECK` | 編成の検査（`Deck.problems()`。`docs/deck-building.md`）を通らないプレイヤーがいる |
| `NO_BOARD` | 盤面が小さすぎて作れない（`BoardGenerator.MIN_SIZE` より小さい） |

- 編成の検査を通ったものだけを対戦に出す（人の編成も CPU の編成も同じ）。
- 例外は `ignore_budget` だけ。立てると、予算を超えた編成（`OVER_BUDGET`）を通す。ほかの理由は通さない。
  集計の道具の「両軍とも同じ役割の 6 体」（`--decks=even`）だけが使う。対戦の画面は使わない。

## 試作の入口

試作（`game/`）は、対戦の前に設定画面（`docs/battle-view.md` の「対戦の設定」）で選んだものを
`game/trial_setup.gd` が `MatchSetup` にして、`create_battle()` で始める。
