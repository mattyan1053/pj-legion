class_name KnotPlacedEvent
extends FieldEffectPlacedEvent
## 倒れたほつれ（魔物）が、そのマスに結び目を残した（docs/monsters.md）。cells は center の 1 マス。
## turns_left は残したときの残りのターン数（持ち主のフェーズの始めに 1 減り、0 で立ち直る）。

var turns_left: int
## 立ち直る駒の種類。
var kind: UnitKind.Id


func _init(effect: FieldEffect, reform_kind: UnitKind.Id) -> void:
	_fill(effect)
	turns_left = effect.turns_left
	kind = reform_kind
