class_name FieldEffects
extends RefCounted
## 盤の上の効果（盾、煙幕、聖域。FieldEffect）を置く・消す・期間を進める処理と、効果の計算。docs/field-effects.md。
##
## どこに何があるかは Board が持つ（Board.field_effects）。ここの問い合わせは状態を変えない。
## 状態を変えるのは place_*（スキルの効果が呼ぶ。rules/skills/）、start_phase（EndPhaseAction が呼ぶ）、
## 盾への攻撃（AttackBarricadeAction）と、駒への攻撃（Combat.strike。煙幕が無効にする）。
##
## - 盾: 入れない（Board.is_walkable）。間に盾がある攻撃は届かない（Combat.reaches）。攻撃されると攻撃力のぶん耐久力が減る
## - 煙幕: 持ち主の駒への、距離 2 以上からの攻撃のダメージを 0 にする（smoke_covering）
## - 聖域: 持ち主のフェーズの始めに、中にいる持ち主の駒の HP を回復する（sanctuary_targets）
## - 煙幕と聖域の残りのターン数は、持ち主のフェーズの始めに（聖域の回復のあとで）1 減り、0 になったら消える

# ---- 調整値（docs/field-effects.md の「調整値」） ----

## 盾の耐久力。
const BARRICADE_DURABILITY := 20
## 煙幕と聖域の残りのターン数（置いたときの値）。
const SMOKE_TURNS := 2
const SANCTUARY_TURNS := 3
## 聖域の回復量（持ち主のフェーズの始めに 1 回）。
const SANCTUARY_HEAL := 5
## 煙幕と聖域の広がり（中心からのチェビシェフ距離。1 なら 3 x 3）。
const AREA_RADIUS := 1


# ---- 置く（スキルの行動が呼ぶ入口） ----


## cell に盾を置けるか。盤の中の入れるマスで、駒も環境オブジェクトもほかの効果も無く、本陣でも結晶泉でもないこと。
## 誰が・どこまで離れて置けるか（スキルの射程）は、呼ぶ側が決める。
static func can_place_barricade(battle: Battle, cell: Vector2i) -> bool:
	var board := battle.board
	return (
		board.is_walkable(cell)
		and board.object_at(cell) == MapObject.Type.NONE
		and battle.unit_at(cell) == null
		and board.field_effects_at(cell).is_empty()
		and board.hq_owner(cell) < 0
		and not board.font_cells.has(cell)
	)


## side の盾を cell に置く。置けなければ（can_place_barricade が偽）何もせずに空を返す。
static func place_barricade(battle: Battle, side: Unit.Side, cell: Vector2i) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if side == Unit.Side.NEUTRAL or not can_place_barricade(battle, cell):
		return events
	var effect := FieldEffect.new(FieldEffect.Type.BARRICADE, side, cell, [cell])
	effect.durability = BARRICADE_DURABILITY
	battle.board.add_field_effect(effect)
	events.append(BarricadePlacedEvent.new(effect))
	return events


## center を中心に煙幕・聖域を置けるか（中心が盤の中なら置ける。壁や駒の上にも広がる）。
static func can_place_area(battle: Battle, center: Vector2i) -> bool:
	return battle.board.in_bounds(center)


## center を中心とする煙幕・聖域のマス（3 x 3 のうち盤の中のもの。上の行から、左の列から）。
static func area_cells(board: Board, center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-AREA_RADIUS, AREA_RADIUS + 1):
		for dx in range(-AREA_RADIUS, AREA_RADIUS + 1):
			var cell := center + Vector2i(dx, dy)
			if board.in_bounds(cell):
				result.append(cell)
	return result


## side の煙幕を center を中心に置く。置けなければ空を返す。
static func place_smoke(battle: Battle, side: Unit.Side, center: Vector2i) -> Array[BattleEvent]:
	return _place_area(battle, FieldEffect.Type.SMOKE, side, center, SMOKE_TURNS)


## side の聖域を center を中心に置く。置けなければ空を返す。
static func place_sanctuary(battle: Battle, side: Unit.Side, center: Vector2i) -> Array[BattleEvent]:
	return _place_area(battle, FieldEffect.Type.SANCTUARY, side, center, SANCTUARY_TURNS)


static func _place_area(
	battle: Battle, type: FieldEffect.Type, side: Unit.Side, center: Vector2i, turns: int
) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if side == Unit.Side.NEUTRAL or not can_place_area(battle, center):
		return events
	var effect := FieldEffect.new(type, side, center, area_cells(battle.board, center))
	effect.turns_left = turns
	battle.board.add_field_effect(effect)
	events.append(AreaEffectPlacedEvent.new(effect))
	return events


# ---- 盾への攻撃 ----


