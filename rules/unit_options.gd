class_name UnitOptions
extends RefCounted
## 1 体の駒が、いま選べること。Battle.options(駒の番号) が返す。状態は変えない。
##
## ここに載るものは、Battle.can_apply() が受け付ける行動と一致する（載っていない行動は断られる）。
## 行動できない駒（相手の番、行動済み、ほかの駒が行動の途中、決着のあと、いない駒）では、すべて空になる。
## 進化先を選ぶのを待っている駒がいる間は、その駒の evolutions だけが載り、ほかはすべて空になる。
## 作った時点の写しなので、状態が進んだら作り直す。駒は番号で指すので、複製した Battle にもそのまま使える。
## 画面（選べるマスを塗る）と CPU（選べる行動を並べる）の両方が使う。

var unit_id: int
## 通常の移動で届くマス -> そこまでに使う移動力。いまのマス（動かない移動。0）も含む。もう動いた駒では空。
var move_cells: Dictionary[Vector2i, int] = {}
## 巡航でだけ届くマス -> そこまでに使う移動力。move_cells とは重ならない。
var cruise_cells: Dictionary[Vector2i, int] = {}
## いまの位置から攻撃できる駒の番号（上の行から、左の列から）。巡航で動いた駒と回復役では空。
var attack_target_ids: Array[int] = []
## いまの位置から攻撃できる起爆樽のマス（同じ並び）。
var barrel_cells: Array[Vector2i] = []
## いまの位置から攻撃できる盾のマス（同じ並び）。相手の盾だけ。
var barricade_cells: Array[Vector2i] = []
## いまの位置から回復できる味方の番号（同じ並び）。回復役だけ。巡航で動いた駒では空。
var heal_target_ids: Array[int] = []
## 選べる進化先（A、B の順）。進化先を選ぶのを待っている駒だけ。
var evolutions: Array[Evolution.Id] = []
## 待機できるか。
var can_wait := false
## 移動を取り消せるか。
var can_undo := false


## 駒 unit_id がいま選べること。
static func of(battle: Battle, for_unit_id: int) -> UnitOptions:
	var options := UnitOptions.new()
	options.unit_id = for_unit_id
	var unit := battle.unit_by_id(for_unit_id)
	if battle.is_over():
		return options
	if unit != null and unit == battle.evolving_unit():
		options.evolutions = Evolution.options_for(unit.kind)
		return options
	if not battle.can_act(unit):
		return options
	options.can_wait = true
	options.can_undo = unit.has_moved
	if not unit.has_moved:
		# 巡航の範囲を 1 回だけ探す。通常の移動で届くのは、そのうち移動力が通常の範囲に収まるマス。
		var stops := Movement.search(battle, unit, true).stops()
		var normal := Movement.budget(unit, false)
		for cell: Vector2i in stops:
			if stops[cell] <= normal:
				options.move_cells[cell] = stops[cell]
			else:
				options.cruise_cells[cell] = stops[cell]
	if not unit.cruised:
		for target in Combat.targets(battle, unit):
			options.attack_target_ids.append(target.id)
		options.barrel_cells = MapObject.barrel_targets(battle, unit)
		options.barricade_cells = FieldEffects.barricade_targets(battle, unit)
		for target in Healing.targets(battle, unit):
			options.heal_target_ids.append(target.id)
	return options


## 何も選べないか。
func is_empty() -> bool:
	return not can_wait and evolutions.is_empty()


## cell へ動けるか（通常の移動か、巡航で）。
func can_move_to(cell: Vector2i) -> bool:
	return move_cells.has(cell) or cruise_cells.has(cell)


## 選べる行動を、そのまま Battle.apply() に渡せる形で並べる。
## 並びは、進化、移動（通常、巡航）、攻撃、樽の攻撃、盾の攻撃、回復、待機、取り消し。毎回同じ並びになる。
## 通常の移動で届くマスへの巡航は並べない（受け付けはするが、攻撃を諦めるだけで得が無い）。
func actions() -> Array[BattleAction]:
	var result: Array[BattleAction] = []
	for evolution in evolutions:
		result.append(EvolveAction.new(unit_id, evolution))
	for cell in move_cells:
		result.append(MoveAction.new(unit_id, cell, false))
	for cell in cruise_cells:
		result.append(MoveAction.new(unit_id, cell, true))
	for target_id in attack_target_ids:
		result.append(AttackAction.new(unit_id, target_id))
	for cell in barrel_cells:
		result.append(AttackBarrelAction.new(unit_id, cell))
	for cell in barricade_cells:
		result.append(AttackBarricadeAction.new(unit_id, cell))
	for target_id in heal_target_ids:
		result.append(HealAction.new(unit_id, target_id))
	if can_wait:
		result.append(WaitAction.new(unit_id))
	if can_undo:
		result.append(UndoMoveAction.new(unit_id))
	return result
