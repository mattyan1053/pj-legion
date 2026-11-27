class_name CardPlayedEvent
extends BattleEvent
## プレイヤーが札を使った（docs/hand-cards.md）。効果のイベント（状態が付いた、回復した、など）は、このあとに続く。
## unit_id は相手の駒（相手を選ばない札では 0）、target はそのマス、spot は駒を動かす札の動かす先（無ければ Board.NO_CELL）。
## hand_size は使ったあとの手札の枚数。

var side: Unit.Side
var card: Card.Id
var unit_id: int
var target: Vector2i
var spot: Vector2i
var hand_size: int


func _init(user: Unit.Side, played: Card.Id, on_unit_id: int, at: Vector2i, to: Vector2i, cards_in_hand: int) -> void:
	side = user
	card = played
	unit_id = on_unit_id
	target = at
	spot = to
	hand_size = cards_in_hand
