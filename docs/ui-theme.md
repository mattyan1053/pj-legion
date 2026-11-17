# UI のテーマ

UI の見た目（ボタン、板、帯、札、文字、色）は、1 つのテーマにまとめてある。画面の側は、色や枠を直に書かず、ここを引く。

- 色: `game/ui_palette.gd`（役割ごとの色に名前を付けて、1 か所に置く）
- テーマ: `game/ui_theme.gd`（Godot の `Theme`。色は上だけを引いて、スクリプトで組む。絵は使わない）
- 文字: `assets/fonts/zen/`（出どころとライセンスは、その中の `README.md`）
- 小さな動き: `game/ui_feel.gd`（下の「小さな動き」）

テスト: `tests/game/test_ui_theme.gd`（文字と地の濃淡の差）、`tests/game/test_ui_feel.gd`。

アプリの入口（`app.gd`）が、起動してすぐ `UiTheme.install()` で Godot の既定のテーマに重ねる。
だから、ふつうに作った `Button`、`PanelContainer`、`Label`、`HSlider`、ツールチップなどは、何もしなくてもこの見た目になる。

## 方向

夜の藍の地に、くすんだ真鍮の縁と、生成りの文字。

- 盤（明るい低ポリ）の上に重ねるので、UI の地は彩度を落とした暗い藍にして、盤の色（範囲の青・黄・赤、足元の印、HP の棒）とぶつけない。
- 色を持つのは「意味のある所」だけ（強調の金、危険の朱、陣営の青と赤、勝ち方の金）。飾りのための色は足さない。
- 文字は、本文が角ゴシック（小さくても読める）、題字と画面の見出しだけ明朝（ファンタジー寄りの音と絵柄に合わせる）。

## 色の役割

`Palette.<名前>` で引く。値はコードにある。

| 役割 | 名前 | 使う所 |
| --- | --- | --- |
| 地 | `INK` | 沈んだ所（入力欄、スライダーや棒の溝） |
| 地 | `PANEL`（`OVERLAY` / `SOLID`） | 板。盤の上に重ねるものは半透明の `OVERLAY`、ダイアログはほぼ不透明の `SOLID` |
| 地 | `RAISED` / `RAISED_HOVER` | 浮いた所（ボタン、カード）と、マウスが乗ったとき |
| 地 | `WASH` | 板の上の薄い塗り（マウスが乗った行、区切り） |
| 地 | `SHADE` | ダイアログの後ろを沈める幕 |
| 地 | `SHADOW` | ダイアログの板の影 |
| 枠 | `BORDER` / `BORDER_BRIGHT` | ふつうの枠と、目立たせる枠（乗った、選ばれている） |
| 文字 | `TEXT` / `TEXT_DIM` / `TEXT_OFF` | 本文、補足、押せない |
| 文字 | `TEXT_ON_GOLD` | 金の地の上（いちばん大事なボタン） |
| 文字 | `OUTLINE` | 文字の縁取り |
| 強調 | `ACCENT` | 見出し、選んでいるもの、予測、クリア済み |
| 強調 | `GOLD` / `GOLD_HOVER` / `GOLD_PRESSED` | いちばん大事なボタンの地、棒の中身 |
| 強調 | `CHOSEN` | 選ばれている（押し込まれたままの）ボタンの地 |
| 知らせ | `GOOD` / `WARN` / `DANGER` / `INFO` | 良い、注意、危険・だめ、新しい・状態 |
| 危険 | `DANGER_FILL` | 危険なボタンの地 |
| 進める | `GO` / `GO_READY` | ターン終了のボタンの地（未行動の駒が残っている / いない） |
| 陣営 | `TEAM_BLUE` / `TEAM_RED` / `TEAM_NEUTRAL` | 盤の駒と同じ色。文字にするときは `team_text()` で明るくする |
| 勝ち方 | `GOAL` / `GOAL_BORDER` / `GOAL_URGENT` | 勝ち方の札（ふつうと、最後のターン） |
| HP | `HP_HIGH` / `HP_MID` / `HP_LOW`（`hp(割合)`） | HP の棒 |

**盤の上の色（移動範囲、脅威範囲、足元の印など。`battle_screen.gd`）は、ここに入れない。** あれは盤の情報で、UI の色ではない。

文字と地の濃淡の差（コントラスト比）は、`tests/game/test_ui_theme.gd` が下限を確かめる（本文 4.5 以上、押せない文字 3 以上。
半透明の板は、後ろが真っ白でも本文が読める）。色を足したり変えたりしたら、そこに通す。

## 新しい画面を作るとき

