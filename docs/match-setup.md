# 対戦設定

コード: `rules/match_setup.gd`（`MatchSetup`）。テスト: `tests/rules/test_match_setup.gd`、`tests/rules/test_deployment_zone.gd`（人が決めた置き方）。
場面の遷移（タイトル、マップ選択、部隊編成、決着の画面）は画面の話なので、ここには無い（`docs/scene-flow.md`、`docs/deck-screen.md`）。

## 持つもの

1 回の対戦を始めるのに要るものを、1 つの値にまとめる。添字はプレイヤー番号（0 = プレイヤー1 = 先手、1 = プレイヤー2 = 後手）。

| 値 | 中身 |
| --- | --- |
| `scenario` | 戦いの定義（`Scenario`。盤の出どころ、初期位置、決め打ちの部隊、勝ちの条件。`docs/scenario.md`）。既定は対戦モードの中央平原 |
| `battle_seed` | 盤面の生成と、対戦の乱数（`Battle.rng`）の両方に使う種 |
| `decks` | プレイヤーごとの選んだ編成（`Deck`。軍を含む）。戦いの定義が部隊を決め打ちにしているプレイヤーの分は使わない |
| `controllers` | プレイヤーごとに、人（`HUMAN`）が動かすか CPU（`CPU`）が動かすか |
| `placements` | プレイヤーごとの、人が決めた置き方（本陣からのずれ。空ならいつもの置き方。`docs/player-loadout.md`） |

- **先手・後手**は、どちらのプレイヤー番号を人が動かすかで表す。ルールでは、いつもプレイヤー1 から動く（`docs/turn-phase.md`）。
- **CPU の編成**は、その軍の CPU の編成（`CpuDeck`。`docs/cpu-ai.md`）。`set_cpu(プレイヤー, 軍)` が作る。
  CPU の軍は、対戦を始める側が選ぶ。CPU にほかの部隊を渡すときは、`set_cpu` のあとで `decks` を置き換える
  （対戦モードの画面の CPU の行で選んだ部隊。CPU はどの部隊でも動かせる。下の「画面の入口」）。
- **人の編成**は、渡したもの（`set_human(プレイヤー, 編成)`）。対戦モードの画面では、部隊編成で組んで取っておいた部隊か、
  軍ごとの既定の編成 `MatchSetup.default_deck(軍)`（中身は CPU の編成と同じ。コスト上限どおり）。ストーリーでは、出撃準備で選んだ部隊か、ストーリーの既定の編成（`docs/story.md`）。
- 人と CPU の対戦は `MatchSetup.on_scenario(戦いの定義, 種, 人のプレイヤー, 人の編成, CPU の軍)` から作る（どのモードもここを通す）。
  CPU の側の部隊を戦いの定義が決め打ちにしていれば（ストーリーの話の敵）、CPU の編成は作らない（CPU の軍は要らない）。
- よく使う組み合わせ: `MatchSetup.versus_cpu(マップ, 種, 人の編成, CPU の軍, 人のプレイヤー)`（`on_scenario` に対戦モードのマップの戦いの定義を渡す）、
  `MatchSetup.versus_human(マップ, 種, 先手の編成, 後手の編成)`（`MatchSetup.humans_on(戦いの定義, 種, 先手の編成, 後手の編成)` に対戦モードのマップの戦いの定義を渡す。人どうしは、どのモードも `humans_on` を通す）。どちらも、戦いの定義は対戦モードのそのマップ（`Scenario.versus`）。
  マップの名前（中央平原・迷宮回廊・双子結晶）は画面の文の表（`game/names.gd` の `stage`。`docs/text.md`）。ルールは持たない。
- 読むもの: `is_cpu(プレイヤー)`、`cpu_sides()`（CPU が動かすプレイヤー番号の並び。小さい順）、
  `deck_of(プレイヤー)`（対戦に出す編成。決め打ちの部隊があればそれ、無ければ選んだ編成）、
  `army_of(プレイヤー)`（`deck_of` の軍。編成が無ければ `Army.NONE`）。

