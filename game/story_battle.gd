extends "res://game/battle_source.gd"
## ストーリーの 1 話の対戦（docs/story.md）。対戦の画面に渡すもの（battle_source.gd）。
## 話のデータ（game/episodes/ の 1 ファイル）から、戦いの定義（手で作ったマップ、決め打ちの敵）を持った対戦の設定を作る。
##
## 人はいつもプレイヤー1（先手）で、渡された部隊（story.gd が、いま雇える駒で組む）。敵はプレイヤー2 で、CPU が動かす。
## 選び直せるものは無い（ステージ、相手、対戦の設定のパネル）。やり直しは「同じ盤面でもう一度」と、出撃の準備へ戻る「部隊を選び直す」。
## 人が勝ったら、決着の画面に「次へ」を出し（流れの次の場面、あとの会話へ）、話をクリアしたと書く。
## ここはノードに依存しない（テストから呼べる）。

## 話のデータ（game/episodes/ の 1 ファイル）。
var episode: Script
## 人の部隊。
var human_deck: Deck


func _init(of_episode: Script = null, deck: Deck = null) -> void:
	episode = of_episode
	human_deck = deck


func make_setup(battle_seed: int) -> MatchSetup:
	var scenario := Scenario.on_map(episode.MAP.map(), episode.MAP.TITLE)
	scenario.fix_deck(Unit.Side.PLAYER2, episode.enemy_deck())
	# 初期位置（話のデータの DEPLOY。[プレイヤー1 のマスの列, プレイヤー2 のマスの列]。空の列は、いつもの「本陣の前」）。
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var cells: Array[Vector2i] = []
		cells.assign(episode.DEPLOY[side])
		if not cells.is_empty():
			scenario.set_deploy_cells(side, cells)
	var setup := MatchSetup.new()
	setup.scenario = scenario
	setup.battle_seed = battle_seed
	setup.set_human(Unit.Side.PLAYER1, human_deck)
	setup.controllers[Unit.Side.PLAYER2] = MatchSetup.Controller.CPU  # 部隊は決め打ちなので、CPU の編成は作らない
	return setup


func look() -> StringName:
	return episode.LOOK


func can_continue(won: bool) -> bool:
	return won


func can_choose_squad() -> bool:
	return true


func record_win(context: RefCounted) -> void:
	if context != null and context.story != null:
		context.story.clear(episode.ID)


func copy() -> RefCounted:
	return get_script().new(episode, human_deck)