## attacker がいまの位置から cell の盾を攻撃できるか。盾の持ち主の駒と回復役は攻撃できない。
## 届くかどうかは駒への攻撃と同じ（射程と、間の盾。Combat.reaches）。
static func can_attack_barricade(battle: Battle, attacker: Unit, cell: Vector2i) -> bool:
	var barricade := battle.board.barricade_at(cell)
	if attacker == null or barricade == null or attacker.side == barricade.side:
		return false
	if UnitKind.role(attacker.kind) == UnitKind.Role.HEALER:
		return false
	return Combat.reaches(battle, attacker.cell, cell, attacker.attack_range())


## いまの位置から攻撃できる盾のマス。上の行から、左の列から。
static func barricade_targets(battle: Battle, attacker: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for effect in battle.board.field_effects:
		if effect.type == FieldEffect.Type.BARRICADE and can_attack_barricade(battle, attacker, effect.center):
			result.append(effect.center)
	result.sort_custom(Board.in_reading_order)
	return result


## attacker の攻撃で、盾の耐久力が減る量（予測にも使う）。攻撃力のぶん。森の軽減は無い（駒ではない）。
static func barricade_damage(attacker: Unit) -> int:
	return attacker.power()


# ---- 煙幕 ----


## from から target を攻撃したときに、そのダメージを 0 にする煙幕。無ければ null。
## 守るのは、煙幕の中にいる、煙幕の持ち主の駒だけ。離れたところ（距離 Combat.RANGED_DISTANCE 以上）からの攻撃だけを防ぐ。
## いくつも重なっていれば、番号のいちばん小さいもの。
static func smoke_covering(battle: Battle, from: Vector2i, target: Unit) -> FieldEffect:
	if target == null or target.side == Unit.Side.NEUTRAL:
		return null
	if Combat.distance(from, target.cell) < Combat.RANGED_DISTANCE:
		return null
	return smoke_of(battle, target)


## unit のいるマスにある、unit の陣営の煙幕。いくつも重なっていれば番号のいちばん小さいもの。無ければ null。
static func smoke_of(battle: Battle, unit: Unit) -> FieldEffect:
	for effect in battle.board.field_effects:
		if effect.type == FieldEffect.Type.SMOKE and effect.side == unit.side and effect.cells.has(unit.cell):
			return effect
	return null


# ---- 聖域 ----


## unit のいるマスにある、unit の陣営の聖域。いくつも重なっていれば番号のいちばん小さいもの。無ければ null。
static func sanctuary_of(battle: Battle, unit: Unit) -> FieldEffect:
	for effect in battle.board.field_effects:
		if effect.type == FieldEffect.Type.SANCTUARY and effect.side == unit.side and effect.cells.has(unit.cell):
			return effect
	return null


## side のフェーズの始めに、聖域で回復する駒（HP が減っているものだけ）。上の行から、左の列から。
## 聖域がいくつ重なっていても、1 体につき 1 回。
static func sanctuary_targets(battle: Battle, side: Unit.Side) -> Array[Unit]:
	var result: Array[Unit] = []
	if side == Unit.Side.NEUTRAL:
		return result
	for unit in battle.units:
		if unit.side == side and sanctuary_heal(unit) > 0 and sanctuary_of(battle, unit) != null:
			result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool: return Board.in_reading_order(a.cell, b.cell))
	return result


## 聖域で unit の HP が実際に増える量。最大 HP を超えるぶんは切り捨てる。
static func sanctuary_heal(unit: Unit) -> int:
	return clampi(unit.max_hp() - unit.hp, 0, SANCTUARY_HEAL)


# ---- フェーズの始め ----


## side のフェーズの始めに起きること（EndPhaseAction が、回復の泉と再生のあとに呼ぶ）。
## 1. side の聖域の中の side の駒が回復する（SanctuaryHealedEvent）
## 2. side の煙幕と聖域の残りのターン数が 1 減る（FieldEffectTickedEvent）。0 になったものは消える（FieldEffectRemovedEvent）
## 中立のフェーズには何も起きない（中立の効果は無い）。
static func start_phase(battle: Battle, side: Unit.Side) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if side == Unit.Side.NEUTRAL:
		return events
	for unit in sanctuary_targets(battle, side):
		var amount := sanctuary_heal(unit)
		unit.hp += amount
		events.append(SanctuaryHealedEvent.new(sanctuary_of(battle, unit).id, unit.id, amount, unit.hp))
	for effect: FieldEffect in battle.board.field_effects.duplicate():
		if effect.side != side or not effect.is_timed():
			continue
		effect.turns_left -= 1
		if effect.turns_left > 0:
			events.append(FieldEffectTickedEvent.new(effect.id, effect.turns_left))
		else:
			battle.board.remove_field_effect(effect)
			events.append(FieldEffectRemovedEvent.new(effect, FieldEffectRemovedEvent.Reason.EXPIRED))
	return events
