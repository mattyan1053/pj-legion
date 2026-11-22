extends Node
## 対戦設定の場面。マップ・相手・手番・軍を選ぶ（match_setup_panel.gd。対戦の途中で開く設定画面と同じもの）。
## 背景は、マップ選択と同じ、裂けた空の下の、選んだマップの景色（title_backdrop.gd の VIEW_VERSUS）。場面の決まりは scene_flow.gd。
##
## 「対戦を始める」で選んだものを context.match_choice に入れ、その選択の流れ（match_choice.gd の run。対戦の場面 1 つ）を始める。
## マップはマップ選択の場面で選んで来る。ここでは出すだけで、選び直すときは「マップ選択へ戻る」（右クリック・Esc でも）で
## &"back"（選んだものは残す）。
## 「部隊編成」は、部隊編成へ寄り道する流れ（編成 → 対戦設定）を始める。寄り道で取っておいた部隊が選ばれて戻る。

const Text := preload("res://game/text.gd")
const AppContext := preload("res://game/app_context.gd")
const TitleBackdrop := preload("res://game/title_backdrop.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const MatchSetupPanel := preload("res://game/match_setup_panel.gd")
const BattleScreen := preload("res://game/battle_screen.gd")

## 背景の景色の盤の種（マップ選択と同じ景色にする）。
const BACKDROP_SEED := 7

signal finished(outcome: StringName)

var context: AppContext
var _panel: MatchSetupPanel
var _backdrop: TitleBackdrop


func _ready() -> void:
	# 背景は、マップ選択と同じ: 裂けた空の下の、選んだマップの景色。
	var field: StringName = context.match_choice.field if VersusFields.has(context.match_choice.field) else VersusFields.DEFAULT
	_backdrop = TitleBackdrop.new(TitleBackdrop.VIEW_VERSUS, VersusFields.card_board(field, BACKDROP_SEED), VersusFields.look_of(field))
	add_child(_backdrop)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(UiTheme.vignette(0.5))  # 板が画面のほとんどを覆うので、四隅だけ沈める（板の左右に、空と景色が見える）
	_panel = MatchSetupPanel.new()
	layer.add_child(_panel)
	_panel.setup(BattleScreen.TEAM_COLORS, context.decks, context.overlays)
	_panel.start_pressed.connect(_on_start)
	_panel.cancelled.connect(func() -> void:
		context.match_choice = _panel.current_choice().copy()
		finished.emit(&"back"))
	_panel.decks_pressed.connect(_on_edit_decks)
	_panel.open(context.match_choice, true, false, Text.t("map_select.resume"), false)


## 対戦設定のパネル（検査とスクリーンショットの道具用）。
func setup_panel() -> MatchSetupPanel:
	return _panel


## 背景が見せている景色の見た目の名前（検査用）。
func backdrop_look() -> StringName:
	return _backdrop.shown_look()


func resume_label() -> String:
	return Text.t("setup.back")


func _on_start(choice: RefCounted) -> void:
	context.match_choice = choice
	context.start_run(choice.run())


## 「部隊編成」: いまの選択を覚えて、部隊編成（対戦用。side の部隊を組む）→ 対戦設定 の流れを始める。
func _on_edit_decks(choice: RefCounted, side: Unit.Side) -> void:
	context.match_choice = choice
	context.start_run(choice.deck_run(side))
