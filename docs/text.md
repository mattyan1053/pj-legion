# 画面の文の表

コード: `game/text.gd`（表を引く）、`game/names.gd`（ゲームの中のものの名前と説明）、`game/text/*.csv`（表）。
テスト: `tests/game/test_text.gd`（鍵の抜け、使われていない鍵、直書きの見張り）、`tests/game/test_names.gd`。

画面に出す文を、コードに直書きせず、**鍵 → 文の表**に置く（Issue #49 の、人間の「セリフとかがコードに埋め込まれているように見える」から）。
日本語 1 つだけだが、文を 1 か所で読んで直せるようにするため。言葉の決まりは `docs/wording.md`。

## 表

- `game/text/` に、まとまりごとの CSV を置く。1 行目は `keys,ja`、そのあと 1 行に「鍵,文」。文の中に `,` や `"` があれば、文を `"` で囲む（`"` は `""`）。
  文の中の `\n` は改行になる。
- `game/text.gd` が、最初に文を引くときに、`game/text/` の `*.csv` をすべて自分で読む（CSV を足すだけでよい）。
  Godot の翻訳の取り込み（CSV から `*.translation` を作るもの）には乗せない。取り込みが CSV を並べて取り込むところで、
  Godot ごと落ちることがあったため（CI の `check` が、回し直すと通る形で落ちていた）。CSV の `.import` は
  `importer="keep"`（取り込まず、書き出した pck にそのまま入れる）。CSV を足したら、`.import` も同じ中身で置く。
- 1 つの鍵は、1 つのファイルにだけ置く（テストが確かめる）。

| ファイル | 中身 |
| --- | --- |
| `common.csv` | どの画面でも使う形（括弧、「・」「、」のつなぎ、マスの座標、キーの印の名前 `common.key`） |
| `names.csv` | ゲームの中のものの名前と説明（陣営、軍、役割、能力、特性、盤の上の効果、駒、進化先、持ち物、スキル、必殺技、状態、聖遺物、マップ） |
| `battle.csv` | 対戦の画面（上の帯 `battle.hud`、下の帯の案内 `battle.guide`、駒のそばのメニュー `battle.menu`、マスの説明 `battle.cell`、予測 `battle.forecast`、勝ち方 `battle.goal`、ログ `battle.log`、盤の上の文字 `battle.pop`、知らせ `battle.banner`）、決着の画面 `result`、戦績 `stats` |
| `menus.csv` | タイトル `title`、システムメニュー `menu`、オプション `settings`、マップ選択 `stage`、対戦モードの盤の説明 `field`、対戦設定 `setup`、初期位置の駒の欄 `deploy` |
| `deck.csv` | 部隊編成 `deck`（一覧、組む画面、出せない理由 `deck.problem`、読めなかった部隊 `deck.load`） |
| `story.csv` | セーブデータ選択 `slots`、物語を選ぶ・話の一覧 `story`、出撃準備 `sortie`、会話の場面 `talk`、解放の知らせ `story.news` |

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
  コメント、開発用の出力（`push_error`、`push_warning`、`printerr`、`print`、`assert`）、画面に出さない文だけのファイル（`NOT_SHOWN`。自動の対戦の知らせ、物語・話・マップのファイルの書き間違いの文、折り返しの決まり）は数えない。
  表へ移しきれないファイルがあれば、`PENDING` に、いま残っている数を書く（増えたら落ちる。減ったら数を直す）。いまは空。
- 定数の表に置きたい文（設定の項目の名前、盤の説明など）は、文ではなく鍵を置き、出すときに `Text.t` で引く（定数の中では `Text.t` を呼べない）。
