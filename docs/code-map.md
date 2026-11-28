# コードの地図

コード全体がどうつながっているかと、何かを足すときにどの文書を読むか。新しい作業のセッションは、ここから入る。
細かい決まりは、それぞれの機能の文書にある（この文書は道筋だけを書く。行の番号は書かない）。

## 置き場所

| 場所 | 持つもの | 持たないもの |
| --- | --- | --- |
| `rules/` | ルール。ノードに依存しないクラス。行動を受けて、起きたこと（出来事）の列を返す。調整値は、そのクラスの先頭の定数 | 文（列挙と、差し込む値だけ）、`game/` への参照、ノード |
| `game/` | 画面。ルールに聞いて塗り、行動をルールに渡し、返った出来事を再生する。話・マップを読む所、セーブ、音 | ルールの計算（動けるマス・ダメージは `rules/` に聞く）、直書きの文 |
| `game/story/`・`game/maps/`・`game/text/` | データ。物語と話のファイル、手で作ったマップ、画面の文の表 | コード |
| `tests/` | `rules/` の下は ルール、`game/` の下は 画面のノードに依存しない所、`docs/` の下は 文書の数とコードの突き合わせ、`tools/` の下は 道具 | 画面の見た目（自動の対戦とスクリーンショットが見る） |
| `tools/` | 検査（`check.sh`）、CPU どうしの実測（`cpu_matches.gd`）、台本・声・折り返しの点検、スクリーンショット、兵のアイコン | 遊ぶときに使うもの |

`game/app.gd` が場面を切り替える（場面の表は `game/scene_flow.gd`。`docs/scene-flow.md`）。画面をまたぐものは `game/app_context.gd` の 1 つ。autoload は無い。

## 対戦の 1 手

1. **入力** `game/battle_screen/screen_input.gd`: クリックやメニューを行動（`rules/actions/` の `BattleAction` の子）にして `_do` に渡す。
   行動は兵を番号で指すので、写しにもそのまま当てられる。
2. **ルール** `screen_sides.gd` の `_do_all` が `battle.apply(action)` を呼ぶ。遊ぶときの道で対戦の状態を変えるのはここだけ。
   `Battle.apply`（`rules/battle.gd`）: `can_apply` → `action.execute` → 勝ち負けの判定 → `ActionResult`（受け付けたか、出来事の列）。
3. **出来事** `rules/events/`: 起きた時点の値を持つ。ダメージは原因が何でも `rules/hit.gd` を通り、段の順は `rules/combat.gd` の `hit`（`docs/combat.md`）。
   回復は原因が何でも `rules/mend.gd` を通る（`docs/battle.md` の「回復を 1 つ足すとき」）。
4. **読む側**（`_do_all` が順に渡す）:
   - 戦績 `rules/battle_stats.gd`（`docs/battle-stats.md`）
   - 再生 `game/battle_playback.gd` の `play_all` → `battle_playback/playback_base.gd` の `event_players()`（種類 → 再生の関数）。再生と同時にログ `game/battle_log.gd` の `readers()` へ（`docs/battle-log.md`）。
     再生は対戦を読まない。行動をルールに渡す前に写した盤（再生の盤 `game/replay_board.gd`）に、再生しながら出来事を食わせて読む（`docs/battle-view.md` の「再生の盤」）。
     音は再生の関数から鳴らす（`docs/sound.md`）。中立の番は `game/neutral_playback.gd` がまとめる。
     対戦モードのリプレイは、記録（`game/battle_record.gd`。始めの写しと受け付けられた行動）を見えない対戦へ当て直して、同じ道で見せる（`game/battle_screen/screen_replay.gd`。`docs/battle-view.md` の「リプレイ」）。
     盤のカットシーンは、対戦なしで同じ再生を回す（台本 `game/cut_script.gd` → 台本の出来事 `game/cut_events/` → 舞台 `game/cut_stage.gd`。`docs/battle-view.md` の「盤のカットシーン」）。
   - 話の途中の台詞 `game/battle_cues.gd`（ストーリーだけ）
   - 終わると、ルールに聞き直して画面を作り直し（`_refresh`）、CPU の番なら次の手へ。
5. **写しの上で同じ道を走るもの**: 予測 `rules/forecast.gd`（`Battle.clone()` に同じ行動を当てて、出た出来事を読む。`docs/battle-forecast.md`）と、
   CPU `rules/cpu_player.gd`（候補ごとに写しへ当てて、出来事に値を付ける。`docs/cpu-ai.md`）。写しは `rules/state_copy.gd` が変数を名前で拾う。
   別の計算を持つのは脅威範囲（`rules/threat.gd`。届くマス）だけ。CPU の危険の読み（`rules/cpu/cpu_threats.gd`）は、脅威範囲の攻撃の候補を
   ダメージの解決（`Combat.hit_from`）に聞く。
6. **自動の対戦** `game/autoplay.gd`: 人と同じ入口を通して全部の場面を回す。1 度も再生されなかった出来事があると落ちる。

出来事を種類ごとに読む所は、どれも足し忘れをテストが拾う（再生・ログ・戦績・予測・CPU の手の価値・実測の道具・中立の再生・再生の盤。`docs/battle.md` の「出来事を 1 つ足すとき」）。

## 話の 1 話

