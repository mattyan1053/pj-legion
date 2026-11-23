class_name Monsters
extends RefCounted
## 魔物（UnitKind.is_monster）だけが持つ決まり: 種類そのものの特性と、倒れたときに起きること。docs/monsters.md。
##
## - 種類の特性（kind_traits）: 大蝙蝠は支配領域で止まらず、森を平地と同じに飛ぶ。糸針は動けない。
##   骸骨旗手とほつれは、倒れたときのことを特性として持つ（情報の札に、特性として出る）
## - 骸骨旗手（Trait.RALLY_ON_FALL）が倒れると、周り RALLY_RADIUS マスの味方に奮起（Status.Type.RESOLVE）が付く（on_defeated）
## - ほつれ（Trait.KNOT_ON_FALL）が倒れると、そのマスに結び目（FieldEffect.Type.KNOT）が残る（on_defeated）。
##   持ち主のフェーズの始めに（start_phase）、ほかの陣営の駒が乗っていれば、ほどける。乗っていなければ残りのターン数が 1 減り、
##   0 になったら、そこにほつれが立ち直る（行動済みでなく、そのフェーズから動く）。持ち主の駒が乗っていれば、空くまで待つ
##
## どれも Battle.remove_unit と EndPhaseAction の中で起きるので、予測（Forecast）・CPU の先読み・脅威範囲（Threat）は、
## 複製の上で同じ処理を走らせて知る。

# ---- 調整値（docs/monsters.md の「調整値」） ----

## 骸骨旗手が倒れたとき、奮起が付く広さ（マンハッタン距離）。
const RALLY_RADIUS := 2
## 奮起（Status.Type.RESOLVE）の攻撃力（回復役は回復量）の上がり幅。
const RESOLVE_POWER := 4
## 結び目が立ち直るまでの、持ち主のフェーズの数（残したときの残りのターン数）。
const KNOT_TURNS := 2

## 種類 -> その種類が生まれつき持つ特性。
const _KIND_TRAITS := {
	UnitKind.Id.SKELETON_BANNER: [Evolution.Trait.RALLY_ON_FALL],
	UnitKind.Id.BAT: [Evolution.Trait.IGNORES_ZOC, Evolution.Trait.FOREST_WALK],
	UnitKind.Id.FRAY: [Evolution.Trait.KNOT_ON_FALL],
	UnitKind.Id.NEEDLE: [Evolution.Trait.ROOTED],
}
const _NONE: Array = []


## kind の種類そのものが持つ特性（進化先や持ち物のものは含まない）。無ければ空。
static func kind_traits(kind: UnitKind.Id) -> Array:
	return _KIND_TRAITS.get(kind, _NONE)


## 駒 fallen が倒れたあと（Battle.remove_unit が、盤から取り除いたあとに呼ぶ）に起きること。
## - 骸骨旗手: RallyEvent と、奮起の付いた味方ごとの StatusAppliedEvent（味方がいなければ何も起きない）
## - ほつれ: KnotPlacedEvent（そのマスに、もう結び目があれば残さない）
static func on_defeated(battle: Battle, fallen: Unit) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var traits := kind_traits(fallen.kind)
	if traits.has(Evolution.Trait.RALLY_ON_FALL):
		events.append_array(_rally(battle, fallen))
	if traits.has(Evolution.Trait.KNOT_ON_FALL):
		events.append_array(_tie_knot(battle, fallen))
	return events


## 骸骨旗手 fallen が倒れたとき、奮起が付く味方（上の行から、左の列から）。fallen はもう盤にいなくてよい。
static func rallied(battle: Battle, fallen: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in battle.units:
		if unit != fallen and unit.side == fallen.side and Combat.distance(unit.cell, fallen.cell) <= RALLY_RADIUS:
			result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool: return Board.in_reading_order(a.cell, b.cell))
	return result


static func _rally(battle: Battle, fallen: Unit) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var friends := rallied(battle, fallen)
	if friends.is_empty():
		return events
	events.append(RallyEvent.new(fallen, friends))
	# 誓いの果てと同じ長さ: 次の自分のフェーズの終わりまで（自分のフェーズの途中なら、このフェーズの終わりまで）。
	var turns := 1 if battle.phase == fallen.side else 2
	for friend in friends:
		events.append(Statuses.add(friend, Status.Type.RESOLVE, turns))
	return events


static func _tie_knot(battle: Battle, fallen: Unit) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if fallen.side == Unit.Side.NEUTRAL or knot_at(battle, fallen.cell) != null:
		return events
	var knot := FieldEffect.new(FieldEffect.Type.KNOT, fallen.side, fallen.cell, [fallen.cell])
	knot.turns_left = KNOT_TURNS
	battle.board.add_field_effect(knot)
	events.append(KnotPlacedEvent.new(knot, fallen.kind))
	return events


## cell にある結び目。無ければ null。
static func knot_at(battle: Battle, cell: Vector2i) -> FieldEffect:
	for effect in battle.board.field_effects:
		if effect.type == FieldEffect.Type.KNOT and effect.center == cell:
			return effect
	return null


## 結び目 knot が、いま持ち主のフェーズが始まったら、ほどけるか（ほかの陣営の駒が乗っている）。
static func is_held_down(battle: Battle, knot: FieldEffect) -> bool:
	var standing := battle.unit_at(knot.center)
	return standing != null and standing.side != knot.side


## side のフェーズの始めに、side の結び目に起きること（FieldEffects.start_phase が、期間を進める前に呼ぶ）。
## 結び目ごとに（番号の順に）:
## 1. ほかの陣営の駒が乗っていれば、ほどける（FieldEffectRemovedEvent。UNTIED）
## 2. そうでなければ残りのターン数が 1 減る（FieldEffectTickedEvent）。0 になったら、空いていれば消えて（REFORMED）、
##    ほつれが立ち直る（UnitSpawnedEvent。HP は満ちて、このフェーズから動ける）。持ち主の駒が乗っていれば 1 のまま待つ
static func start_phase(battle: Battle, side: Unit.Side) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for knot: FieldEffect in battle.board.field_effects.duplicate():
		if knot.type != FieldEffect.Type.KNOT or knot.side != side:
			continue
		if is_held_down(battle, knot):
			battle.board.remove_field_effect(knot)
			events.append(FieldEffectRemovedEvent.new(knot, FieldEffectRemovedEvent.Reason.UNTIED))
			continue
		knot.turns_left = maxi(1, knot.turns_left - 1) if battle.unit_at(knot.center) != null else knot.turns_left - 1
		if knot.turns_left > 0:
			events.append(FieldEffectTickedEvent.new(knot.id, knot.turns_left))
			continue
		battle.board.remove_field_effect(knot)
		events.append(FieldEffectRemovedEvent.new(knot, FieldEffectRemovedEvent.Reason.REFORMED))
		var reformed := battle.add_unit(UnitKind.Id.FRAY, side, knot.center)
		if reformed != null:
			events.append(UnitSpawnedEvent.new(reformed))
	return events
