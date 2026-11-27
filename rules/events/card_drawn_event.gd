class_name CardDrawnEvent
extends BattleEvent
## プレイヤーが、自分の番の始めに札を 1 枚引いた（docs/hand-cards.md）。hand_size は引いたあとの手札の枚数、pile_left は山の残り。

var side: Unit.Side
var card: Card.Id
var hand_size: int
var pile_left: int


func _init(drawer: Unit.Side, drawn: Card.Id, cards_in_hand: int, cards_in_pile: int) -> void:
	side = drawer
	card = drawn
	hand_size = cards_in_hand
	pile_left = cards_in_pile
