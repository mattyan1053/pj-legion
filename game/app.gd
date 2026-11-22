extends Node
## アプリの入口（メインシーン）。場面（scene_flow.gd）を順に進め、場面をまたいで続くもの（設定、システムメニュー、音、暗転）を持つ。
##
## - 起動するとタイトルから始める。場面が finished(outcome) を出したら、scene_flow.gd の表で次の場面を決めて切り替える。
##   流れ（run.gd）の中の場面が「次へ」（Run.NEXT）で終わったら流れの次の場面へ、「1 つ前へ」（Run.PREVIOUS）なら前の場面へ。
##   流れは、場面が context.start_run で始める。
## - 切り替えは、短い暗転（FADE_TIME）を挟むだけ。BGM は場面の表の曲へ、フェードでつなぐ（sound.gd。同じ曲なら途切れない）。
## - システムメニュー（system_menu.gd）は、ここが開く。並べるのは、共通の項目（戻る、設定、タイトルへ戻る、ゲームを終える）と、
##   いまの場面が足すもの（menu_items）。
## - 検査（`-- --autoplay`）とスクリーンショットの道具（`-- --shots`）も、ここから入り、人と同じ道（タイトル → 対戦設定 → 対戦）を通る。

const Text := preload("res://game/text.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const AppContext := preload("res://game/app_context.gd")
const SystemMenu := preload("res://game/system_menu.gd")
const SaveStore := preload("res://game/save_store.gd")
const Sound := preload("res://game/sound.gd")
const Run := preload("res://game/run.gd")
const ScreenSize := preload("res://game/screen_size.gd")
const WindowMode := preload("res://game/window_mode.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const UiFeel := preload("res://game/ui_feel.gd")
const UnitLooks := preload("res://game/unit_looks.gd")
const StageLook := preload("res://game/stage_look.gd")
const PieceStyle := preload("res://game/piece_style.gd")
const Palette := preload("res://game/ui_palette.gd")
const SaveMark := preload("res://game/save_mark.gd")
const SlotScreen := preload("res://game/slot_screen.gd")
const ConfirmWindow := preload("res://game/confirm_window.gd")
const WIPE := preload("res://game/wipe.gdshader")

## 場面を切り替え終えた（暗転が明けた）。
signal scene_changed(scene: StringName)

## 共通のシステムメニューの項目。
const ITEM_TITLE := &"title"
const ITEM_QUIT := &"quit"
## 流れの外への行き先の項目の名前の頭（後ろに場面の名前。Run.menu_exits）。
const ITEM_EXIT_PREFIX := "exit:"
## 暗転にかける秒数（暗くなるまでと、明けるまで、それぞれ）。
const FADE_TIME := 0.22
const FADE_LAYER := 30
const OpenAllKey := preload("res://game/open_all_key.gd")

var context := AppContext.new()
var _current: Node
var _current_id := &""
var _changing := false
var _fade: ColorRect
var _wipe: ShaderMaterial
## 幕がどこまで覆っているか（0 = 明けている、1 = 覆っている）。
var _cover := 1.0
var _window_mode: WindowMode
## 保存の小さな印（オートセーブで書いたとき）。
var save_mark: SaveMark
## ウィンドウの × で閉じる前の確かめ（docs/save-slots.md の「ウィンドウを閉じるとき」）。
var quit_window: ConfirmWindow
const QUIT_LAYER := 26
## オプションの画面を開いてから、設定が変わったか（閉じて書いたときに、保存の印を出す）。
var _settings_touched := false
var _open_all: OpenAllKey
## 検査のときだけ持つ、枠の見張り（game/steady_probe.gd）。
var steady_probe: Node


func _ready() -> void:
	UiTheme.install()  # どの画面を作るよりも前に、UI のテーマを当てる
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay"):
		context.checking = AppContext.CHECK_AUTOPLAY
	elif args.has("--shots"):
		context.checking = AppContext.CHECK_SHOTS
	if context.checking != &"":
		# 枠の大きさが中身で変わらないことを見張る（docs/ui-theme.md の「枠の大きさ」）。`--frames` は洗い出し。
		steady_probe = load("res://game/steady_probe.gd").new(args.has("--frames"))
		steady_probe.name = "SteadyProbe"
		add_child(steady_probe)
		scene_changed.connect(func(_scene: StringName) -> void: steady_probe.forget_all())
		# 検査とスクリーンショットは、決めた画面の大きさで回す（`--size <幅>x<高さ>`。無ければ基準の 1280×720）。
		ScreenSize.apply_for_check(get_window(), ScreenSize.requested(args))
		# 駒の見た目の組を選んで撮る・回す（`--unit-look <組の名前>`。無ければ既定の組）。
		var at := args.find("--unit-look")
		if at != -1 and at + 1 < args.size():
			context.settings.set_value(AppContext.Settings.UNIT_LOOK, UnitLooks.ORDER.find(StringName(args[at + 1])))
			UnitLooks.use(UnitLooks.name_at(context.settings.value(AppContext.Settings.UNIT_LOOK)))
	# 検査とスクリーンショットは、遊ぶ人の設定を読まず、書かない（いつも既定の値で同じに動く）。
	if context.checking == &"":
		context.settings.store = SaveStore.new()
		context.settings.load_saved()
		# セーブのスロット（ストーリーの進み具合とストーリー用の部隊）。前の置き方のファイルがあれば 1 番へ移し、最後に遊んだスロットを開く。
		context.slots.store = SaveStore.new()
		context.slots.migrate_old(func(rules: String) -> bool: return AppContext.is_story_rules(StringName(rules)))
		context.slots.open_latest()
		context.decks.store = SaveStore.new()
		context.reload_slot()

	# 画面の効果（光のにじみ、陰、色の調子）は、オプションで切れる。変えたら、いまの景色にもすぐ効く。
	StageLook.set_effects(context.settings.value(AppContext.Settings.SCREEN_EFFECTS))
	context.settings.changed.connect(func(key: StringName) -> void:
		if key == AppContext.Settings.SCREEN_EFFECTS:
			StageLook.set_effects(context.settings.value(key)))

	add_child(UiFeel.new())  # ボタンにマウスが乗ったとき・押したときの小さな動き
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
	menu.settings_closed.connect(_on_settings_closed)
	context.settings.changed.connect(func(_key: StringName) -> void: _settings_touched = true)
	menu.opened.connect(context.play_sound.bind(&"menu_open"))
	menu.closed.connect(context.play_sound.bind(&"menu_close"))
	menu.stepped_back.connect(context.play_sound.bind(&"ui_back"))
	context.system_menu = menu
	context.menu_requested.connect(open_menu)
	context.settings_requested.connect(open_settings)
	context.quit_requested.connect(request_close)
	context.run_requested.connect(start_run)

	save_mark = SaveMark.new()
	add_child(save_mark)
	var quit_layer := CanvasLayer.new()
	quit_layer.layer = QUIT_LAYER  # システムメニュー（20）の上、幕（30）の下
	add_child(quit_layer)
	quit_window = ConfirmWindow.new()
	quit_window.overlays = context.overlays
	quit_window.pausing = true
	quit_layer.add_child(quit_window)
	# ウィンドウの × は、すぐには閉じずに request_close で受ける（途中のものがあれば確かめる）。検査は、窓に触らない。
	if context.checking == &"":
		get_tree().auto_accept_quit = false
	context.slots.saved.connect(save_mark.flash)

	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	# 幕は、斜めに拭き取るように覆って、同じ向きへ抜ける（wipe.gdshader）。
	_wipe = ShaderMaterial.new()
	_wipe.shader = WIPE
	_wipe.set_shader_parameter(&"ink", Palette.INK)
	_wipe.set_shader_parameter(&"edge", Palette.BORDER_BRIGHT)
	_wipe.set_shader_parameter(&"cover", 1.0)
	_fade.material = _wipe
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

	# 全画面と窓（設定の「全画面」と Alt+Enter）。検査とスクリーンショットは、窓に触らない。
	_window_mode = WindowMode.new()
	add_child(_window_mode)
	_window_mode.setup(context.settings, context.checking == &"")
	_window_mode.toggled.connect(context.settings.save)

	# 確かめ用の解放（F5。ストーリーの全部の話と解放を、その起動のあいだだけ開く）。
	_open_all = OpenAllKey.new()
	add_child(_open_all)
	_open_all.setup(self)

	if context.checking != &"":
		scene_changed.connect(_drive_check)
	go(SceneFlow.FIRST)


## 確かめ用の解放の鍵（open_all_key.gd。検査用）。
func open_all_key() -> OpenAllKey:
	return _open_all


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
		context.run = null  # 流れの外の場面へ出た（タイトルへ戻る、対戦設定へ、など）
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP  # 切り替えの間のクリックは、どの場面にも届かない
	context.system_menu.close()
	_track_story_time(scene)
	# 暗転と同じころに、曲もつなぐ。流れが渡すものが曲を決めていれば、その曲（対戦の盤の見た目、話の会話）。
	var given: Variant = context.run.data() if context.run != null else null
	var track := SceneFlow.music_for(scene, given)
	(context.sound as Sound).play_scene_music(track, SceneFlow.music_offset_db(scene, track))
	if _current != null:
		# 抜ける場面は止めておく（暗くなる間に、CPU の番や再生が進まないように）。
		_current.process_mode = Node.PROCESS_MODE_DISABLED
		await _fade_to(1.0)
		remove_child(_current)
		_current.queue_free()
	# 駒の見た目の組は、場面を作るときにだけ替える（場面の途中でオプションを変えても、盤の駒とアイコンが混ざらない）。
	UnitLooks.use(UnitLooks.name_at(context.settings.value(AppContext.Settings.UNIT_LOOK)))
	# 駒の縁取り（piece_style.gd）も、場面を作るときに当てる（場面の途中で縁のある駒とない駒が混ざらない）。
	PieceStyle.outline = context.settings.value(AppContext.Settings.PIECE_OUTLINE)
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


## ストーリーを遊んでいる間（物語を選ぶ場面に入ってから、タイトル・スロットの場面・マップ選択へ出るまで）、
## いまのスロットの遊んだ時間を数える。
## 区切り（オートセーブ。docs/save-slots.md の「保存する所」）で、いまのスロットを書く:
## 話の流れ（出撃準備・会話・対戦・寄り道の部隊編成）を抜けて、話の一覧・物語選択・タイトルへ出たとき
## （話をクリアしたなら、あとの会話と解放の知らせが済んだ所）と、あとの会話の「次の話へ」で次の話の出撃準備へ進んだとき。
## ウィンドウを閉じた瞬間や、流れの途中は書かない（最後に書いた所までが残る）。
const STORY_RUN_SCENES := [SceneFlow.SORTIE, SceneFlow.TALK, SceneFlow.BATTLE, SceneFlow.DECKS]

func _track_story_time(scene: StringName) -> void:
	var slots: AppContext.SaveSlots = context.slots
	var from := _current_id
	if not slots.counting:
		slots.counting = scene == SceneFlow.CAMPAIGNS
		return
	var left_run: bool = from in STORY_RUN_SCENES and scene not in STORY_RUN_SCENES
	var next_episode: bool = from == SceneFlow.TALK and scene == SceneFlow.SORTIE
	if left_run or next_episode:
		slots.flush_if_started()
	if scene in [SceneFlow.TITLE, SceneFlow.SLOTS, SceneFlow.MAP_SELECT]:
		slots.counting = false


## オプションの画面を閉じた: 設定を書く（オートセーブの区切り）。変えたものがあれば、保存の印を出す。
func _on_settings_closed() -> void:
	if context.settings.save() and _settings_touched:
		save_mark.flash()
	_settings_touched = false


## ウィンドウの × を押された。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and context.checking == &"":
		request_close()


## ウィンドウを閉じたい（× を押した）: その瞬間のものは保存しない（最後にオートセーブした所までが残る）。
## どの画面でも、すぐには閉じずに確かめる（文はいつも同じ。quit_note）。確かめている間にもう一度 × を押したら、閉じる。
func request_close() -> void:
	if quit_window.is_open():
		context.quit()
		return
	context.system_menu.close()
	quit_window.ask(Text.t("menu.quit.confirm"), quit_note(), Text.t("menu.quit"), context.quit)


## ゲームを終える前の確かめに書く文。どの画面でも同じ（「セーブしていない内容は失われます。」。docs/save-slots.md）。
static func quit_note() -> String:
	return Text.t("menu.quit.note")


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
	menu.open(menu_items(), false, last_saved_note())


## ストーリーを遊んでいる間の、システムメニューの見出しの下の文（「最後のオートセーブ: 日時」）。ストーリーの外では空。
func last_saved_note() -> String:
	if not context.slots.counting:
		return ""
	return last_saved_text(context.slots)


## いまのスロットを最後にオートセーブした時刻の文（まだ書いていなければ「なし」）。
static func last_saved_text(slots: AppContext.SaveSlots) -> String:
	var at := slots.saved_at()
	return Text.t("menu.last_saved", {"when": SlotScreen.date_text(at) if at > 0 else Text.t("menu.never_saved")})


## オプションの画面だけを開く（タイトルの「オプション」）。閉じると、メニューへは戻らずに閉じる。
func open_settings() -> void:
	var menu := system_menu()
	if _changing or menu.is_open():
		return
	menu.open(menu_items(), true)


## いま並べるシステムメニューの項目。いまの場面が足すものは、「設定」のあと。
## 抜けると失われるもの（決着していない対戦）があれば、タイトルへ戻る・ゲームを終える前に確かめる。
func menu_items() -> Array:
	var scene := _current
	var resume := Text.t("common.back")
	if scene.has_method(&"resume_label"):
		resume = scene.call(&"resume_label")
	var items: Array = [[SystemMenu.ITEM_RESUME, resume, ""], [SystemMenu.ITEM_SETTINGS, Text.t("menu.settings"), ""]]
	if scene.has_method(&"menu_items"):
		items.append_array(scene.call(&"menu_items"))
	# 流れの外への行き先（ストーリーの「話の一覧へ戻る」、対戦の「マップ選択へ戻る」）。タイトルへ戻るより先に並べる。
	if context.run != null:
		for exit: Array in context.run.menu_exits:
			items.append([ITEM_EXIT_PREFIX + String(exit[0]), Text.t(exit[1]), leave_confirm(scene, Text.t(exit[2]))])
	if _current_id != SceneFlow.FIRST:
		items.append([ITEM_TITLE, Text.t("menu.to_title"), leave_confirm(scene, Text.t("menu.to_title.confirm"))])
	# ゲーム終了は、ウィンドウの × と同じ確かめ（どの画面でも確かめる）。
	items.append([ITEM_QUIT, Text.t("menu.quit"), "%s\n%s" % [Text.t("menu.quit.confirm"), quit_note()]])
	return items


## 場面 scene を抜ける前の確かめの文（question のあとに、失われるもの）。抜けても失われるものが無ければ空（確かめない）。
## 失われるものの文は、場面の losing_note()（無ければ、決着していない対戦）。
static func leave_confirm(scene: Node, question: String) -> String:
	if not (scene.has_method(&"in_progress") and scene.call(&"in_progress")):
		return ""
	var losing := Text.t("menu.losing.battle")
	if scene.has_method(&"losing_note"):
		losing = scene.call(&"losing_note")
	return "%s\n%s" % [question, losing]


func _on_menu_item(id: StringName) -> void:
	match id:
		ITEM_TITLE:
			go(SceneFlow.COMMON[&"title"])
		ITEM_QUIT:
			context.quit()
		_ when String(id).begins_with(ITEM_EXIT_PREFIX):
			go(StringName(String(id).trim_prefix(ITEM_EXIT_PREFIX)))  # 流れの外の場面なので、流れは捨てる（go）
		_:
			if _current != null and _current.has_method(&"on_menu_item"):
				_current.call(&"on_menu_item", id)


func _fade_to(alpha: float) -> void:
	_wipe.set_shader_parameter(&"direction", 1.0 if alpha > _cover else -1.0)
	if context.checking == CHECK_AUTOPLAY:
		_set_cover(alpha)  # 検査は暗転を待たない（切り替えが 1 フレームで終わるのは同じにする）
		await get_tree().process_frame
		return
	var tween := create_tween()
	tween.set_ignore_time_scale(true)  # メニューで止めた時間や、検査の速さに左右されない
	tween.tween_method(_set_cover, _cover, alpha, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _set_cover(value: float) -> void:
	_cover = value
	_wipe.set_shader_parameter(&"cover", value)


# ---- 検査 ----


## 検査は、人と同じ道（タイトルの「対戦」→ マップ選択のカード → 対戦設定の「対戦を始める」）で対戦へ入る。
## 対戦設定では、人どうし（相手は人）を選ぶ（検査は、人の操作の入口を両方のプレイヤーで通すところから始める）。
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
		SceneFlow.MAP_SELECT:
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
