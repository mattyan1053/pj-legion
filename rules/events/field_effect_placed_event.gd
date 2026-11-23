@abstract
class_name FieldEffectPlacedEvent
extends BattleEvent
## 盤の上に効果が置かれた（docs/field-effects.md）。見た目は、この値だけで効果を描ける。
##
## 実際に出るのは、種類ごとの子のクラス。種類に固有の値は、子のクラスだけが持つ。
##
## - BarricadePlacedEvent: 盾（durability）
## - AreaEffectPlacedEvent: 煙幕・聖域（turns_left）
## - KnotPlacedEvent: 結び目（turns_left、立ち直る種類）

var effect_id: int
var type: FieldEffect.Type
var side: Unit.Side
## 効果のあるマス（上の行から、左の列から）と、中心のマス。
var cells: Array[Vector2i]
var center: Vector2i


func _fill(effect: FieldEffect) -> void:
	effect_id = effect.id
	type = effect.type
	side = effect.side
	cells = effect.cells.duplicate()
	center = effect.center
