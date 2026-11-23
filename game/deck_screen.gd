extends "res://game/deck_screen/deck_list_actions.gd"
## 部隊編成の場面（docs/deck-screen.md）。取っておいた部隊の一覧と、1 つの部隊を組む画面の 2 つを、切り替えて出す。
## 背景は対戦と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。取っておく先は context.decks（deck_library.gd）。
##
## - 一覧: 部隊を選び（中身は駒の札で出す）、編集・複製・名前変更・削除（確かめる）。「新しい部隊」で、軍を選んでから空の部隊を組む。
## - 組む画面: 雇える駒の札を押して部隊に足し、部隊の駒を選んで、その駒の札と持ち物の欄を出す。並べ替えで、置かれるところが変わる。
##   予算・駒の数・出せない理由はいつも出す。出せない部隊は「編成完了」できない。
## - 右クリックと Esc は「戻す」: 確かめ・名前の入力 → 駒の選択 → 組む画面（変えたところがあれば確かめる）・軍の選択 → 一覧 → 戻り先。
## - 一覧は「対戦用」か「ストーリー用」の 1 つの決まりの部隊だけを出す（見出しの横に決まりの名前。切り替えのボタンは置かない）。
## 一覧と「新しい部隊」は、その決まりの部隊だけ（混ざらない）。組む画面の決まり（雇える駒、予算、数の上限）も同じ
## （rules。対戦の決まりか、いまの進み具合のストーリーの決まり）。流れの外で置いたとき（道具）は、set_mode で替える。
## - 流れ（run.gd）の中で置かれたら（出撃準備・対戦設定の「部隊編成」）、渡された決まりの一覧を出し、
##   いちばん外の「戻る」は Run.NEXT（流れの次の場面 = 出撃準備・対戦設定へ戻る）。寄り道の間に取っておいた部隊を、戻った先で選ぶ。
##
## ここは、場面の入口（_ready、戻る、流れの中か）だけ。画面ごとのファイル（game/deck_screen/deck_*.gd）:
## 駒の札と持ち物（deck_unit_card）、一覧の表示（deck_list）、組む画面（deck_editor）、一覧の組み立てと操作・軍の選択（deck_list_actions）。
## 読み込み・調整値・部品の変数と部品を作る道具、確かめと名前の入力の窓は deck_base。ファイルは deck_base.gd からこの順に継いで積み重なり、
## このファイルが最後（前のファイルは、後のファイルの関数を呼べない）。


func _ready() -> void:
	if context == null:
		context = AppContext.new()
	_library = context.decks
	add_child(Backdrop.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	_layer = layer
	var shade := ColorRect.new()
	shade.color = Color(Palette.SHADE, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	_list_view = _build_list()
	layer.add_child(_list_view)
	_army_view = _build_army_picker()
	layer.add_child(_army_view)
	_edit_view = _build_editor()
	layer.add_child(_edit_view)
	get_viewport().size_changed.connect(_fit_equip)  # 窓を縮めたとき、持ち物の欄の高さを決め直す
	_dialog = _build_dialog()
	layer.add_child(_dialog)
	_library.changed.connect(_refresh_list)
	var given: Variant = context.run_data()
	if given is Dictionary:
		_detour = given
		_back_button.text = Text.t(_detour.get("back_label", "common.back"))
	set_mode(_detour.get("rules", DeckRules.VERSUS))
	if not _detour.is_empty():
		# 寄り道のもとで選んでいる部隊を、一覧で選んでおく（ストーリーは出撃準備、対戦は対戦設定の、その側の部隊）。
		var current: String = context.story.squad_id
		if _detour.get("rules") == DeckRules.VERSUS:
			current = context.match_choice.deck_ids[_detour.get("side", Unit.Side.PLAYER1)]
		if _library.find(current) != null and _library.find(current).deck.rules.id == rules.id:
			select_saved(current)


# ==== 場面の決まり ====


func resume_label() -> String:
	return Text.t("deck.resume")


## 組んでいる途中で、取っておいていない変更があるか（タイトルへ戻る・ゲームを終える前に確かめる）。
func in_progress() -> bool:
	return is_editing() and _dirty


## 抜ける前の確かめに書く、失われるもの（app.gd の leave_confirm）。
func losing_note() -> String:
	return Text.t("deck.losing")


## 右クリックと Esc は「戻す」。重なる画面（システムメニュー）が開いている間は、そちらが受ける。
func _input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	if CardKeys.is_back(event):
		get_viewport().set_input_as_handled()
		press_back()


## 1 つ戻す。確かめ・名前の入力 → 駒の選択 → 組む画面・軍の選択 → 一覧 → 戻り先 の順。
func press_back() -> void:
	if _dialog.visible:
		close_dialog()
	elif is_editing() and _binding != -1:
		_binding = -1
		_refresh_editor()
	elif is_editing() and _selected != -1:
		select_entry(-1)
	elif is_editing():
		leave_editor()
	elif is_choosing_army():
		show_list()
	else:
		leave()


## 流れの中（出撃準備からの寄り道）で置かれたか。
func is_detour() -> bool:
	return not _detour.is_empty()


## 一覧の「戻る」のボタンの文字（検査用）。
func back_label() -> String:
	return _back_button.text


# ==== 一覧 ====