何もしなければ「ふつう」になる。違う種類にするときは、`theme_type_variation` に `UiTheme` の定数を入れる。

    const UiTheme := preload("res://game/ui_theme.gd")
    button.theme_type_variation = UiTheme.BUTTON_PRIMARY

| 部品 | 種類 | いつ使う |
| --- | --- | --- |
| `Button` | （ふつう） | たいていのボタン。`toggle_mode` で押し込まれたままのものは、金の縁と濃い金の地で「選ばれている」になる |
| `Button` | `BUTTON_PRIMARY` | その画面で次に押す、いちばん大事なボタン（「対戦開始」「出撃」「次へ」）。**1 画面に 1 つ** |
| `Button` | `BUTTON_DANGER` | 取り返しのつかないこと（「削除」「破棄」、対戦を終える） |
| `Button` | `BUTTON_ROW` | 板の上に並ぶ行（一覧の行、メニューの項目）。枠が無く、乗ると薄く塗る |
| `Button` | `BUTTON_CARD` | カード（マップ、物語、話）。乗ると金の縁 |
| `PanelContainer` | （ふつう） | 盤の上に重ねる板（情報の枠、案内）。半透明 |
| `PanelContainer` | `PANEL_SOLID` | ダイアログ、メニュー、オプション。ほぼ不透明で、太い縁と影 |
| `PanelContainer` | `PANEL_BAND_TOP` / `PANEL_BAND_BOTTOM` | 画面の上の帯と下の帯 |
| `PanelContainer` | `PANEL_CARD` | 板の中の区切り |
| `PanelContainer` | `PANEL_TAG` | 小さな札（名前の札、印） |
| `PanelContainer` | `PANEL_NONE` | 縁も地も無い入れ物 |
| `Label` | （ふつう） | 本文 |
| `Label` | `LABEL_TITLE` | 題字（明朝、金） |
| `Label` | `LABEL_HEADING` | 画面の見出し（明朝） |
| `Label` | `LABEL_SECTION` | 板の中の小見出し（太字、金） |
| `Label` | `LABEL_DIM` | 補足の文 |

- 景色の四隅を沈める幕は `UiTheme.vignette()`、ダイアログの板は `UiTheme.solid_box(余白)`、盤の上の板は `UiTheme.overlay_box(余白)`。
- **色だけ違う板**が要るとき（陣営の色の札など）は、`UiTheme.box(地, 縁, …)` で形を作り、色は `Palette` から渡す。
  `StyleBoxFlat.new()` から組まない（角の丸さや縁の太さが、画面ごとにずれるため）。
- **状態で色が変わる文字**（出せる / 出せない、など）は、`add_theme_color_override("font_color", Palette.GOOD)` のように `Palette` を渡す。
- 盤の上に直に置く文字（板の無いところ）は、縁取り（`outline_size`）を付ける。縁取りの色はテーマが持っている。
- スイッチ（`CheckButton`）、スライダー、送りの棒、進み具合の棒、入力欄、選択肢（`OptionButton`）、ツールチップは、そのまま使えばテーマの見た目になる。

## テーマを直すとき

- 種類を足すときは、`ui_theme.gd` に定数と形を足し、上の表に 1 行足す。
- 見え方は、スクリーンショット（`docs/screenshots.md`）を 1280×720 と 960×540（文字がいちばん小さくなる）で撮り、
  草原・石畳・暗い結晶の森の上で、半透明の板の文字が読めることを確かめる。
- コンテナのソフトウェア描画では、半透明の重なり・細い縁・影のぼかしが実機と少し違って見える。最終の見え方は exe で確かめる。

## 小さな動き

- ボタンにマウスが乗ると一瞬だけ明るく光って落ち着き、押すと一瞬だけ沈む（`game/ui_feel.gd`。アプリの入口が 1 つ持ち、木に入るボタンの全部に付く）。
  画面の側は何もしなくてよい。入力は止めないので、待ち時間は増えない。
- 大きさは変えない（入れ物が並べ直すたびに戻るのと、文字が拡大でぼやけるため）。
- 画面の側が `self_modulate` で色を付けているボタン（必殺技の READY の明滅など）には重ねない。

## 景色の上に置く画面

- タイトル、マップ選択、物語選択、話の一覧は、景色の上に `UiTheme.vignette()`（四隅を沈める幕）を 1 枚敷いてから、板やカードを置く。
- 景色の上に直に置く見出し（`LABEL_HEADING`）は、縁取りを太くする（`outline_size` 10）。
- 対戦の上の帯と下の帯は `UiTheme.band_box(上か)` の形（角を丸めず、内側の辺にだけ縁）。
