extends "res://game/window_base.gd"
## 主人公の名前を付ける窓（docs/story.md の「主人公の名前」）。物語を初めて始めるときと、話の一覧の「名前を変える」で出す。
## 見出し、主人公の立ち位置（物語のファイルの [cast] の文）、名前の欄、長さの注、「決定」。
## 欄は、いまの名前を入れて始める。そのまま Enter・「決定」で進める。空にして決めると、既定の名前。
## 右クリック・Esc は、変えずに閉じる。どちらでも done を呼ぶ（決めた名前か、開いたときの名前）。
## 使えない文字（改行、波括弧、画面の字に無い文字）は、打った所で落とす。長さは、名前の札に入る幅まで（hero_name.gd）。
##
##   var window := HeroNameWindow.new()
##   window.setup(context.overlays)
##   layer.add_child(window)
##   window.ask("ハーデン", "ハーデン", "偵察隊の新任少尉", func(named: String) -> void: ...)

const Text := preload("res://game/text.gd")
const HeroName := preload("res://game/hero_name.gd")

## 板の大きさ（px。中身で変えない）と、名前の欄の幅。
const SIZE := Vector2(460.0, 290.0)
const FIELD_WIDTH := 300.0

var _role: Label
var _field: LineEdit
var _done: Callable
## 開いたときの名前と、既定の名前。
var _was := ""
var _default := ""
## 決めた名前（閉じるときに done へ渡す）。
var _named := ""


func setup(overlays: RefCounted) -> void:
	var panel := build_window(overlays, "hero.window", SIZE)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = Text.t("hero.window.title")
	UiTheme.style_window_title(title, 22)
	column.add_child(title)
	column.add_child(UiTheme.window_rule(Palette.BORDER_BRIGHT))
	_role = Label.new()
	_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role.add_theme_font_size_override("font_size", 16)
	_role.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_role.clip_text = true
	column.add_child(_role)
	_field = LineEdit.new()
	_field.custom_minimum_size = Vector2(FIELD_WIDTH, 48.0)
	_field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field.add_theme_font_size_override("font_size", 24)
	_field.max_length = HeroName.MAX_LETTERS
	_field.context_menu_enabled = false
	_field.text_changed.connect(_on_typed)
	_field.text_submitted.connect(func(_text: String) -> void: accept())
	column.add_child(_field)
	var note := Label.new()
	note.text = Text.t("hero.window.note", {"max": HeroName.MAX_CHARS})
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Palette.TEXT_DIM)
	column.add_child(note)
	var ok := Button.new()
	ok.text = Text.t("hero.window.ok")
	ok.theme_type_variation = UiTheme.BUTTON_PRIMARY
	ok.focus_mode = Control.FOCUS_NONE
	ok.add_theme_font_size_override("font_size", 18)
	ok.custom_minimum_size = Vector2(180.0, 48.0)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.set_meta(&"sound", &"ui_confirm")
	ok.pressed.connect(accept)
	column.add_child(ok)


## 名前を訊く。named はいまの名前、default_name は既定の名前（欄を空にして決めたときの名前）、role は立ち位置の文。
## 閉じるときに done(名前) を呼ぶ（決めた名前。変えずに閉じたら、開いたときの名前）。
func ask(named: String, default_name: String, role: String, done: Callable) -> void:
	_was = named
	_named = named
	_default = default_name
	_done = done
	_role.text = role
	_field.placeholder_text = default_name
	_field.text = named
	visible = true
	_field.grab_focus()
	_field.select_all()


func is_open() -> bool:
	return visible


## 欄の文字（検査用に、打ったことにもできる）。
func typed() -> String:
	return _field.text


func type(text: String) -> void:
	_field.text = text
	_on_typed(text)


## 「決定」: 欄の名前で決める（空なら既定の名前）。
func accept() -> void:
	if not visible:
		return
	var cleaned := HeroName.clean(_field.text)
	_named = cleaned if cleaned != "" else _default
	close_window()


func _on_hidden() -> void:
	_field.release_focus()
	var done := _done
	_done = Callable()
	if done.is_valid():
		done.call(_named)


## 打った文字から、使えない文字と、入らない分を落とす。
func _on_typed(text: String) -> void:
	var cleaned := HeroName.clean(text)
	# 前後の空白は、打っている途中では落とさない（間に空白のある名前を打てるように。決めるときに落とす）。
	if cleaned != text.strip_edges():
		_field.text = cleaned
		_field.caret_column = cleaned.length()
