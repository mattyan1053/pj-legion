extends Node
## 対戦の設定の場面。ステージ・相手・手番・軍を選ぶ（match_setup_panel.gd。対戦の途中で開く設定画面と同じもの）。
## 背景は対戦と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。
##
## 「対戦を始める」で選んだものを context.match_choice に入れ、その選択の流れ（match_choice.gd の run。対戦の場面 1 つ）を始める。「ステージ選択へ戻る」（右クリック・Esc でも）で &"back"。
## ステージはステージ選択の場面で選んで来る。ここでは出すだけで、「ステージを選び直す」で &"back"（選んだものは残す）。
## 「部隊を編成する」は、部隊の編成へ寄り道する流れ（編成 → 対戦の設定）を始める。寄り道で取っておいた部隊が選ばれて戻る。

const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const MatchSetupPanel := preload("res://game/match_setup_panel.gd")
const BattleScreen := preload("res://game/battle_screen.gd")

signal finished(outcome: StringName)

var context: AppContext
var _panel: MatchSetupPanel


func _ready() -> void:
	add_child(Backdrop.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	_panel = MatchSetupPanel.new()
	layer.add_child(_panel)
	_panel.setup(BattleScreen.TEAM_COLORS, context.decks, context.overlays)
	_panel.start_pressed.connect(_on_start)
	_panel.cancelled.connect(func() -> void: finished.emit(&"back"))
	_panel.stage_pressed.connect(func(choice: RefCounted) -> void:
		context.match_choice = choice
		finished.emit(&"back"))
	_panel.decks_pressed.connect(_on_edit_decks)
	_panel.open(context.match_choice, true, false, "ステージ選択へ戻る", false)


## 対戦の設定のパネル（検査とスクリーンショットの道具用）。
func setup_panel() -> MatchSetupPanel:
	return _panel


func resume_label() -> String:
	return "対戦の設定へ戻る"


func _on_start(choice: RefCounted) -> void:
	context.match_choice = choice
	context.start_run(choice.run())


## 「部隊を編成する」: いまの選択を覚えて、部隊の編成（対戦用。side の部隊を組む）→ 対戦の設定 の流れを始める。
func _on_edit_decks(choice: RefCounted, side: Unit.Side) -> void:
	context.match_choice = choice
	context.start_run(choice.deck_run(side))
