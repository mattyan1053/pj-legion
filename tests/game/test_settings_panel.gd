extends "res://tests/base_test.gd"
## オプションの画面（game/settings_panel.gd）の枠: 選択肢の数や言葉で、行の右の「初期値に戻す」が動かず、ボタンの言葉が収まる。

const SettingsPanel := preload("res://game/settings_panel.gd")
const Settings := preload("res://game/settings.gd")


func test_reset_buttons_line_up_and_choice_words_fit() -> void:
	var panel := SettingsPanel.new()
	panel.setup(Settings.new())
	await settle(panel)
	var lefts := {}
	for entry: Dictionary in Settings.ITEMS:
		var key: StringName = entry["key"]
		lefts[snappedf(panel.row_reset_button(key).global_position.x, 0.5)] = key
		var buttons := panel.row_choice_buttons(key)
		for value: Variant in buttons:
			var button: Button = buttons[value]
			var font := button.get_theme_font("font")
			var words := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			var room := button.size.x - button.get_theme_stylebox("normal").get_minimum_size().x
			assert_true(words <= room, "%s の「%s」が収まらない（%.0f > %.0f）" % [key, button.text, words, room])
	assert_eq(lefts.size(), 1, "行ごとに「初期値に戻す」の位置が違う: %s" % [lefts])
	panel.free()
