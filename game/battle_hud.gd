extends "res://game/battle_hud/hud_hand.gd"
## 対戦の画面の文字とボタン（ターン、番、駒とマスの情報、駒のそばのメニュー、決着）。
##
## 何を出すかは呼ぶ側が決める。ここはルールを持たず、押されたことを signal で知らせるだけ。
## 駒に属する操作（攻撃、スキル、待機…）は駒のそばのメニューに、駒に属さない操作（ターン終了、必殺技、相手の切り替え）は
## 画面の決まった場所に置く。どれもクリックだけで選べる。
##
## ここは、組み立ての順と、毎コマの明滅だけ。部品は帯・枠ごとのファイル（game/battle_hud/hud_*.gd）にある:
## 上の帯（hud_top_bar）、下の帯（hud_bottom_bar）、重ねて出すもの（hud_overlays）、駒のそばのメニューと予測（hud_menu）、
## 左下の駒とマスの情報（hud_info_panel）、手札の帯（hud_hand）。知らせ・調整値・部品の変数と、部品を作る道具は hud_base。
## ファイルは hud_base.gd からこの順に継いで積み重なり、このファイルが最後（前のファイルは、後のファイルの関数を呼べない）。


func setup(team_colors: Array[Color]) -> void:
	_team_colors = team_colors
	add_child(UiTheme.vignette(BOARD_VIGNETTE))  # 盤の四隅を、ごく薄く沈める（帯や枠の下）
	_build_top_bar()
	_build_info_panel()
	_build_bottom()
	_build_hand()
	_build_flash()
	_build_banner()
	_build_notice()
	_build_menu()
	_build_forecast()
	_build_minimap()
	_result = ResultScreen.new()
	_result.team_colors = team_colors
	add_child(_result)
	_result.restart_pressed.connect(restart_pressed.emit)
	_result.setup_pressed.connect(setup_pressed.emit)
	_result.title_pressed.connect(title_pressed.emit)
	_build_evolution()


## ゲージが READY のあいだ、上の帯のゲージと、押せる必殺技のボタンを、金色にゆっくり明滅させる。
## 時計は実時間で測る（CPU の番の速さや、メニューで時間が止まっているのに依らない）。
func _process(_delta: float) -> void:
	var phase := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / PULSE_PERIOD)
	var tint := Color.WHITE.lerp(COLOR_PULSE, phase)
	for player in _ult_labels.size():
		var shade := tint if _ult_labels[player].text == "READY" else Color.WHITE
		_ult_bars[player].self_modulate = shade
		_ult_labels[player].self_modulate = shade
	if _ult_button != null:
		_ult_button.self_modulate = tint if not _ult_button.disabled else Color.WHITE
	_update_menu_alpha()


## マウスがボタンやパネルの上にあるか（盤面のクリックと取り違えないため）。
func is_mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null
