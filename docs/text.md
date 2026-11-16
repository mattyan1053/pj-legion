# 画面の文の表

コード: `game/text.gd`（表を引く）、`game/names.gd`（ゲームの中のものの名前と説明）、`game/text/*.csv`（表）。
テスト: `tests/game/test_text.gd`（鍵の抜け、使われていない鍵、直書きの見張り）、`tests/game/test_names.gd`。

画面に出す文を、コードに直書きせず、**鍵 → 文の表**に置く（Issue #49 の、人間の「セリフとかがコードに埋め込まれているように見える」から）。
日本語 1 つだけだが、文を 1 か所で読んで直せるようにするため。言葉の決まりは `docs/wording.md`。

## 表

- Godot の翻訳の仕組み（CSV から取り込む `Translation`）に乗せる。`game/text/` に、まとまりごとの CSV を置く。
  1 行目は `keys,ja`、そのあと 1 行に「鍵,文」。文の中に `,` や `"` があれば、文を `"` で囲む（`"` は `""`）。
- 取り込みで `<名前>.ja.translation` ができる（コミットしない。`.gitignore`）。`game/text.gd` が、最初に文を引くときに、
  `game/text/` の `*.translation` をすべて読み込む（CSV を足すだけでよい）。`project.godot` の `locale/translations` には並べない
  （まっさらな取り出しの最初の取り込みで、まだ無いファイルを開こうとしてエラーになるため）。言語は `locale/fallback` の `ja`（どの言語の環境でも、この表を使う）。
- 1 つの鍵は、1 つのファイルにだけ置く（テストが確かめる）。

| ファイル | 中身 |
| --- | --- |
| `common.csv` | どの画面でも使う形（括弧、「・」「、」のつなぎ、マスの座標） |
| `names.csv` | ゲームの中のものの名前と説明（陣営、軍、役割、能力、特性、盤の上の効果、駒、進化先、持ち物、スキル、必殺技、状態、聖遺物、ステージ） |
| `battle.csv` | 対戦の画面（上の帯 `battle.hud`、下の帯の説明 `battle.hint`、駒のそばのメニュー `battle.menu`、マスの説明 `battle.cell`、予測 `battle.forecast`、勝ち方 `battle.goal`、ログ `battle.log`、盤の上の文字 `battle.pop`、知らせ `battle.banner`）、決着の画面 `result`、戦績 `stats` |
| `menus.csv` | タイトル `title`、システムメニュー `menu`、設定 `settings`、ステージ選択 `stage`、対戦モードの盤の説明 `field`、対戦の設定 `setup` |
| `deck.csv` | 部隊の編成 `deck`（一覧、組む画面、出せない理由 `deck.problem`、読めなかった部隊 `deck.load`） |
| `story.csv` | 物語を選ぶ・話の一覧 `story`、出撃の準備 `sortie`、会話の場面 `talk`、解放の知らせ `story.news` |

## 鍵の名付け

- **画面の文は `画面.部品.意味`**（英小文字と `_`、`.` で区切る）。例: `title.button.story`、`deck.list.empty`、`battle.log.damage`。
  同じ画面の文は、同じ頭にそろえる（表の中で並ぶ）。
- **ゲームの中のものは `種類.列挙の名前の小文字`**（`unit.shield_trooper`、`skill.fireball`）。説明は後ろに `.summary`、短い名前は `.short`。
  `game/names.gd` が列挙から鍵を作る（コードに鍵の文字は書かない）。列挙の値を足したら、表に行を足す（`test_names.gd` が落ちる）。
- ルール（`rules/`）は**文を持たない**。持つのは列挙と、説明に差し込む値（スキルの `summary_args`、聖遺物の `amount` など）だけ。

## 差し込み

- 数や名前を差し込む文は、**名前つきの差し込み** `{名前}` で書く（`{range} マス以内を中心に、十字 5 マスの敵へ {damage} ダメージ`）。
  コードは `Text.t(鍵, {"range": 3, "damage": 8})`。語順は表の側で決める（「A が B に N ダメージ」を、文 1 つで書く）。
- 文をつなげて組み立てない。言い回しが変わるたびに、コードを直すことになる。文の形が場合で変わる（「倒した」「倒れた」、
  「…すれば勝ち。」の「れば」）ときは、形ごとに鍵を分ける（`battle.log.damage.attack.defeated` / `battle.log.damage.effect.defeated`、
  `battle.goal.win.<勝ち方>` / `battle.goal.win.<勝ち方>.last`）。
- 「（…）」「・」「、」でつなぐ所は `Text.paren`・`Text.notes`・`Text.join_dot`・`Text.join_comma`（形は `common.csv`）。
- 列挙から鍵を作る画面の文（勝ち方の形、終わり方の名前）は、`test_text.gd` の `SCREEN_FAMILIES` に頭と列挙を書く（表の鍵が使われているかを、そこで調べる）。

## 見張り（`test_text.gd`）

- コードが文字で書いた鍵（`Text.t("…")`）が、どれも表にある。
- 表の鍵が、どれもコードから引かれる（文字の鍵か、`names.gd` が列挙から作る鍵）。
- **表に無い直書きの日本語**（文字の値に、かな・漢字・全角の記号）が、`game/` と `rules/` のコードに増えていない。
  コメント、開発用の出力（`push_error`、`push_warning`、`printerr`、`print`、`assert`）、画面に出さない文だけのファイル（自動の対戦の知らせ、話のファイルの書き間違いの文）は数えない。
  表へ移しきれないファイルがあれば、`PENDING` に、いま残っている数を書く（増えたら落ちる。減ったら数を直す）。いまは空。
- 定数の表に置きたい文（設定の項目の名前、盤の説明など）は、文ではなく鍵を置き、出すときに `Text.t` で引く（定数の中では `Text.t` を呼べない）。
