# 対戦の画面に渡すもの

コード: `game/battle_source.gd`（既定の答え）、`game/match_choice.gd`（対戦モード）、`game/battle_screen.gd`（受け取る側）。
テスト: `tests/game/test_match_choice.gd`、自動の対戦（`game/autoplay.gd` の `setup`。何も選び直せない対戦を渡して、入口が出ないことを見る）。

対戦の画面は、どのモードの対戦かを知らない。「対戦の設定（`MatchSetup`）を作ってくれるもの」を 1 つ受け取り、
対戦を作るのも、やり直すのも、選び直す入口を出すかも、それに聞く。

## 受け取り方

- 流れ（`docs/scene-flow.md` の「流れ」）が対戦の場面に渡すもの。対戦モードは、対戦の設定の「対戦を始める」で、選んだものの写しを渡す。
- 流れの外から置かれた対戦の場面（スクリーンショットの道具など）は、`context.match_choice` の写しで始める。

## 聞くこと

| 聞くこと | 既定の答え（`battle_source.gd`） | 対戦モード（`match_choice.gd`） | 画面のどこが使うか |
| --- | --- | --- | --- |
| `make_setup(種)` | 無し（継いだ側が必ず書く） | 選んだもので `MatchSetup` を作る | 対戦を作る・やり直す |
| `look()` | 既定の見た目 | ステージの見た目（`StageLook.OF_STAGE`） | 盤・ミニマップ・空と光（`stage_look.gd`） |
| `cpu_side()` | プレイヤー2 | 人の手番の反対 | CPU が動かす（切り替えたら動かす）プレイヤー |
| `can_switch_opponent()` | できない | できる | F4、下の帯の「相手」のボタン |
| `stages()` | 無し | 3 つのステージ | F1〜F3、決着の画面の「新しい盤面」 |
| `can_open_setup()` | できない | できる | システムメニューの「対戦の設定へ」、決着の画面の「対戦の設定へ」 |

- **誰が動かすか**は、作った `MatchSetup` の `controllers` から読む（`cpu_side()` のプレイヤーが CPU か）。
  対戦の途中の切り替え（F4）は、次に作る対戦にも持ち越す（`set_cpu_opponent`）。
- 決着の画面の「作戦領域」は、戦いの定義の名前（`MatchSetup.scenario.title`）。
- 「同じ盤面でもう一度」と「タイトルへ」は、いつも出す。

## モードを足すとき

`battle_source.gd` を継いで、`make_setup` と、既定と違う答えだけを書く。既定は「何も選び直せない対戦」。
