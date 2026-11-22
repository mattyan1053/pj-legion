extends Node
## セーブデータを選ぶ場面（docs/save-slots.md の「セーブデータ選択」）。タイトルの「ストーリー」のあと、物語を選ぶ場面の前。
## 背景は物語を選ぶ場面と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。
##
## - スロット（save_slots.gd の COUNT 個）をカードで並べる。中身のあるカードは「つづきから」: 物語、クリアした話の数、
##   いちばん先のクリアした話、最後に保存した日時、プレイ時間。空きのカードは「はじめから」。
## - カードのクリックで、そのスロットを選んで（空きなら新しく始めて）&"open"（物語を選ぶ場面へ）。
## - カードの下に「コピー」「削除」。コピーは、写す先のカードを選ぶ（中身があれば上書きを確かめる）。削除は確かめてから。
## - 読み込めない・新しい版のスロットは選べない（削除はできる。削除するまで、勝手に書かない）。
## - 「タイトルへ戻る」（右クリック・Esc でも）で &"back"。コピー先を選んでいる間の右クリック・Esc は、コピーをやめる。

const SceneFlow := preload("res://game/scene_flow.gd")
const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Ornament := preload("res://game/ui_ornament.gd")
const AppContext := preload("res://game/app_context.gd")
const TitleBackdrop := preload("res://game/title_backdrop.gd")
const Story := preload("res://game/story.gd")
const SaveSlots := preload("res://game/save_slots.gd")
const CardKeys := preload("res://game/card_keys.gd")
const ConfirmWindow := preload("res://game/confirm_window.gd")
const CampaignList := preload("res://game/campaign_list_screen.gd")

signal finished(outcome: StringName)

const CARD_SIZE := Vector2(320.0, 260.0)

var context: AppContext
## スロットの番号 -> カード（Button）。
var _cards := {}
## スロットの番号 -> [コピーのボタン, 削除のボタン]。
var _tools := {}
var _row: HBoxContainer
var _sub: Label
var _back: Button
var _confirm: ConfirmWindow
## コピーの元のスロット（コピー先を選んでいなければ 0）。
var _copy_from := 0
var _key_index := -1
var _backdrop: TitleBackdrop


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	# 背景はタイトルと同じ裂けた空の下。セーブデータのカードに乗せると、そのデータの物語の景色（国の側の空、国の色の空、
	# クリアしたいちばん先の話の次の話のマップ。title_backdrop.gd の show_story）に替わる。開いたときは、いまのデータのもの。
	_backdrop = TitleBackdrop.new(TitleBackdrop.VIEW_STORY)
	var shown := scape_of(context.slots.current)
	if shown.is_empty():
		_backdrop.show_story(-1, null, &"", &"")
	else:
		_backdrop.show_story(shown[0], shown[1], shown[2], shown[3])
	add_child(_backdrop)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(UiTheme.vista_shade())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 36.0
	root.offset_bottom = -28.0
	root.add_theme_constant_override("separation", 10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var heading := _label(Text.t("slots.heading"), 40)
	heading.theme_type_variation = UiTheme.LABEL_HEADING
	heading.add_theme_constant_override("outline_size", 10)
	root.add_child(heading)
	var ornament := Ornament.new(360.0, 14.0)
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(ornament)
	_sub = _label(Text.t("slots.sub"), 18)
	_sub.add_theme_color_override("font_color", Palette.TEXT_DIM)
	root.add_child(_sub)

	root.add_child(_spacer())
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 28)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_row)
	root.add_child(_spacer())

	_back = Button.new()
	_back.focus_mode = Control.FOCUS_NONE
	_back.add_theme_font_size_override("font_size", 18)
	_back.custom_minimum_size = Vector2(220.0, 48.0)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(press_back)
	root.add_child(_back)

	_confirm = ConfirmWindow.new()
	_confirm.overlays = context.overlays
	layer.add_child(_confirm)
	_rebuild()


func resume_label() -> String:
	return Text.t("slots.resume")


# ---- 操作 ----


## スロット number のカード: コピー先を選んでいればそこへコピー、そうでなければ選んで物語を選ぶ場面へ。
func choose(number: int) -> void:
	if _copy_from != 0:
		copy_to(number)
		return
	if not is_card_enabled(number):
		return
	if context.use_slot(number):
		finished.emit(&"open")


## スロット number の「コピー」: コピー先を選ぶ状態にする。
func press_copy(number: int) -> void:
	if state_of(number) != SaveSlots.READY:
		return
	_copy_from = number
	_rebuild()


## コピー先 number へ写す（中身があれば、上書きを確かめる）。
func copy_to(number: int) -> void:
	if _copy_from == 0 or number == _copy_from:
		return
	var from := _copy_from
	if state_of(number) == SaveSlots.EMPTY:
		_do_copy(from, number)
		return
	_confirm.ask(Text.t("slots.copy.confirm", {"to": number}), Text.t("slots.copy.note", {"to": number}), Text.t("slots.copy.ok"),
		_do_copy.bind(from, number))


