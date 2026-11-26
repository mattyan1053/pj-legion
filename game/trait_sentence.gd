extends Control
## 軍略の文 1 つ（docs/troop-traits.md）: 「このターン味方が攻撃した敵にダメージ +2」。効果（数のある所）だけ、太字で色を変える。
## 部隊編成の軍略の欄、編成確認、対戦中の軍略の窓が使う。
## 大きさは中身（軍略）に依らず同じ（幅 × 行の数。docs/ui-theme.md の「枠の大きさ」）。文は語の途中で切らずに折り返す（text_wrap.gd）。

const Names := preload("res://game/names.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const TextWrap := preload("res://game/text_wrap.gd")

## 見せる軍略（Traits.Id の値。Traits.NONE なら空）。
var trait_id := Traits.NONE:
	set(value):
		trait_id = value
		_layout()
		queue_redraw()

var _width: float
var _font_size: int
var _max_lines: int
var _color: Color
var _accent: Color
## 折り返した行。行ごとに [文字列, 効果の所か] の並び。
var _lines: Array[Array] = []
var _plain := ""


## 幅 width・字の大きさ font_size・行の数 max_lines の欄。color は文の色、accent は効果の色。
func _init(width: float, font_size: int, max_lines: int, color := Palette.TEXT_DIM, accent := Palette.ACCENT) -> void:
	_width = width
	_font_size = font_size
	_max_lines = max_lines
	_color = color
	_accent = accent
	custom_minimum_size = Vector2(width, line_height() * max_lines)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 1 行の高さ（px）。
func line_height() -> float:
	return ceilf(UiTheme.FONT_BOLD.get_height(_font_size) + 2.0)


## 見せている文（色を付ける前の 1 文。検査用）。
func shown_text() -> String:
	return _plain


## 折り返した行の数。
func line_count() -> int:
	return _lines.size()


## 欄に収まらないか（行が多すぎる、行が幅を超える）。検査用。
func overflows() -> bool:
	if _lines.size() > _max_lines:
		return true
	for line in _lines:
		if _line_width(line) > _width + 0.5:
			return true
	return false


## 文字 1 つの幅（折り返しは太字で測る。効果の所が太字なので、広いほうに合わせる）。
func _measure(character: String) -> float:
	return UiTheme.FONT_BOLD.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x


func _layout() -> void:
	_lines.clear()
	_plain = Names.troop_trait_text(trait_id)
	if _plain == "":
		return
	var effect := Names.troop_trait_effect(trait_id)
	var from := _plain.find(effect)
	var to := from + effect.length() if from >= 0 else -1
	var folded := TextWrap.fold(_plain, _width, _measure)
	# 折り返した文の 1 字ずつを、元の文の位置に合わせる（折り返しで落ちた行の末の空白は飛ばす）。
	var at := 0
	for row in folded.split("\n"):
		var runs: Array = []
		for character in row:
			while at < _plain.length() and _plain[at] != character:
				at += 1
			var accented := at >= from and at < to
			if runs.is_empty() or runs[runs.size() - 1][1] != accented:
				runs.append(["", accented])
			runs[runs.size() - 1][0] += character
			at += 1
		_lines.append(runs)


func _line_width(line: Array) -> float:
	var total := 0.0
	for run: Array in line:
		total += _font_of(run[1]).get_string_size(run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	return total


func _font_of(accented: bool) -> Font:
	return UiTheme.FONT_BOLD if accented else UiTheme.FONT_BODY


func _draw() -> void:
	var height := line_height()
	var shown := mini(_lines.size(), _max_lines)
	var top := (size.y - height * shown) / 2.0
	for i in shown:
		var x := 0.0
		var baseline := top + height * i + (height - UiTheme.FONT_BOLD.get_height(_font_size)) / 2.0 + UiTheme.FONT_BOLD.get_ascent(_font_size)
		for run: Array in _lines[i]:
			var font := _font_of(run[1])
			draw_string(font, Vector2(x, baseline), run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _accent if run[1] else _color)
			x += font.get_string_size(run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
