class_name FieldEffect
extends RefCounted
## 盤のマスに一定の間だけ置かれる効果 1 つ（盾、煙幕、聖域、結び目）。docs/field-effects.md。
##
## 地形とも環境オブジェクト（MapObject）とも別の層で、置いても地形とオブジェクトは変わらない。
## どこに何があるかは Board が持つ（Board.field_effects）。効果の計算と、置く・消す・期間を進めるのは FieldEffects。
##
## - 盾（BARRICADE）: 1 マス。入れない。射線を遮る。耐久力（durability）が 0 になると消える。期間は無い
## - 煙幕（SMOKE）: 3 x 3。入れる。持ち主の駒への、離れたところからの攻撃を無効にする。残りのターン数（turns_left）で消える
## - 聖域（SANCTUARY）: 3 x 3。入れる。持ち主のフェーズの始めに、持ち主の駒を回復する。残りのターン数で消える

enum Type {
	BARRICADE,  ## 盾
	SMOKE,  ## 煙幕
	SANCTUARY,  ## 聖域
	KNOT,  ## 結び目（倒れたほつれが残す。Monsters）
}

## 盤の中で効果を指す番号。Board が振る（1 から）。
var id: int
var type: Type
## 効果のあるマス（上の行から、左の列から）。盾と結び目は 1 マス、煙幕と聖域は中心の周りの 3 x 3 のうち盤の中のもの。
var cells: Array[Vector2i] = []
## 中心のマス（盾は、そのマス）。
var center: Vector2i
## 持ち主の陣営（置いた駒の陣営）。プレイヤーだけ。
var side: Unit.Side
## 残りのターン数。煙幕と聖域と結び目が使う（盾では 0 のまま）。持ち主のフェーズの始めに 1 減り、0 で消える（結び目は立ち直る）。
var turns_left := 0
## 耐久力。盾だけが使う（煙幕と聖域では 0 のまま）。攻撃されると減り、0 で消える。
var durability := 0


func _init(effect_type: Type, owner: Unit.Side, at: Vector2i, effect_cells: Array[Vector2i]) -> void:
	type = effect_type
	side = owner
	center = at
	cells = effect_cells.duplicate()


## 同じ状態の効果を作る（Board.copy() が使う）。
func copy() -> FieldEffect:
	var result := FieldEffect.new(type, side, center, cells)
	StateCopy.copy_fields(self, result)
	return result


## 駒がそのマスに入れるか（通り抜けも、止まるのも）。
func is_walkable() -> bool:
	return type != Type.BARRICADE


## 攻撃の射線を遮るか。
func blocks_line_of_fire() -> bool:
	return type == Type.BARRICADE


## 期間で消える効果か（煙幕と聖域と結び目）。
func is_timed() -> bool:
	return type != Type.BARRICADE
