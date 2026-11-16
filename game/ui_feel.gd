extends Node
## ボタンの小さな動き。マウスが乗ったら一瞬だけ明るく光って落ち着き、押したら一瞬だけ沈む（暗くなる）。
## テーマ（ui_theme.gd）の形の切り替えは一瞬なので、その上に色の移りだけを重ねる。待ち時間は増やさない（入力は止めない）。
## アプリの入口（app.gd）が 1 つ持ち、木に入るボタンの全部に付ける。画面の側は何もしなくてよい。
##
## 大きさは変えない: 入れ物（Container）が並べ直すたびに大きさを戻すのと、文字が拡大でぼやけるため。

## 乗ったときの明るさ（1 が元の色）と、落ち着くまでの秒数。
const HOVER_GLOW := 1.28
const HOVER_TIME := 0.22
## 押したときの暗さと、戻るまでの秒数。
const PRESS_DIM := 0.82
const PRESS_TIME := 0.14

const TWEEN_META := &"ui_feel_tween"


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.mouse_entered.connect(_pulse.bind(button, HOVER_GLOW, HOVER_TIME))
		button.button_down.connect(_pulse.bind(button, PRESS_DIM, PRESS_TIME))


## button の色を level 倍にして、seconds 秒で元へ戻す。押せないボタンは動かさない。
func _pulse(button: BaseButton, level: float, seconds: float) -> void:
	if button.disabled or not button.is_inside_tree():
		return
	var running: Tween = button.get_meta(TWEEN_META, null)
	if running != null and running.is_valid():
		running.kill()
	elif button.self_modulate != Color.WHITE:
		return  # 画面の側が色を付けているボタン（必殺技の READY の明滅など）には重ねない
	button.self_modulate = Color(level, level, level, 1.0)
	var tween := button.create_tween()
	tween.tween_property(button, "self_modulate", Color.WHITE, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	button.set_meta(TWEEN_META, tween)
