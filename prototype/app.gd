extends Node
## アプリの入口（メインシーン）。場面（scene_flow.gd）を順に進め、場面をまたいで続くもの（設定、システムメニュー、音、暗転）を持つ。
##
## - 起動するとタイトルから始める。場面が finished(outcome) を出したら、scene_flow.gd の表で次の場面を決めて切り替える。
## - 切り替えは、短い暗転（FADE_TIME）を挟むだけ。BGM は場面の表の曲へ、フェードでつなぐ（sound.gd。同じ曲なら途切れない）。
## - システムメニュー（system_menu.gd）は、ここが開く。並べるのは、共通の項目（戻る、設定、タイトルへ戻る、ゲームを終える）と、
##   いまの場面が足すもの（menu_items）。
## - 検査（`-- --autoplay`）とスクリーンショットの道具（`-- --shots`）も、ここから入り、人と同じ道（タイトル → 対戦の設定 → 対戦）を通る。

const SceneFlow := preload("res://prototype/scene_flow.gd")
const AppContext := preload("res://prototype/app_context.gd")
const SystemMenu := preload("res://prototype/system_menu.gd")
const SaveStore := preload("res://prototype/save_store.gd")
const Sound := preload("res://prototype/sound.gd")

## 場面を切り替え終えた（暗転が明けた）。
signal scene_changed(scene: StringName)

## 共通のシステムメニューの項目。
const ITEM_TITLE := &"title"
const ITEM_QUIT := &"quit"
## 暗転にかける秒数（暗くなるまでと、明けるまで、それぞれ）。
const FADE_TIME := 0.22
const FADE_LAYER := 30

var context := AppContext.new()
var _current: Node
var _current_id := &""
var _changing := false
var _fade: ColorRect


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay"):
		context.checking = AppContext.CHECK_AUTOPLAY
	elif args.has("--shots"):
		context.checking = AppContext.CHECK_SHOTS
	# 検査とスクリーンショットは、遊ぶ人の設定を読まず、書かない（いつも既定の値で同じに動く）。
	if context.checking == &"":
		context.settings.store = SaveStore.new()
		context.settings.load_saved()
		context.decks.store = SaveStore.new()
		context.decks.load_saved()

	var sound := Sound.new()
	add_child(sound)
	context.sound = sound
	Sound.apply_settings(context.settings)
	context.settings.changed.connect(func(_key: StringName) -> void: Sound.apply_settings(context.settings))

	var menu := SystemMenu.new()
	add_child(menu)
	menu.setup(context.settings)
	menu.open_requested.connect(open_menu)
	menu.item_chosen.connect(_on_menu_item)
	menu.settings_closed.connect(context.settings.save)
	menu.opened.connect(context.play_sound.bind(&"menu_open"))
	menu.closed.connect(context.play_sound.bind(&"menu_close"))
	menu.stepped_back.connect(context.play_sound.bind(&"ui_back"))
	context.system_menu = menu
	context.menu_requested.connect(open_menu)
	context.settings_requested.connect(open_settings)

	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

	if context.checking != &"":
		scene_changed.connect(_drive_check)
	go(SceneFlow.FIRST)


## いまの場面（ノード）と、その名前。
func current_scene() -> Node:
	return _current


func current_id() -> StringName:
	return _current_id


func system_menu() -> SystemMenu:
	return context.system_menu


## 場面 scene へ切り替える（暗転を挟む）。終わるまで待てる。切り替えの途中なら何もしない。
func go(scene: StringName) -> void:
	if _changing or not SceneFlow.has(scene):
		if not SceneFlow.has(scene):
			push_error("app: 知らない場面: %s" % scene)
		return
	_changing = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP  # 切り替えの間のクリックは、どの場面にも届かない
	context.system_menu.close()
	(context.sound as Sound).play_scene_music(SceneFlow.music(scene))  # 暗転と同じころに、曲もつなぐ
	if _current != null:
		# 抜ける場面は止めておく（暗くなる間に、CPU の番や再生が進まないように）。
		_current.process_mode = Node.PROCESS_MODE_DISABLED
		await _fade_to(1.0)
		remove_child(_current)
		_current.queue_free()
	var node: Node = load(SceneFlow.script_path(scene)).new()
	node.set(&"context", context)
	node.connect(&"finished", _on_finished.bind(scene))
	_current = node
	_current_id = scene
	# 暗転が明けるまでは、新しい場面に入力を渡さない（その間の操作は、切り替えの途中なので行き先が捨てられてしまう）。
	node.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(node)
	await _fade_to(0.0)
	node.process_mode = Node.PROCESS_MODE_INHERIT
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_changing = false
	scene_changed.emit(scene)


