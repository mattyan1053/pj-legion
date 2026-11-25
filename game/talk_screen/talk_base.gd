extends Node
## 会話の場面（game/talk_screen.gd）の土台: 読み込み、調整値、状態の変数と、どこからも使う小さな道具（行の読み方、幕、文字）。
## 継ぐ順: talk_base.gd → talk_figures.gd（話し手の姿）→ talk_choice.gd（終わり方と行き先の選択）→ game/talk_screen.gd（組み立て・入力・文の送り）。

const Text := preload("res://game/text.gd")
const KeyMarks := preload("res://game/key_marks.gd")
const Palette := preload("res://game/ui_palette.gd")
const AppContext := preload("res://game/app_context.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const ItemIcon := preload("res://game/item_icon.gd")
const Backdrop := preload("res://game/backdrop.gd")
const Run := preload("res://game/run.gd")
const TalkFigure := preload("res://game/talk_figure.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Steady := preload("res://game/steady.gd")
const TalkLog := preload("res://game/talk_log.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const UnitLooks := preload("res://game/unit_looks.gd")

signal finished(outcome: StringName)

## 文を出す速さ（1 秒あたりの文字数）。検査では待たない。
const CHARS_PER_SECOND := 45.0
const BOX_WIDTH := 980.0
const BOX_HEIGHT := 150.0
## 名前の札の幅（px）。いちばん長い話し手の名前が入る幅（tests/game/test_steady_frames.gd）。名前の長さで変えない。
const PLATE_WIDTH := 152.0
## あとの会話の「次の話へ」「話の一覧へ」のボタンの幅（px。縦に積んで、左右の話し手の間に収める）。
const CHOICE_WIDTH := 260.0
const BOX_BOTTOM := 40.0
## 背景の盤に重ねる幕の濃さ（Palette.SHADE の色）。
const BACKDROP_SHADE := 0.3
## 足元を沈める幕の、下の端の濃さ。
const FLOOR_SHADE := 0.7
## 画面の端から見出しまでの余白。
const MARGIN := Vector2(32.0, 24.0)
## 話し手の姿の枠の横幅の上限（文の枠の幅に対する割合。左右の姿が真ん中で重ならない）。
const FIGURE_MAX_WIDTH := 0.42
## 送りの印の明滅の周期（秒）。
const BLINK_PERIOD := 1.2
## 名前の札の色（0 = 人の軍、1 = 敵の軍は battle_screen.gd の TEAM_COLORS と同じ。2 = 知らせ）。
const TEAM_COLORS: Array[Color] = [Palette.TEAM_BLUE, Palette.TEAM_RED, Palette.TEXT_OFF]
## 知らせの行の side（story.gd の NOTICE_SIDE）。
const NOTICE_SIDE := 2
## 地の文の行の side（episode.gd の NARRATION_SIDE）。名前の札を出さず、文を真ん中に明朝で出す。話し手の姿は、両方とも暗い。
const NARRATION_SIDE := 3
## 知らせの行の、駒・持ち物の額の辺（px）。
const NOTICE_FRAME := 72.0
## 文の大きさと、文の枠の左右の余白（px）、知らせのアイコンと文の間（px）。文の幅は text_width で決まる。
const TEXT_FONT := 25
const BOX_MARGIN_X := 28.0
const NOTICE_GAP := 12

const COLOR_BOX := Color(Palette.PANEL, 0.92)
const COLOR_BORDER := Palette.BORDER
const COLOR_TEXT := Palette.TEXT
const COLOR_DIM := Palette.TEXT_DIM

var context: AppContext
## 渡された会話（{"title": 見出し, "lines": [{"side", "name", "text"}, …], "board": 背景の盤, "look": 盤の見た目,
## "figures": 話し手の姿（行の "who" の番号の並び）}。story.gd の talk_of）。行に "who" が無ければ、陣営（"side"）の番号。
var talk := {}
var _index := 0
var _shown := 0.0  # いまの文の、出した文字数
var _elapsed := 0.0
var _plate: PanelContainer
var _plate_style: StyleBoxFlat
var _box_style: StyleBoxFlat
var _name: Label
var _text: Label
var _raw_text := ""
var _face: UnitFrame
var _item_face: Control  # item_icon.gd
var _item_frame: PanelContainer
var _hint: KeyMarks
var _count: Label
var _skip: Button
var _log_button: Button
## 会話のログの窓（talk_log.gd）。
var _log: TalkLog
## 話し手の姿を立たせる所（見出しと、下の名前の札・文の枠の間）と、話し手の姿（会話に出てくる話し手ごとに 1 つ。
## 同じ所に立つ話し手のうち、いま立っている 1 人だけを見せる）。
var _stage: Control
var _figures: Array[TalkFigure] = []
## 下の名前の札・「飛ばす」・文の枠をまとめたもの（姿と重ねない）。
var _bottom: Control
## 会話を終えるときの行き先の選択（次の話があるときだけ。_end で出す）。
var _choice: Control
var _layer: CanvasLayer
var _backdrop: Backdrop
## 会話を終えた（行き先へ進んだ）。2 回進まない。
var _ended := false


## 行 line の話し手の番号（"who"。無ければ陣営の番号）。知らせの行は -1。
static func _who(line: Dictionary) -> int:
	var side := int(line.get("side", 0))
	return -1 if side >= NOTICE_SIDE else int(line.get("who", side))


## 行 line が地の文か（話し手のいない行）。
static func is_narration(line: Dictionary) -> bool:
	return int(line.get("side", 0)) == NARRATION_SIDE


## 行 line の文を折り返す幅（px）。知らせの行は、アイコンのぶん狭い。
static func text_width(line: Dictionary) -> float:
	var width := BOX_WIDTH - BOX_MARGIN_X * 2.0
	if line.has("kind") or line.has("item"):
		width -= NOTICE_FRAME + NOTICE_GAP
	return width


## 行 line の文を、text_width で折り返したもの（地の文は見出しの字）。
static func fold_line(line: Dictionary) -> String:
	var font := UiTheme.FONT_HEADING if is_narration(line) else UiTheme.FONT_BODY
	return TextWrap.fold(line.get("text", ""), text_width(line),
		func(character: String) -> float: return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_FONT).x)



## 足元を沈める幕（下の端が濃く、画面の半ばで消える）。入力は通す。
static func _floor_shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(Palette.INK, 0.0), Color(Palette.INK, 0.0), Color(Palette.INK, FLOOR_SHADE)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 64
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
