extends "res://tests/base_test.gd"
## ボタンの小さな動き（game/ui_feel.gd）。

const UiFeel := preload("res://game/ui_feel.gd")


func test_pulse_lights_an_enabled_button_and_leaves_others_alone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var feel := UiFeel.new()
	var button := Button.new()
	tree.root.add_child(button)
	feel.attach(button)
	button.mouse_entered.emit()
	assert_true(button.self_modulate.r > 1.0, "乗ったら明るくなる")
	button.self_modulate = Color.WHITE  # 木の中なら、光りは自分で元へ戻る
	button.button_down.emit()
	assert_true(button.self_modulate.r < 1.0, "押したら沈む")

	var disabled := Button.new()
	disabled.disabled = true
	tree.root.add_child(disabled)
	feel.attach(disabled)
	disabled.mouse_entered.emit()
	assert_eq(disabled.self_modulate, Color.WHITE, "押せないボタンは動かさない")

	# 画面の側が色を付けているボタンには重ねない。
	var tinted := Button.new()
	tinted.self_modulate = Color(1.0, 0.8, 0.5)
	tree.root.add_child(tinted)
	feel.attach(tinted)
	tinted.mouse_entered.emit()
	assert_eq(tinted.self_modulate, Color(1.0, 0.8, 0.5), "色の付いたボタン")

	for node: Node in [button, disabled, tinted, feel]:
		node.free()
