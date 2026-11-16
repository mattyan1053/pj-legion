extends Control
## 対戦の途中の会話の札（docs/story.md の「対戦の途中の会話」）。上の帯のすぐ下の真ん中に、細く横長の 1 本の帯
## （話し手の名前の札（陣営の色）と文）で、短い台詞を数秒出して消す。対戦は止めない（クリックを受けない。盤の操作の邪魔をしない）。
##
## 盤を隠しにくくするため、地は半透明にし、マウスが乗っている間と、駒のそばのメニュー・予測のパネルが重なっている間は薄くする
## （obstacles）。左の勝ち方の札、右の視点の案内・ミニマップとは重ならない幅にしてある。
##
## 台詞が重なったら、順に出す（前の台詞が消えてから次）。出す長さは実際の時間で測る（CPU の番の早送りや、
## 自動の対戦の速さ（Engine.time_scale）で縮めない。メニューを開いて止めている間は進めない）。

const BattleCues := preload("res://game/battle_cues.gd")
const TextWrap := preload("res://game/text_wrap.gd")

## 1 つの台詞を出しておく時間（秒）: 基本 + 1 文字あたり。
const SHOW_BASE := 2.2
const SHOW_PER_CHAR := 0.07
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

const TEAM_COLORS: Array[Color] = [Color("3a7bd5"), Color("d64545"), Color("6b7280")]
const COLOR_BOX := Color(0.06, 0.08, 0.11, 0.72)
const COLOR_BORDER := Color(1.0, 1.0, 1.0, 0.14)
const COLOR_TEXT := Color(0.95, 0.96, 0.98)

## 札を薄くする四角（画面の座標）を返す Callable（無ければ、マウスだけを見る）。HUD が入れる（駒のそばのメニュー、予測のパネル）。
var obstacles := Callable()

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


## 札の部品は、木に入れる前に作っておく（テストから木に入れずに使える）。
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2((1280.0 - WIDTH) / 2.0, TOP)
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = COLOR_BOX
	box_style.border_color = COLOR_BORDER
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(5)
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
	_plate_style = StyleBoxFlat.new()
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
	_plate.add_child(_name)
	_text = _label(17, COLOR_TEXT)
	row.add_child(_text)
	visible = false


func _ready() -> void:
	_center()
	get_viewport().size_changed.connect(_center)


func _center() -> void:
	position.x = roundf((get_viewport_rect().size.x - WIDTH) / 2.0)


## 札が画面に占める四角（出していなければ大きさ 0）。検査用。
func card_rect() -> Rect2:
	return Rect2(global_position, _box.size) if visible else Rect2()


## 札を薄くしているか（マウスが乗っているか、メニューか予測のパネルが重なっているか）。
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


## 台詞を出す順に積む。
func say(lines: Array[BattleCues.Line]) -> void:
	_queue.append_array(lines)
	if _current == null:
		_next()


## 出している台詞と、積んである台詞を消す（新しい対戦を始めるとき）。
func clear() -> void:
	_queue.clear()
	_current = null
	visible = false


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
	_elapsed += real
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
		return
	_name.text = _current.name
	_plate_style.bg_color = TEAM_COLORS[clampi(_current.side, 0, TEAM_COLORS.size() - 1)].darkened(0.15)
	# 折り返しは先に決める（自動の折り返しのラベルは、幅が決まる前の高さを覚えて、帯が縦に伸びる）。
	# 文の幅は、帯の幅から、枠の余白と名前の札と間のぶんを引いたもの。
	var box_style := _box.get_theme_stylebox("panel")
	var width := WIDTH - box_style.get_minimum_size().x - _plate.get_combined_minimum_size().x - ROW_GAP
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
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
