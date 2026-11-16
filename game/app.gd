extends Node
## アプリの入口（メインシーン）。場面（scene_flow.gd）を順に進め、場面をまたいで続くもの（設定、システムメニュー、音、暗転）を持つ。
##
## - 起動するとタイトルから始める。場面が finished(outcome) を出したら、scene_flow.gd の表で次の場面を決めて切り替える。
##   流れ（run.gd）の中の場面が「次へ」（Run.NEXT）で終わったら流れの次の場面へ、「1 つ前へ」（Run.PREVIOUS）なら前の場面へ。
##   流れは、場面が context.start_run で始める。
## - 切り替えは、短い暗転（FADE_TIME）を挟むだけ。BGM は場面の表の曲へ、フェードでつなぐ（sound.gd。同じ曲なら途切れない）。
## - システムメニュー（system_menu.gd）は、ここが開く。並べるのは、共通の項目（戻る、設定、タイトルへ戻る、ゲームを終える）と、
##   いまの場面が足すもの（menu_items）。
## - 検査（`-- --autoplay`）とスクリーンショットの道具（`-- --shots`）も、ここから入り、人と同じ道（タイトル → 対戦の設定 → 対戦）を通る。

const SceneFlow := preload("res://game/scene_flow.gd")
const AppContext := preload("res://game/app_context.gd")
const SystemMenu := preload("res://game/system_menu.gd")
const SaveStore := preload("res://game/save_store.gd")
const Sound := preload("res://game/sound.gd")
const Run := preload("res://game/run.gd")
const ScreenSize := preload("res://game/screen_size.gd")
const WindowMode := preload("res://game/window_mode.gd")

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
var _window_mode: WindowMode


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay"):
		context.checking = AppContext.CHECK_AUTOPLAY
	elif args.has("--shots"):
		context.checking = AppContext.CHECK_SHOTS
	if context.checking != &"":
		# 検査とスクリーンショットは、決めた画面の大きさで回す（`--size <幅>x<高さ>`。無ければ基準の 1280×720）。
		ScreenSize.apply_for_check(get_window(), ScreenSize.requested(args))
	# 検査とスクリーンショットは、遊ぶ人の設定を読まず、書かない（いつも既定の値で同じに動く）。
	if context.checking == &"":
		context.settings.store = SaveStore.new()
		context.settings.load_saved()
		# ストーリーの進み具合を先に読む（取っておいたストーリー用の部隊は、いま雇える駒の決まりで読む）。
		context.story.store = SaveStore.new()
		context.story.load_saved()
		context.decks.store = SaveStore.new()
		context.decks.load_saved()

	var sound := Sound.new()
	add_child(sound)
	context.sound = sound
	Sound.apply_settings(context.settings)
	context.settings.changed.connect(func(_key: StringName) -> void: Sound.apply_settings(context.settings))

	var menu := SystemMenu.new()
	add_child(menu)
	menu.setup(context.settings, context.overlays)
	menu.open_requested.connect(open_menu)
	menu.item_chosen.connect(_on_menu_item)
	menu.settings_closed.connect(context.settings.save)
	menu.opened.connect(context.play_sound.bind(&"menu_open"))
	menu.closed.connect(context.play_sound.bind(&"menu_close"))
	menu.stepped_back.connect(context.play_sound.bind(&"ui_back"))
	context.system_menu = menu
	context.menu_requested.connect(open_menu)
	context.settings_requested.connect(open_settings)
	context.run_requested.connect(start_run)

	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

	# 全画面と窓（設定の「全画面」と Alt+Enter）。検査とスクリーンショットは、窓に触らない。
	_window_mode = WindowMode.new()
	add_child(_window_mode)
	_window_mode.setup(context.settings, context.checking == &"")
	_window_mode.toggled.connect(context.settings.save)

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
	if context.run != null and context.run.scene() != scene:
		context.run = null  # 流れの外の場面へ出た（タイトルへ戻る、対戦の設定へ、など）
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
	context.scene = scene  # 場面が run_data() で、流れが渡すものを受け取れるように
	node.set(&"context", context)
	node.connect(&"finished", _on_finished.bind(scene))
	_current = node
	_current_id = scene
	# 暗転が明けるまでは、新しい場面に入力を渡さない（その間の操作は、切り替えの途中なので行き先が捨てられてしまう）。
	node.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(node)
	move_child(_window_mode, -1)  # Alt+Enter は、場面より先に受ける（入力は、子の後ろから順に届く）
	await _fade_to(0.0)
	node.process_mode = Node.PROCESS_MODE_INHERIT
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_changing = false
	scene_changed.emit(scene)


## 流れ run を、最初の場面から始める。切り替えの途中なら何もしない。
func start_run(run: Run) -> void:
	if _changing or run.is_done():
		return
	context.run = run
	go(run.scene())


func _on_finished(outcome: StringName, scene: StringName) -> void:
	if scene != _current_id:
		return  # もう抜けた場面から届いた
	if outcome == Run.NEXT and context.run != null and context.run.scene() == scene:
		var run: Run = context.run
		var following := run.advance()
		if run.is_done():
			context.run = null
		go(following)
		return
	if outcome == Run.PREVIOUS and context.run != null and context.run.scene() == scene:
		go(context.run.back())
		return
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
	if _current_id != SceneFlow.FIRST:
		items.append([ITEM_TITLE, "タイトルへ戻る", leave_confirm(scene, "タイトルへ戻りますか？")])
	items.append([ITEM_QUIT, "ゲームを終える", leave_confirm(scene, "ゲームを終えますか？")])
	return items


## 場面 scene を抜ける前の確かめの文（question のあとに、失われるもの）。抜けても失われるものが無ければ空（確かめない）。
## 失われるものの文は、場面の losing_note()（無ければ、決着していない対戦）。
static func leave_confirm(scene: Node, question: String) -> String:
	if not (scene.has_method(&"in_progress") and scene.call(&"in_progress")):
		return ""
	var losing := "いまの対戦は取っておけないので、失われる"
	if scene.has_method(&"losing_note"):
		losing = scene.call(&"losing_note")
	return "%s\n%s" % [question, losing]


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


## 検査は、人と同じ道（タイトルの「対戦」→ ステージ選択のカード → 対戦の設定の「対戦を始める」）で対戦へ入る。
## 対戦の設定では、人どうし（相手は人）を選ぶ（検査は、人の操作の入口を両方のプレイヤーで通すところから始める）。
## スクリーンショットの道具は、対戦に入ったところで足す（場面を撮る間に、ほかの場面へも行き来する）。
## 最初に対戦へ入るまでの間だけ、ここが操作する（そのあとの行き来は、検査とスクリーンショットの道具が自分でやる）。
var _check_entered := false

const CHECK_AUTOPLAY := AppContext.CHECK_AUTOPLAY


func _drive_check(scene: StringName) -> void:
	if _check_entered:
		return
	match scene:
		SceneFlow.TITLE:
			_current.call(&"press_start")
		SceneFlow.STAGE:
			_current.call(&"choose", context.match_choice.field)
		SceneFlow.SETUP:
			var panel: Node = _current.call(&"setup_panel")
			panel.call(&"choose_opponent", false)
			panel.call(&"confirm")
		SceneFlow.BATTLE:
			_check_entered = true
			if context.checking == AppContext.CHECK_SHOTS:
				# スクリーンショットの道具（tools/screenshots.gd）。遊ぶときは読み込まない。
				add_child(load("res://tools/screenshots.gd").new(self))