func _on_finished(outcome: StringName, scene: StringName) -> void:
	if scene != _current_id:
		return  # もう抜けた場面から届いた
	var next := SceneFlow.next(scene, outcome)
	if next == &"":
		push_error("app: 場面 %s の終わり方 %s の行き先が決まっていない" % [scene, outcome])
		return
	go(next)


## システムメニューを開く（右上のボタン、場面の Esc）。切り替えの途中は開かない。
func open_menu() -> void:
	var menu := system_menu()
	if _changing or menu.is_open() or _current == null:
		return
	menu.open(menu_items())


## 設定の画面だけを開く（タイトルの「設定」）。閉じると、メニューへは戻らずに閉じる。
func open_settings() -> void:
	var menu := system_menu()
	if _changing or menu.is_open():
		return
	menu.open(menu_items(), true)


## いま並べるシステムメニューの項目。いまの場面が足すものは、「設定」のあと。
## 抜けると失われるもの（決着していない対戦）があれば、タイトルへ戻る・ゲームを終える前に確かめる。
func menu_items() -> Array:
	var scene := _current
	var resume := "戻る"
	if scene.has_method(&"resume_label"):
		resume = scene.call(&"resume_label")
	var items: Array = [[SystemMenu.ITEM_RESUME, resume, ""], [SystemMenu.ITEM_SETTINGS, "設定", ""]]
	if scene.has_method(&"menu_items"):
		items.append_array(scene.call(&"menu_items"))
	var losing: bool = scene.has_method(&"in_progress") and scene.call(&"in_progress")
	if _current_id != SceneFlow.FIRST:
		items.append([ITEM_TITLE, "タイトルへ戻る", "タイトルへ戻りますか？\nいまの対戦は取っておけないので、失われる" if losing else ""])
	items.append([ITEM_QUIT, "ゲームを終える", "ゲームを終えますか？\nいまの対戦は取っておけないので、失われる" if losing else ""])
	return items


func _on_menu_item(id: StringName) -> void:
	match id:
		ITEM_TITLE:
			go(SceneFlow.COMMON[&"title"])
		ITEM_QUIT:
			context.quit()
		_:
			if _current != null and _current.has_method(&"on_menu_item"):
				_current.call(&"on_menu_item", id)


func _fade_to(alpha: float) -> void:
	if context.checking == CHECK_AUTOPLAY:
		_fade.modulate.a = alpha  # 検査は暗転を待たない（切り替えが 1 フレームで終わるのは同じにする）
		await get_tree().process_frame
		return
	var tween := create_tween()
	tween.set_ignore_time_scale(true)  # メニューで止めた時間や、検査の速さに左右されない
	tween.tween_property(_fade, "modulate:a", alpha, FADE_TIME)
	await tween.finished


# ---- 検査 ----


## 検査は、人と同じ道（タイトルの「始める」→ 対戦の設定の「対戦を始める」）で対戦へ入る。
## 対戦の設定では、人どうし（相手は人）を選ぶ（検査は、人の操作の入口を両方のプレイヤーで通すところから始める）。
## スクリーンショットの道具は、対戦に入ったところで足す（場面を撮る間に、ほかの場面へも行き来する）。
## 最初に対戦へ入るまでの間だけ、ここが操作する（そのあとの行き来は、検査とスクリーンショットの道具が自分でやる）。
var _check_entered := false

const CHECK_AUTOPLAY := AppContext.CHECK_AUTOPLAY


func _drive_check(scene: StringName) -> void:
	if _check_entered:
		return
	match scene:
		&"title":
			_current.call(&"press_start")
		&"setup":
			var panel: Node = _current.call(&"setup_panel")
			panel.call(&"choose_opponent", false)
			panel.call(&"confirm")
		&"battle":
			_check_entered = true
			if context.checking == AppContext.CHECK_SHOTS:
				# スクリーンショットの道具（tools/screenshots.gd）。遊ぶときは読み込まない。
				add_child(load("res://tools/screenshots.gd").new(self))