func _do_copy(from: int, to: int) -> void:
	_copy_from = 0
	if context.slots.copy(from, to) and to == context.slots.current:
		context.reload_slot()
	_rebuild()


## スロット number の「削除」: 確かめてから消す。
func press_delete(number: int) -> void:
	if state_of(number) == SaveSlots.EMPTY:
		return
	_confirm.ask(Text.t("slots.delete.confirm", {"number": number}), Text.t("slots.delete.note"), Text.t("slots.delete.ok"),
		func() -> void:
			context.slots.remove(number)
			if number == context.slots.current:
				context.reload_slot()
			_rebuild())


## コピー先を選ぶのをやめる。
func cancel_copy() -> void:
	_copy_from = 0
	_rebuild()


## 「タイトルへ戻る」（コピー先を選んでいる間は「キャンセル」）。
func press_back() -> void:
	if _copy_from != 0:
		cancel_copy()
		return
	finished.emit(&"back")


# ---- 検査用 ----


func state_of(number: int) -> StringName:
	return context.slots.info(number)["state"]


func is_card_enabled(number: int) -> bool:
	return _cards.has(number) and not (_cards[number] as Button).disabled


func is_copying() -> bool:
	return _copy_from != 0


func confirm_window() -> ConfirmWindow:
	return _confirm


## カード number の文（行を改行でつないだもの）。
func card_text(number: int) -> String:
	return "\n".join(card_lines(context.slots.info(number), number))


## カードに出す行（上から）。
static func card_lines(info: Dictionary, number: int) -> PackedStringArray:
	var lines := PackedStringArray([Text.t("slots.number", {"number": number})])
	match info["state"]:
		SaveSlots.EMPTY:
			lines.append(Text.t("slots.empty"))
			lines.append(Text.t("slots.new"))
		SaveSlots.BROKEN:
			lines.append(Text.t("slots.broken"))
		SaveSlots.NEWER:
			lines.append(Text.t("slots.newer"))
		_:
			var story_section: Variant = (info["sections"] as Dictionary).get(Story.STORE_NAME)
			var data: Dictionary = story_section.get("data", {}) if typeof(story_section) == TYPE_DICTIONARY and typeof(story_section.get("data")) == TYPE_DICTIONARY else {}
			var summary := Story.summary_of(data)
			if summary["campaign"] == null:
				lines.append(Text.t("slots.no_campaign"))
				lines.append(Text.t("slots.not_cleared"))
			else:
				lines.append(summary["campaign"].title)
				lines.append(Text.t("slots.progress", {"cleared": summary["cleared"], "total": summary["total"]}))
				var last: Variant = summary["last"]
				lines.append(Text.t("slots.last", {"number": Story.number_of(last), "title": last.title}) if last != null else Text.t("slots.not_cleared"))
			lines.append(date_text(info["saved_at"]))
			lines.append(played_text(info["played_seconds"]))
			lines.append(Text.t("slots.continue"))
	return lines


## 時刻（Unix 時刻）を、この機械の時間帯の「年/月/日 時:分」にする。
static func date_text(unix: int) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var at := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return Text.t("slots.date", {"year": at["year"], "month": "%02d" % at["month"], "day": "%02d" % at["day"],
		"hour": "%02d" % at["hour"], "minute": "%02d" % at["minute"]})


## 遊んだ時間（秒）を「プレイ時間 時:分」にする。
static func played_text(seconds: int) -> String:
	return Text.t("slots.played", {"hours": seconds / 3600, "minutes": "%02d" % ((seconds / 60) % 60)})


# ---- 入力 ----


func _input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	if _key_index >= 0 and CardKeys.is_pointer_move(event):
		select_by_key(-1)
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or escape:
		get_viewport().set_input_as_handled()
		context.play_sound(&"ui_back")
		press_back()


func _unhandled_input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	var step := CardKeys.direction(event)
	if step != 0:
		get_viewport().set_input_as_handled()
		select_by_key(CardKeys.next(_key_index, step, SaveSlots.COUNT, func(i: int) -> bool: return is_card_enabled(i + 1)))
		return
	if CardKeys.is_accept(event) and _key_index >= 0:
		get_viewport().set_input_as_handled()
		context.play_sound(&"ui_confirm")
		choose(_key_index + 1)


## キーボードで index 番目（0 から）のカードを選ぶ。-1 で選ぶのをやめる。
func select_by_key(index: int) -> void:
	if _key_index >= 0 and _cards.has(_key_index + 1):
		(_cards[_key_index + 1] as Button).remove_theme_stylebox_override("normal")
	_key_index = index
	if index >= 0:
		var card: Button = _cards[index + 1]
		card.add_theme_stylebox_override("normal", card.get_theme_stylebox("hover"))
		focus(index + 1)