## 対戦を作る

`create_battle()` が、戦いの定義から盤面を作り（`docs/game-board.md`）、両方の軍（`deck_of`）を置き（人が決めた置き方 `placements` があればそこ、ほかは初期位置があればそこ、無ければ本陣の前。`Deployment`。`docs/player-loadout.md`）、勝ちの条件を写した、
ターン 1・プレイヤー1 の番の対戦を返す。設定は変えないので、同じ設定から何度でも同じ対戦が作れる。

**対戦はこの入口だけから作る。** 対戦の画面、検査の自動の対戦（`game/autoplay.gd` の通しの対戦）、
CPU どうしの集計の道具（`tools/cpu_matches.gd`）が同じ入口を通る。
例外は、テストと、自動の対戦の中の場面ごとの小さな盤面（`Battle.new` で直に作る）だけ。

始められない設定なら、何も作らずに `null`。理由は `problems()`（空なら `is_valid()`）。

| 理由（`MatchSetup.Problem`） | 条件 |
| --- | --- |
| `NO_DECK` | 編成の無いプレイヤーがいる（決め打ちの部隊のあるプレイヤーは数えない） |
| `INVALID_DECK` | 編成の検査（`Deck.problems()`。`docs/deck-building.md`）を通らないプレイヤーがいる（同じ） |
| `NO_BOARD` | 戦いの定義の盤を作れない（`Scenario.can_make_board()`） |

- 選んだ編成は、検査を通ったものだけを対戦に出す（人の編成も CPU の編成も同じ）。
  戦いの定義の決め打ちの部隊は、検査を通さない（`docs/scenario.md`）。
- 例外は `ignore_budget` だけ。立てると、コスト上限を超えた編成（`OVER_BUDGET`）を通す。ほかの理由は通さない。
  テストのほかは、集計の道具の「両軍とも同じ役割の 6 体」（`--decks=even`）だけが使う。対戦の画面は使わない。

## 画面の入口

画面の側（`game/`）は、対戦モードでは、対戦の前に設定画面（`docs/battle-view.md` の「対戦設定」）で選んだものを
`game/match_choice.gd` が `MatchSetup` にし、ストーリーでは話のデータから `game/story_battle.gd` が作って、`create_battle()` で始める。対戦の画面は `MatchChoice` を直に読まず、
「`MatchSetup` を作ってくれるもの」（`game/battle_source.gd`。`docs/battle-source.md`）として受け取る。

対戦モードの部隊は、人の行も CPU の行も同じ選び方（`match_choice.gd`）: 既定の編成（CPU の行では CPU の編成）、取っておいた部隊、ランダム編成。

### ランダム編成

コード: `game/random_squad.gd`（`RandomSquad`）。テスト: `tests/game/test_match_choice.gd`。

- 対戦を作るたびに、対戦の決まりの中でランダムに組む（`RandomSquad.for_battle(軍, 対戦の種, プレイヤー)`）。
  その軍のロスターから、種で決まる順に、数の上限まで予算の中で雇い、余った予算で、種で決まる駒に種で決まる持ち物を持たせる。並びは役割の順。
- 種は対戦の種から引く（`対戦の種 × 2 + プレイヤー番号`）。同じ種なら同じ部隊（「同じ盤面で再戦」は同じ部隊、「新しい盤面」は新しい部隊）。
  手番がランダムなら、引いた側（実際に動かすプレイヤー）の番号で組む。
- CPU どうしの集計の道具の `--squads=random`（対戦モード）も、同じ組み方を使う（`docs/cpu-ai.md`）。
- 組んだ部隊は、選んだもの（`match_choice.gd` の `drawn_decks`）に残り、対戦の途中の対戦設定のパネルの「編成確認」で見られる。