1. **話のファイル** `game/story/<物語>/<話>.txt`。物語のフォルダは置くだけで並び、話は `story.txt` の `[episodes]` で並ぶ（`game/campaign.gd`、`game/episode.gd`。書き方は `docs/story.md`）。
   会話の 1 行は `game/episode/talk_line.gd`、対戦の途中の台詞は `game/episode/talk_cue.gd`（欄を名前で読む。`docs/story.md` の「会話の 1 行（コードの形）」）。
2. **流れを組む** 話は場面の列（`Episode.scenes`、`game/episode/story_scene.gd`。`[before]`・`[after]` の話は 出撃準備 → 会話（前）→ 対戦 → 会話（後）、場面の節 `[talk 名前]`・`[sortie]`・`[battle]` の話は書いた順。`game/episode/episode_scenes.gd`）で持つ。
   話の一覧で選ぶと、`Story.run_now` → `run_of` がその列を順に流れ（`game/run.gd`）へ並べ、`app.gd` が順に場面を出す（`docs/story.md` の「場面の列」）。
3. **出撃準備** `game/sortie_screen.gd`: 部隊を選ぶ（部隊編成への寄り道あり）。戦いの定義は `game/story_battle.gd`（`docs/scenario.md`）。
4. **会話** `game/talk_screen.gd`（前と後で同じ画面）。流れが渡すのは `game/talk_scene.gd`（`TalkScene`。名前の付いた欄と、場面の型 `shape`。
   型は話のファイルの節で決まる `StoryScene.talk_shape()`。型を読む所は `tests/game/test_talk_shapes.gd` が見張る）。
5. **対戦** 上の「対戦の 1 手」と同じ。勝つと `StoryBattle.record_win` → `Story.clear` が記録する（対戦の無い話は、最後の会話を読み終えたとき）。
6. **記録** `game/story_parts/story_record.gd`（`Story` が継ぐ）の記録は、流れの場面を抜けたときにまとめてスロットへ書く（`docs/save-slots.md`）。あとの会話から次の話へ進める。

## 何かを足すとき

足す手順は、機能の文書の「足すとき」の節にある。どの手順も、**触るファイル**・**足し忘れても検査が落ちない所**・**確かめ方**の順に書いてある。

| 足すもの | 手順 |
| --- | --- |
| 軍 | `docs/unit-roster.md` の「軍を足すとき」 |
| 兵（いまの軍に） | `docs/unit-roster.md` の「兵を足すとき」 |
| 魔物 | `docs/monsters.md` の「魔物を足すとき」 |
| 軍略 | `docs/troop-traits.md` の「軍略を足すとき」 |
| 状態・ダメージの段 | `docs/unit-statuses.md` の「状態を足すとき」（段の順は `docs/combat.md`） |
| 持ち物 | `docs/player-loadout.md` の「持ち物を足すとき」 |
| スキル | `docs/active-skills.md` の「スキルを足すとき」 |
| 必殺技 | `docs/tactical-ult.md` の「必殺技を足すとき」 |
| 出来事 | 読む側の見張りと一緒に、手順が入る（`docs/code-health.md` の「直す順のおすすめ」の 2）。それまでは、上の「対戦の 1 手」の 4 と 5 の読む側を全部見る（再生 `docs/battle-view.md` の「ルールとのつなぎ方」、ログ `docs/battle-log.md`） |
| 話・物語 | `docs/story.md` の「話を 1 つ足す」「物語を 1 つ足す」 |
| 話の場面の型（カットシーンのようなもの） | `docs/story.md` の「場面の型を 1 つ足すとき」 |
| 盤のカットシーンの台本の行 | `docs/story.md` の「台本の行を 1 つ足すとき」 |
| 会話の行の種類（台詞・地の文のようなもの） | `docs/story.md` の「会話の行の種類を 1 つ足すとき」 |
| 話の分かれ（次の話が替わる） | まだ入っていない。前提の 5 か所は `docs/story.md` の「話の一本道」 |
| マップ | `docs/hand-map.md` の「マップを足すとき」 |
| 画面の文 | `docs/text.md` の「文を足すとき」（言葉は `docs/wording.md`、枠は `docs/ui-theme.md` の「枠の大きさ」） |
| 対戦モードの場面・画面 | `docs/scene-flow.md`、`docs/battle-source.md` の「モードを足すとき」 |
| 兵の見た目の組 | `docs/look-set-intake.md` |
| 素材（絵・音・フォント） | `add-asset` のスキル |

**どれを足しても、最後は `tools/check.sh <godot>`。** ルールや数値に触ったら、釣り合いを `measure-balance` で測る
（CPU の読みは検査が守っていない所が多く、実測でしか分からない）。

## いまの前提

- 軍は 2 つ（`UnitKind.Army` の MILITARY と FANTASY）。それぞれ役割ごとに 1 種で 4 種、軍略 3 つ、必殺技 1 つ。
- 軍で決まるものは、軍の表（ルールは `rules/armies.gd`、見た目は `game/army_look.gd`）から読む。軍を足す手順は `docs/unit-roster.md` の「軍を足すとき」。
  まだ 2 軍のままの所も、そこに書いてある。
- 同じ軍に 5 種目の兵を足すのは、この前提の外（`docs/unit-roster.md` の「兵を足すとき」）。
- 話は物語の中で一本道（次の話が 1 つに決まっている）。前提の 5 か所と、分かれる話を入れるときに要ることは `docs/story.md` の「話の一本道」。
