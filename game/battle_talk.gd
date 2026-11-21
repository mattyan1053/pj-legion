extends Control
## 対戦の途中の会話の札（docs/story.md の「対戦の途中の会話」）。上の帯のすぐ下の真ん中に、細く横長の 1 本の帯
## （話し手の名前の札（陣営の色）と文）で、短い台詞を出す。札そのものはクリックを受けない（送るのは対戦の画面。下の hold）。
##
## 盤を隠しにくくするため、地は半透明にし、マウスが乗っている間と、駒のそばのメニュー・予測のパネル・進化先の選択肢が重なっている間は薄くする
## （obstacles）。左の勝ち方の札、右の視点の案内・ミニマップとは重ならない幅にしてある。
##
## 台詞が重なったら、順に出す（前の台詞が消えてから次）。出す長さは実際の時間で測る（CPU の番の早送りや、
## 自動の対戦の速さ（Engine.time_scale）で縮めない。メニューを開いて止めている間は進めない）。
##
## hold（遊ぶとき）なら、台詞は自動で消さず、送られる（advance。対戦の画面が、クリック・Enter・Space で呼ぶ）まで出したままにする。
## その間、対戦の画面は盤の進行を止める（is_holding）。帯の右に送りの印（▼）を明滅させる。
## hold でない（検査とスクリーンショット）なら、数秒で消す。

const Palette := preload("res://game/ui_palette.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const UiTheme := preload("res://game/ui_theme.gd")

## 送りの印の明滅の周期（秒）。
const BLINK_PERIOD := 1.2
## 1 つの台詞を出しておく時間（秒。hold でないとき）: 基本 + 1 文字あたり。目で追い終えてから、もう一度読めるくらい。
const SHOW_BASE := 3.5
const SHOW_PER_CHAR := 0.1
## 出てくる・消えるときのフェード（秒）。
const FADE := 0.25
## 帯の幅と、上端（上の帯（battle_hud.gd の TOP_BAR_HEIGHT = 50）のすぐ下）。横は画面の真ん中。
## 幅は、1280 の画面で、左の勝ち方の札（いちばん長い文で 360 ほど）と右の視点の案内（左端が 900 ほど）の間に収まるもの。
const WIDTH := 500.0
const TOP := 54.0
## 薄くしたときの濃さと、濃さが変わる速さ（1 秒あたり）。
const DIMMED := 0.18
const DIM_SPEED := 6.0
## 名前の札と文の間（px）。
const ROW_GAP := 10
## 話し手のアイコン（unit_icons.gd の胸から上。話のファイルの figure の姿）の大きさ（px）。帯の高さを増やさない大きさ。
const FACE_SIZE := 32.0

const TEAM_COLORS: Array[Color] = [Palette.TEAM_BLUE, Palette.TEAM_RED, Palette.TEXT_OFF]
const COLOR_BOX := Color(Palette.PANEL, 0.72)
const COLOR_BORDER := Color(Palette.BORDER, 0.9)
const COLOR_TEXT := Palette.TEXT

## 札を薄くする四角（画面の座標）を返す Callable（無ければ、マウスだけを見る）。HUD が入れる（駒のそばのメニュー、予測のパネル）。
var obstacles := Callable()
## 真なら、次の台詞を出し始めずに待つ Callable（無ければ待たない）。対戦の画面が入れる: 画面の真ん中の「ターン N」の帯が出ている間は、
## 目がそちらへ行くので、台詞は帯が消えてから出す（同時に出すと、気付かないうちに消える）。出し始めた台詞は止めない。
var waiting := Callable()
## 送られるまで台詞を出したままにするか（上の説明）。
var hold := false

## 出す台詞が尽きた（送り終えたか、消した）。
signal drained

## まだ出していない台詞。
var _queue: Array[BattleCues.Line] = []
## いま出している台詞と、出してからの時間（実際の秒）。
var _current: BattleCues.Line
var _elapsed := 0.0
## いまの濃さ（薄くするとき DIMMED へ寄る）。
var _dim := 1.0
var _plate_style: StyleBoxFlat
var _name: Label
var _text: Label
var _box: PanelContainer
var _plate: PanelContainer
var _face: TextureRect
var _face_frame: PanelContainer
var _face_style: StyleBoxFlat
var _box_style: StyleBoxFlat
var _more: Label
var _blink := 0.0


## 札の部品は、木に入れる前に作っておく（テストから木に入れずに使える）。
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2((1280.0 - WIDTH) / 2.0, TOP)
	# 帯: 会話の画面の文の枠と同じく、上の縁を太くして話し手の陣営の色にする。薄い影で盤から浮かせる。
	var box_style := UiTheme.box(COLOR_BOX, COLOR_BORDER, 1, 5, 4.0, 3)
	box_style.border_width_top = 2
	_box_style = box_style
	box_style.content_margin_left = 4.0
	box_style.content_margin_right = 12.0
	box_style.content_margin_top = 4.0
	box_style.content_margin_bottom = 4.0
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", box_style)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.custom_minimum_size = Vector2(WIDTH, 0.0)
	add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	# 話し手のアイコン（名前の札の左。陣営の色の、その話し手の駒の姿）。沈んだ地に陣営の色の縁の、小さな額に入れる。
	_face_style = UiTheme.box(Color(Palette.INK, 0.85), COLOR_BORDER, 1, 5, 0.0)
	_face_frame = PanelContainer.new()
	_face_frame.add_theme_stylebox_override("panel", _face_style)
	_face_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_face_frame)
	_face = UnitIcons.rect(UnitKind.Id.KING, 0, false, FACE_SIZE)
	_face_frame.add_child(_face)
	_plate_style = StyleBoxFlat.new()
	_plate_style.set_border_width_all(1)
	_plate_style.set_corner_radius_all(4)
	_plate_style.content_margin_left = 10.0
	_plate_style.content_margin_right = 10.0
	_plate_style.content_margin_top = 1.0
	_plate_style.content_margin_bottom = 1.0
	_plate = PanelContainer.new()
	_plate.add_theme_stylebox_override("panel", _plate_style)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_plate)
	_name = _label(15, Color.WHITE)
	_name.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_plate.add_child(_name)
	_text = _label(17, COLOR_TEXT)
	row.add_child(_text)
	# 送りの印（hold のときだけ）。文の右の端、下に寄せる。
	_more = _label(14, Palette.TEXT)
	_more.text = "▼"
	_more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_more)
	visible = false


