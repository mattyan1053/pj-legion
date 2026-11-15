extends PanelContainer
## 設定の画面。settings.gd の ITEMS から、区分ごとに行を作る（項目を足しても、ここは変えなくてよい）。
##
## 値はその場で settings に入れる（すぐ効く）。行ごとに「既定に戻す」、下に「すべて既定に戻す」と「戻る」。
## 閉じる（戻る・右クリック・Esc）のは、持ち主（system_menu.gd）が決める。ここは closed を出すだけ。

const Settings := preload("res://prototype/settings.gd")
const TextWrap := preload("res://prototype/text_wrap.gd")

## 「戻る」が押された。
signal closed

const COLOR_PANEL := Color(0.09, 0.11, 0.15, 0.97)
const COLOR_TEXT_DIM := Color(0.75, 0.78, 0.82)
const COLOR_SECTION := Color("ffd76a")
## 選んでいる選択肢のボタンの色。
const COLOR_CHOSEN := Color("3a7bd5")
## 項目の名前の列の幅と、説明を折り返す幅（px）。
const LABEL_WIDTH := 230.0
const NOTE_WIDTH := 560.0
const CONTROL_WIDTH := 300.0

var settings: Settings
## 項目の名前 -> その行の部品（"control"、"value"、"reset"）。
var _rows := {}
var _reset_all: Button


func setup(target: Settings) -> void:
	settings = target
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20.0)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)  # 項目が 7 つでも 720 の高さに収まるよう詰める
	add_child(column)

	var title := _label(28)
	title.text = "設定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var section := ""
	for entry in Settings.ITEMS:
		if entry["section"] != section:
			section = entry["section"]
			var heading := _label(17)
			heading.text = section
			heading.add_theme_color_override("font_color", COLOR_SECTION)
			column.add_child(heading)
		column.add_child(_build_row(entry))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_reset_all = _button("すべて既定に戻す", 17)
	_reset_all.pressed.connect(settings.reset_all)
	buttons.add_child(_reset_all)
	var back := _button("戻る", 18)
	back.custom_minimum_size = Vector2(200.0, 48.0)
	back.pressed.connect(closed.emit)
	buttons.add_child(back)

	settings.changed.connect(func(_key: StringName) -> void: refresh())
	refresh()


## いまの値を、画面の部品に写す（値を外から変えたときも、これで追いつく）。
func refresh() -> void:
	var any_changed := false
	for key: StringName in _rows:
		var row: Dictionary = _rows[key]
		var entry := Settings.item(key)
		var shown: Variant = settings.value(key)
		match entry["kind"]:
			Settings.Kind.SLIDER:
				(row["control"] as HSlider).set_value_no_signal(shown)
			Settings.Kind.TOGGLE, Settings.Kind.CHOICE:
				var choices: Dictionary = row["control"]
				for choice_value: Variant in choices:
					(choices[choice_value] as Button).set_pressed_no_signal(choice_value == shown)
		# 選ぶボタンの並ぶ項目は、押されているボタンが値なので、横に値の文字を重ねて出さない。
		(row["value"] as Label).text = Settings.value_text(entry, shown) if entry["kind"] == Settings.Kind.SLIDER else ""
		(row["reset"] as Button).disabled = settings.is_default(key)
		any_changed = any_changed or not settings.is_default(key)
	_reset_all.disabled = not any_changed


## 項目 key の行の操作の部品（スライダーか、値 -> ボタンの辞書）。検査とスクリーンショットの道具用。
func control_of(key: StringName) -> Variant:
	return _rows[key]["control"] if _rows.has(key) else null


func _build_row(entry: Dictionary) -> Control:
	var key: StringName = entry["key"]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var label := _label(18)
	label.text = entry["label"]
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	row.add_child(label)

	var control: Variant
	var holder := HBoxContainer.new()
	holder.custom_minimum_size = Vector2(CONTROL_WIDTH, 36.0)
	holder.add_theme_constant_override("separation", 6)
	row.add_child(holder)
	match entry["kind"]:
		Settings.Kind.SLIDER:
			var slider := HSlider.new()
			slider.min_value = entry["min"]
			slider.max_value = entry["max"]
			slider.step = entry["step"]
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.custom_minimum_size = Vector2(0.0, 28.0)
			slider.focus_mode = Control.FOCUS_NONE
			slider.value_changed.connect(func(new_value: float) -> void: settings.set_value(key, new_value))
			holder.add_child(slider)
			control = slider
		Settings.Kind.TOGGLE, Settings.Kind.CHOICE:
			# オン・オフも、選択肢と同じに、押されているほうが分かるボタンを並べる（スイッチの絵は暗い背景で見えにくい）。
			var choices: Array = [[false, "オフ"], [true, "オン"]] if entry["kind"] == Settings.Kind.TOGGLE else entry["choices"]
			var group := ButtonGroup.new()
			var buttons := {}
			for choice: Array in choices:
				var button := _button(choice[1], 16)
				button.toggle_mode = true
				button.button_group = group
				# 押されている（選んでいる）ボタンは、明るい色で塗って、どれを選んでいるかを一目で分かるようにする。
				button.add_theme_stylebox_override("pressed", _chosen_style())
				button.add_theme_stylebox_override("hover_pressed", _chosen_style())
				button.add_theme_color_override("font_pressed_color", Color.WHITE)
				button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
				button.custom_minimum_size = Vector2(0.0, 36.0)
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var choice_value: Variant = choice[0]
				button.pressed.connect(func() -> void: settings.set_value(key, choice_value))
				holder.add_child(button)
				buttons[choice_value] = button
			control = buttons

	var shown := _label(17)
	shown.custom_minimum_size = Vector2(90.0, 0.0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(shown)
	var reset := _button("既定に戻す", 15)
	reset.custom_minimum_size = Vector2(110.0, 34.0)
	reset.pressed.connect(func() -> void: settings.reset(key))
	row.add_child(reset)

	var note := _label(14)
	note.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	note.add_theme_constant_override("outline_size", 0)
	box.add_child(note)
	_set_folded(note, entry.get("note", ""), NOTE_WIDTH)
	_rows[key] = {"control": control, "value": shown, "reset": reset}
	return box


static func _chosen_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CHOSEN
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6.0)
	return style


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size = Vector2(150.0, 44.0)
	button.focus_mode = Control.FOCUS_NONE
	return button


## label に、width（px）で折り返した text を出す（text_wrap.gd。日本語の禁則を守る）。
static func _set_folded(label: Label, text: String, width: float) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	label.text = TextWrap.fold(text, width, func(character: String) -> float:
		return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
