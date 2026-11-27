class_name PlayCardAction
extends BattleAction
## いまのフェーズのプレイヤーが、手札の札を 1 枚使う（試しの決まり。docs/hand-cards.md）。
##
## 駒の行動ではない（使っても、どの駒の行動も使わない）。1 つの番に 1 枚。行動の途中の駒がいる間は使えない。
## target は相手の駒のマス（相手を選ばない札では使わない）、spot は駒を動かす札で、動かす先のマス。

var card: Card.Id
var target: Vector2i
var spot: Vector2i


func _init(played: Card.Id, at := Board.NO_CELL, to := Board.NO_CELL) -> void:
	card = played
	target = at
	spot = to


func is_valid(battle: Battle) -> bool:
	return Hand.can_play_at(battle, card, target, spot)


func execute(battle: Battle) -> Array[BattleEvent]:
	return Hand.play(battle, card, target, spot)