func _ready() -> void:
	_center()
	get_viewport().size_changed.connect(_center)


func _center() -> void:
	position.x = roundf((get_viewport_rect().size.x - WIDTH) / 2.0)


## 札が画面に占める四角（出していなければ大きさ 0）。検査用。
func card_rect() -> Rect2:
	return Rect2(global_position, _box.size) if visible else Rect2()


## 札を薄くしているか（マウスが乗っているか、メニュー・予測のパネル・進化先の選択肢が重なっているか）。
func is_dimmed() -> bool:
	if not visible:
		return false
	var rect := Rect2(global_position, _box.size)
	if is_inside_tree() and rect.has_point(get_global_mouse_position()):
		return true
	if obstacles.is_valid():
		for other: Rect2 in obstacles.call():
			if other.has_area() and rect.intersects(other):
				return true
	return false


## メニュー・予測のパネル・進化先の選択肢が札に重なっているか（マウスは見ない）。
func _blocked() -> bool:
	if not obstacles.is_valid():
		return false
	var rect := Rect2(global_position, _box.size)
	for other: Rect2 in obstacles.call():
		if other.has_area() and rect.intersects(other):
			return true
	return false


## いま出している話し手のアイコン（出していなければ null）。検査用。
func face() -> Texture2D:
	return _face.texture if visible and _face_frame.visible else null


## 台詞を出す順に積む。
func say(lines: Array[BattleCues.Line]) -> void:
	_queue.append_array(lines)
	if _current == null:
		_next()


