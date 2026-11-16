extends RefCounted
## UI の色。役割で決めた少数の色に名前を付けて、ここ 1 か所に置く（使い方は docs/ui-theme.md）。
## 画面の側は、色を直に書かずにここを引く。テーマ（ui_theme.gd）も、ここの色だけで組む。
##
## 方向: 夜の藍の地に、古い真鍮の縁と、生成りの文字。盤（明るい低ポリ）の上に重ねても盤の色とぶつからないよう、
## UI の地は彩度を落とした暗い藍にし、色を持つのは「意味のある所」（強調、危険、陣営、勝ち方）だけにする。

# ---- 地（暗いほうから） ----

## 沈んだ所（入力欄、スライダーや棒の溝、送りの棒の溝）。
const INK := Color("0d1119")
## 板の地。
const PANEL := Color("161b27")
## 浮いた所（ボタン、カード）。
const RAISED := Color("252d3f")
## 浮いた所に、マウスが乗った。
const RAISED_HOVER := Color("34405a")
## 板の上の、行の区切りや薄い塗り（マウスが乗った行など）。
const WASH := Color(1.0, 1.0, 1.0, 0.07)
## 画面を覆って後ろを沈める幕（ダイアログの後ろ）。
const SHADE := Color(0.02, 0.03, 0.06, 0.6)

## 盤の上に重ねる板の濃さ（半透明）と、ダイアログの板の濃さ（ほぼ不透明）。
const ALPHA_OVERLAY := 0.88
const ALPHA_SOLID := 0.97
## 盤の上に重ねる板の地（半透明）と、ダイアログの板の地（ほぼ不透明）。
const OVERLAY := Color(PANEL, ALPHA_OVERLAY)
const SOLID := Color(PANEL, ALPHA_SOLID)

# ---- 枠 ----

## ふつうの枠（くすんだ真鍮）。
const BORDER := Color("6a5d3f")
## 目立たせる枠（マウスが乗った、選ばれている）。
const BORDER_BRIGHT := Color("d2ad62")
## 影。
const SHADOW := Color(0.0, 0.0, 0.0, 0.4)

# ---- 文字 ----

## 本文（生成り）。
const TEXT := Color("f2ede0")
## 補足（説明、案内、見出しの下の小さな文）。
const TEXT_DIM := Color("bcb9ae")
## 押せない・まだ開いていない。
const TEXT_OFF := Color("7e808a")
## 金の地の上の文字（いちばん大事なボタン）。
const TEXT_ON_GOLD := Color("241a06")
## 文字の縁取り。
const OUTLINE := Color("05070b")

# ---- 意味のある色 ----

## 強調（見出し、選んでいるもの、予測、クリア済み）。金。
const ACCENT := Color("ffd76a")
## いちばん大事なボタンの地（真鍮）。
const GOLD := Color("c9a24e")
const GOLD_HOVER := Color("e0ba64")
const GOLD_PRESSED := Color("a27f34")
## 選ばれている（押し込まれたままのボタン）の地。
const CHOSEN := Color("5f4d22")
## 良い知らせ（出せる、回復）。
const GOOD := Color("7fdc8a")
## 注意（確かめてほしいこと）。
const WARN := Color("ffb86b")
## 危険・だめ（出せない、消す、倒される）。
const DANGER := Color("ff8a6b")
## 危険なボタンの地。
const DANGER_FILL := Color("6b2a24")
## 進める（ターン終了）の地。未行動の駒が残っていないときは、明るいほう。
const GO := Color("2f6b3a")
const GO_READY := Color("3fa24f")
## 知らせ・新しいもの（状態、まだ読んでいない話）。
const INFO := Color("8fe3ff")

# ---- 陣営（盤の駒の色と同じ） ----

const TEAM_BLUE := Color("3a7bd5")
const TEAM_RED := Color("d64545")
const TEAM_NEUTRAL := Color("e0b83a")

# ---- 勝ち方の札 ----

const GOAL := Color(0.25, 0.2, 0.08, 0.9)
const GOAL_BORDER := Color("8a7230")
const GOAL_URGENT := Color(0.62, 0.2, 0.1, 0.95)

# ---- HP の棒（多い・半分以下・わずか） ----

const HP_HIGH := Color("5fd35f")
const HP_MID := Color("e8c23a")
const HP_LOW := Color("e8503a")


## HP の残りの割合（0〜1）に合う棒の色。
static func hp(ratio: float) -> Color:
	return HP_HIGH if ratio > 0.5 else (HP_MID if ratio > 0.25 else HP_LOW)


## 陣営の色の文字（暗い地の上で読めるよう、明るくしたもの）。
static func team_text(color: Color) -> Color:
	return color.lightened(0.4)
