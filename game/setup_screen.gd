extends Node
## 対戦の設定の場面。ステージ・相手・手番・軍を選ぶ（match_setup_panel.gd。対戦の途中で開く設定画面と同じもの）。
## 背景は対戦と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。
##
## 「対戦を始める」で選んだものを context.match_choice に入れて &"start"。「ステージ選択へ戻る」（右クリック・Esc でも）で &"back"。
## ステージはステージ選択の場面で選んで来る（ここのステージの行で選び直してもよい）。

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
	_panel.open(context.match_choice, true, false, "ステージ選択へ戻る", false)


## 対戦の設定のパネル（検査とスクリーンショットの道具用）。
func setup_panel() -> MatchSetupPanel:
	return _panel


func resume_label() -> String:
	return "対戦の設定へ戻る"


func _on_start(choice: RefCounted) -> void:
	context.match_choice = choice
	finished.emit(&"start")
