extends "res://game/sortie_screen/sortie_layout.gd"
## 出撃準備の場面（docs/story.md）。ストーリーの話の最初の場面（出撃のあとに、前の会話と対戦）。マップ・勝ち方・敵を見て、出撃する部隊を選ぶ。
## 背景は話の盤（backdrop.gd）。場面の決まりは scene_flow.gd。流れ（run.gd）が {"episode": 話, "battle": 話の対戦（story_battle.gd）} を渡す。
##
## - 左: 初期位置（deploy_map.gd）。盤の縮図に、味方の駒のアイコンと、敵と中立の駒の点（選んだ部隊で置き直す）。
## - 右: この話で覚えること（話の lesson。チュートリアル）、勝ち方、敵の部隊、出撃する部隊の選択
##   （既定の編成と、取っておいたストーリー用の部隊。出せない部隊は理由つきで押せない）。
##   部隊が決まっている話（話の [ally] に unit がある）は、その部隊だけを出し、「部隊編成」も出さない。
## - 「出撃」で、選んだ部隊を話の対戦に持たせて Run.NEXT（対戦へ）。選んだ部隊は覚えておき（story.gd の squad_id）、次の話でも、次に起動しても選ばれている。
## - 「部隊編成」で、部隊編成（ストーリー用）へ寄り道する（流れに差し込む。編成の「出撃準備へ戻る」で、ここへ戻る）。
## - 「話の一覧へ戻る」（右クリック・Esc でも）で &"back"（流れは捨てる）。
##
## ここは、場面の入口（_ready、戻る）だけ。役割ごとのファイル（game/sortie_screen/sortie_*.gd）:
## 読み込み・調整値・部品の変数と部品を作る道具は sortie_base、部隊の選択と操作は sortie_choice、枠の組み立ては sortie_layout。
## ファイルは sortie_base.gd からこの順に継いで積み重なり、このファイルが最後（前のファイルは、後のファイルの関数を呼べない）。


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	var given: Variant = context.run_data()
	if given == null:
		given = {"episode": Story.military().episodes[0], "battle": Story.first_battle(Story.military().episodes[0])}
	episode = given["episode"]
	battle_source = given["battle"]
	add_child(Backdrop.new(episode.map.make_board(), episode.look))
	var layer := CanvasLayer.new()
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(Palette.SHADE, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 縦長・横長の画面では、枠を広げすぎず、真ん中にまとめる（中身の無い枠が伸びるだけになるため。docs/screen-size.md）。
	ScreenSize.cap(root, MAX_SIZE, Vector4(40.0, MARGIN_Y, 40.0, MARGIN_Y))
	root.add_theme_constant_override("separation", 6)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_root = root
	_layer = layer
	_build_header(root)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 28)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)
	_build_map_panel(body)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_WIDTH, 0.0)
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	_build_goal_panel(right)
	_build_enemy_panel(right)
	_build_troops_panel(right)
	_build_footer(root)

	var kept_placement: Array = battle_source.placement.duplicate()
	_build_options()
	if is_squad_fixed():
		choose(FIXED_ID)
	else:
		var remembered: String = context.story.squad_id
		choose(remembered if _option_buttons.has(remembered) and not (_option_buttons[remembered] as Button).disabled else DEFAULT_ID)
	# 決着の画面の「部隊変更」で戻ってきたときは、前に決めた初期位置を残す（同じ数の部隊なら）。
	if not kept_placement.is_empty() and kept_placement.size() == chosen_deck().entries.size() and not _deploy.read_only:
		battle_source.placement.assign(kept_placement)
		_refresh_deploy(chosen_deck())


func resume_label() -> String:
	return Text.t("sortie.back")


## 右クリックと Esc は 1 つ戻る（話の一覧へ）。重なる画面（システムメニュー）が開いている間は、そちらが受ける。
func _input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	if CardKeys.is_back(event):
		get_viewport().set_input_as_handled()
		context.play_sound(&"ui_back")
		if not _deploy.cancel():  # 初期位置で駒を選んでいれば、まず選ぶのをやめる
			press_back()