## 出している台詞と、積んである台詞を消す（新しい対戦を始めるとき）。
func clear() -> void:
	_queue.clear()
	var had := _current != null
	_current = null
	visible = false
	if had:
		drained.emit()


## 送られるのを待っているか（hold で、台詞を出している。出し始める前の「ターン N」の帯を待つ間も含む）。
func is_holding() -> bool:
	return hold and _current != null


## いまの台詞を送る（次の台詞へ。無ければ消す）。出し始める前（帯を待つ間、フェードの途中）は送らない
## （気付く前に、押した勢いで消さない）。送ったかを返す。
func advance() -> bool:
	if _current == null or _elapsed < FADE:
		return false
	_next()
	return true


## いま出している台詞（無ければ null）。
func current() -> BattleCues.Line:
	return _current


## まだ出していない台詞の数。
func pending() -> int:
	return _queue.size()


func _process(delta: float) -> void:
	if _current == null:
		return
	# Engine.time_scale で縮めない（実際の秒）。0（メニューで止めている間）なら進めない。
	if Engine.time_scale <= 0.0:
		return
	var real := delta / Engine.time_scale
	if _elapsed <= 0.0 and waiting.is_valid() and waiting.call():
		modulate.a = 0.0
		return
	_elapsed += real
	if hold:
		# 送られるまで出したまま。薄くするのは、メニュー・予測のパネル・進化先の選択肢が重なっているときだけ（マウスでは薄くしない）。
		_blink += real
		_dim = move_toward(_dim, DIMMED if _blocked() else 1.0, DIM_SPEED * real)
		modulate.a = clampf(_elapsed / FADE, 0.0, 1.0) * _dim
		_more.modulate.a = 0.65 + 0.35 * cos(_blink * TAU / BLINK_PERIOD)
		return
	var shown := _duration(_current)
	_dim = move_toward(_dim, DIMMED if is_dimmed() else 1.0, DIM_SPEED * real)
	modulate.a = clampf(minf(_elapsed / FADE, (shown - _elapsed) / FADE), 0.0, 1.0) * _dim
	if _elapsed >= shown:
		_next()


func _next() -> void:
	_current = null if _queue.is_empty() else _queue.pop_front()
	_elapsed = 0.0
	visible = _current != null
	if _current == null:
		drained.emit()
		return
	_more.visible = hold
	_name.text = _current.name
	_face_frame.visible = not _current.figure.is_empty() and _current.side < 2
	if _face_frame.visible:
		_face.texture = UnitIcons.bust(_current.figure["kind"], _current.side, _current.figure.get("evolved", false), _current.figure.get("look", &""))
	var team := TEAM_COLORS[clampi(_current.side, 0, TEAM_COLORS.size() - 1)]
	_plate_style.bg_color = team.darkened(0.15)
	_plate_style.border_color = team.lightened(0.35)
	_face_style.border_color = team.lightened(0.2)
	_box_style.border_color = COLOR_BORDER.lerp(team.lightened(0.2), 0.85)
	# 折り返しは先に決める（自動の折り返しのラベルは、幅が決まる前の高さを覚えて、帯が縦に伸びる）。
	# 文の幅は、帯の幅から、枠の余白と名前の札と間のぶんを引いたもの。
	var box_style := _box.get_theme_stylebox("panel")
	var width := WIDTH - box_style.get_minimum_size().x - _plate.get_combined_minimum_size().x - ROW_GAP
	if _more.visible:
		width -= _more.get_combined_minimum_size().x + ROW_GAP
	if _face_frame.visible:
		width -= _face_frame.get_combined_minimum_size().x + ROW_GAP
	var font := _text.get_theme_font("font")
	var font_size := _text.get_theme_font_size("font_size")
	_text.text = TextWrap.fold(_current.text, width,
		func(character: String) -> float: return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_box.reset_size()  # 前の台詞より短ければ、帯も低くする
	_dim = 1.0
	modulate.a = 0.0


static func _duration(line: BattleCues.Line) -> float:
	return SHOW_BASE + SHOW_PER_CHAR * line.text.length()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