## セーブデータ number の物語の景色: [軍, 盤, 見た目, 話の id]。物語の無いデータ（空き・まだ物語を選んでいない）は空。
func scape_of(number: int) -> Array:
	if number < 1 or number > SaveSlots.COUNT:
		return []
	var info := context.slots.info(number)
	if info["state"] != SaveSlots.READY:
		return []
	var story_section: Variant = (info["sections"] as Dictionary).get(Story.STORE_NAME)
	if typeof(story_section) != TYPE_DICTIONARY or typeof(story_section.get("data")) != TYPE_DICTIONARY:
		return []
	var summary := Story.summary_of(story_section["data"])
	if summary["campaign"] == null:
		return []
	var episode := Story.scape_episode(summary["campaign"], summary["last"])
	return [summary["campaign"].army, episode.map.make_board(), episode.look, episode.id]


## セーブデータ number を選んでいる（マウスを乗せた・キーで選んだ）: 背景を、そのデータの物語の景色に替える（とどまったら）。
## 物語の無いデータは、いつもの景色（縫い目が真ん中の結晶の森）へ戻す。
func focus(number: int) -> void:
	var shown := scape_of(number)
	if shown.is_empty():
		_backdrop.queue_story(-1, null, &"", &"")
	else:
		_backdrop.queue_story(shown[0], shown[1], shown[2], shown[3])


## 背景（検査とスクリーンショットの道具用）。
func backdrop() -> TitleBackdrop:
	return _backdrop


# ---- 組み立て ----


func _rebuild() -> void:
	_key_index = -1
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_cards.clear()
	_tools.clear()
	for number in range(1, SaveSlots.COUNT + 1):
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(column)
		var info := context.slots.info(number)
		var card := _build_card(info, number)
		column.add_child(card)
		_cards[number] = card
		var tools := HBoxContainer.new()
		tools.alignment = BoxContainer.ALIGNMENT_CENTER
		tools.add_theme_constant_override("separation", 10)
		column.add_child(tools)
		var copy := _small_button(Text.t("slots.copy"))
		copy.pressed.connect(press_copy.bind(number))
		copy.disabled = info["state"] != SaveSlots.READY or _copy_from != 0
		tools.add_child(copy)
		var delete := _small_button(Text.t("slots.delete"))
		delete.theme_type_variation = UiTheme.BUTTON_DANGER
		delete.pressed.connect(press_delete.bind(number))
		delete.disabled = info["state"] == SaveSlots.EMPTY or _copy_from != 0
		tools.add_child(delete)
		_tools[number] = [copy, delete]
	if _copy_from != 0:
		_sub.text = Text.t("slots.copy.pick", {"number": _copy_from})
		_sub.add_theme_color_override("font_color", Palette.ACCENT)
		_back.text = Text.t("slots.copy.cancel")
	else:
		_sub.text = Text.t("slots.sub")
		_sub.add_theme_color_override("font_color", Palette.TEXT_DIM)
		_back.text = Text.t("menu.to_title")


func _build_card(info: Dictionary, number: int) -> Button:
	var state: StringName = info["state"]
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = CARD_SIZE
	card.theme_type_variation = UiTheme.BUTTON_CARD
	card.set_meta(&"sound", &"ui_confirm")
	if _copy_from != 0:
		card.disabled = number == _copy_from or state in [SaveSlots.BROKEN, SaveSlots.NEWER]
	else:
		card.disabled = state in [SaveSlots.BROKEN, SaveSlots.NEWER]
	card.pressed.connect(choose.bind(number))
	card.mouse_entered.connect(focus.bind(number))
	card.mouse_exited.connect(func() -> void: _backdrop.cancel_queued())
	var lines := card_lines(info, number)
	var summary_campaign: Variant = null
	if state == SaveSlots.READY:
		var story_section: Variant = (info["sections"] as Dictionary).get(Story.STORE_NAME)
		if typeof(story_section) == TYPE_DICTIONARY and typeof(story_section.get("data")) == TYPE_DICTIONARY:
			summary_campaign = Story.summary_of(story_section["data"])["campaign"]
	if summary_campaign != null:
		card.add_child(CampaignList.CardDecor.new(summary_campaign.army, true))
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14.0
	column.offset_right = -14.0
	column.offset_top = 18.0
	column.offset_bottom = -14.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	for i in lines.size():
		var line := _label(lines[i], 16)
		if i == 0:
			line.add_theme_font_override("font", UiTheme.FONT_HEADING)
			line.add_theme_font_size_override("font_size", 22)
			line.add_theme_color_override("font_color", Palette.ACCENT)
		elif i == 1 and state == SaveSlots.READY:
			line.add_theme_font_override("font", UiTheme.FONT_HEADING)
			line.add_theme_font_size_override("font_size", 22)
		elif i == lines.size() - 1 and state in [SaveSlots.READY, SaveSlots.EMPTY]:
			line.add_theme_font_size_override("font_size", 18)
			line.add_theme_color_override("font_color", Palette.INFO)
		elif state in [SaveSlots.BROKEN, SaveSlots.NEWER]:
			line.add_theme_color_override("font_color", Palette.DANGER)
		else:
			line.add_theme_color_override("font_color", Palette.TEXT_DIM)
		column.add_child(line)
	return card


func _small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size = Vector2(110.0, 40.0)
	return button


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
