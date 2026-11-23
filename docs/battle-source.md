# 対戦の画面に渡すもの

コード: `game/battle_source.gd`（既定の答え）、`game/match_choice.gd`（対戦モード）、`game/story_battle.gd`（ストーリーの話。`docs/story.md`）、`game/battle_screen.gd`（受け取る側）。
テスト: `tests/game/test_match_choice.gd`、`tests/game/test_story.gd`、自動の対戦（`game/autoplay/setup_checks.gd` の場面 `setup`。何も選び直せない対戦を渡して、入口が出ないことを見る）。

対戦の画面は、どのモードの対戦かを知らない。「対戦設定（`MatchSetup`）を作ってくれるもの」を 1 つ受け取り、
対戦を作るのも、やり直すのも、選び直す入口を出すかも、それに聞く。

## 受け取り方

- 流れ（`docs/scene-flow.md` の「流れ」）が対戦の場面に渡すもの。対戦モードは、対戦設定の「対戦開始」で、選んだものの写しを渡す。
- 流れの外から置かれた対戦の場面（スクリーンショットの道具など）は、`context.match_choice` の写しで始める。

## 聞くこと

| 聞くこと | 既定の答え（`battle_source.gd`） | 対戦モード（`match_choice.gd`） | ストーリーの話（`story_battle.gd`） | 画面のどこが使うか |
| --- | --- | --- | --- | --- |
| `make_setup(種)` | 無し（継いだ側が必ず書く） | 選んだもので `MatchSetup` を作る | 話のマップと決め打ちの敵で作る | 対戦を作る・やり直す |
| `shows_signs()` | 出さない | 縫い目の様子が入なら出す | 既定のまま | 対戦を始める前の、札がめくられる窓（`docs/battle-view.md` の「縫い目の様子」） |
| `music()` | 見た目の曲（`SoundCatalog.battle_music`） | 既定のまま | 話のファイルの `music`（無ければ見た目の曲） | 対戦の曲（`docs/sound.md`） |
| `climax_music()` | いつもの終盤の曲（`CLIMAX_MUSIC`） | 既定のまま | 話のファイルの `climax_music`（無ければ既定） | 終盤の曲（`docs/sound.md`） |
| `victory_mood()` | 明るい（`MOOD_BRIGHT`） | 既定のまま | 話のファイルの `victory_mood`（無ければ明るい） | 勝ったときの調子。静かならファンファーレを鳴らさない（`docs/sound.md`） |
| `after_result_music()` | 静かな曲（`AFTER_RESULT_MUSIC`） | 既定のまま | その話のあとの会話の曲 | 決着の曲のあとに続ける曲 |
| `king_looks()` | 無し（将の姿） | 既定のまま | 話のファイルの `king_figure` | 将の姿（見た目だけ） |
| `look()` | 既定の見た目 | マップの見た目（`VersusFields.look_of`） | 話の見た目（`Episode.look`。マップのファイルの `look`、話のファイルが `look` を書けばそれ） | 盤・ミニマップ・空と光（`stage_look.gd`） |
| `cpu_side()` | プレイヤー2 | 人の手番の反対 | 既定のまま | CPU が動かす（切り替えたら動かす）プレイヤー |
| `can_switch_opponent()` | できない | できる | 既定のまま | F4、下の帯の「相手」のボタン |
| `new_board_fields()` | 無し | 生成のマップの鍵（`game/versus_fields.gd`。手で作ったマップは入れない。`docs/map-select.md`） | 既定のまま | F1〜F3、決着の画面の「新しいマップ」 |
| `can_open_setup()` | できない | できる | 既定のまま | システムメニューの「対戦設定へ」、決着の画面の「対戦設定へ」 |
| `can_continue(人が勝ったか)` | 出さない | 既定のまま | 勝ったら出す | 決着の画面の「次へ」（押すと `Run.NEXT` で終わり、流れの次の場面へ） |
| `retries_on_enter(人が勝ったか)` | しない | 既定のまま | 勝たなければする | 決着の画面の Enter を「同じマップで再戦」にする（「次へ」が無いとき。しなければ `leave()` の行き先へ） |
| `leave()` | タイトル（「タイトルへ」） | マップ選択（「マップ選択へ」） | 話の一覧（「話の一覧へ」） | 決着の画面の、流れの外への行き先のボタン（`[終わり方, 文の鍵]`） |
| `can_choose_squad()` | 出さない | 既定のまま | 出す | 決着の画面の「部隊変更」（押すと `Run.PREVIOUS` で終わり、流れの 1 つ前の場面 = 出撃準備へ） |
| `talk_cues()` | 台詞なし | 既定のまま | 話のファイルの `[cues]` | 対戦の途中の会話（`docs/story.md` の「対戦の途中の会話」。新しい対戦を始めるたびに作る） |
| `lost_lines()` | 無し | 既定のまま | 話のファイルの `[lost]` | 負けたときの台詞（決着の画面の戦績の左に出す。`docs/result-screen.md`） |
| `record_win(context)` | 何もしない | 既定のまま | 話をクリアしたと書く | CPU と対戦して人が勝った（決着の画面が出たとき） |

- **誰が動かすか**は、作った `MatchSetup` の `controllers` から読む（`cpu_side()` のプレイヤーが CPU か）。
  対戦の途中の切り替え（F4）は、次に作る対戦にも持ち越す（`set_cpu_opponent`）。
- 決着の画面の「マップ」は、戦いの定義の名前（`MatchSetup.scenario.title`）。
- 「同じマップで再戦」と、流れの外への行き先（`leave()`）は、いつも出す。

## モードを足すとき

`battle_source.gd` を継いで、`make_setup` と、既定と違う答えだけを書く。既定は「何も選び直せない対戦」。
