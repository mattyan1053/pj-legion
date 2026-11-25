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
## - 糸蜘蛛（Trait.BINDS_ON_HIT）の攻撃が当たると、相手に絡み（Status.Type.SNARE）が付き、相手の次の番の終わりまで動けない（bind。Combat.strike が呼ぶ）
## - 糸喰い（Trait.BURSTS_ON_FALL）が倒れると、腹の糸が弾けて、周り 8 マスの駒すべて（陣営を問わない）に BURST_DAMAGE（on_defeated）。
##   弾けて倒れた駒が糸喰いなら、続けて弾ける
## - 殻蟹（Trait.SHELLED）は、離れた所（Combat.RANGED_DISTANCE 以上）からの攻撃では狙えない（Combat.can_attack が shell_turns_away を読む）。
##   爆発・弾ける・スキルのダメージ（狙わずに範囲で当たるもの）は受ける
## - 糸茸（Trait.SPORES）の周り 8 マスにいる敵の攻撃は、ダメージが SPORE_PENALTY 減る（Combat.hit が spore_penalty を読む）。何本いても 1 回
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
## 糸喰いが倒れて弾けたとき、周りの駒が受けるダメージ（固定。起爆樽の爆発と同じく、攻撃力にも地形にもよらない）。
const BURST_DAMAGE := 10
## 糸茸の周り 8 マスにいる敵の、攻撃 1 回のダメージから引く量（何本の糸茸の隣でも 1 回だけ。0 より下にはならない）。
const SPORE_PENALTY := 4

## 種類 -> その種類が生まれつき持つ特性。
const _KIND_TRAITS := {
	UnitKind.Id.SKELETON_BANNER: [Evolution.Trait.RALLY_ON_FALL],
	UnitKind.Id.BAT: [Evolution.Trait.IGNORES_ZOC, Evolution.Trait.FOREST_WALK],
	UnitKind.Id.FRAY: [Evolution.Trait.KNOT_ON_FALL],
	UnitKind.Id.NEEDLE: [Evolution.Trait.ROOTED],
	UnitKind.Id.SPIDER: [Evolution.Trait.BINDS_ON_HIT],
	UnitKind.Id.EATER: [Evolution.Trait.BURSTS_ON_FALL],
	UnitKind.Id.CRAB: [Evolution.Trait.SHELLED],
	UnitKind.Id.SHROOM: [Evolution.Trait.SPORES],
}
const _NONE: Array = []


## kind の種類そのものが持つ特性（進化先や持ち物のものは含まない）。無ければ空。
static func kind_traits(kind: UnitKind.Id) -> Array:
	return _KIND_TRAITS.get(kind, _NONE)


## 駒 fallen が倒れたあと（Battle.remove_unit が、盤から取り除いたあとに呼ぶ）に起きること。
## - 骸骨旗手: RallyEvent と、奮起の付いた味方ごとの StatusAppliedEvent（味方がいなければ何も起きない）
## - ほつれ: KnotPlacedEvent（そのマスに、もう結び目があれば残さない）
## - 糸喰い: BurstEvent と、巻き込んだ駒ごとの ExplosionDamagedEvent、倒れた駒の UnitDefeatedEvent（by は倒した駒。経験値は入らない）
static func on_defeated(battle: Battle, fallen: Unit, by: Unit = null) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var traits := kind_traits(fallen.kind)
	if traits.has(Evolution.Trait.RALLY_ON_FALL):
		events.append_array(_rally(battle, fallen))
	if traits.has(Evolution.Trait.KNOT_ON_FALL):
		events.append_array(_tie_knot(battle, fallen))
	if traits.has(Evolution.Trait.BURSTS_ON_FALL):
		events.append_array(_burst(battle, fallen, by))
	return events


## 駒 attacker の攻撃が target に当たった（煙幕に阻まれず、target が倒れていない）あとに起きること（Combat.strike が呼ぶ）。
## attacker が糸蜘蛛なら、target に絡み（StatusAppliedEvent）。target の次の番の終わりまで動けない。それ以外は何も起きない。
static func after_hit(battle: Battle, attacker: Unit, target: Unit) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if attacker.has_trait(Evolution.Trait.BINDS_ON_HIT) and target.hp > 0:
		# 状態は持ち主のフェーズの始めに 1 減る。相手の番に付ければ 2 で、相手の次の番のあいだ残る。
		events.append(Statuses.add(target, Status.Type.SNARE, 1 if battle.phase == target.side else 2))
	return events


## from のマスから target を狙う攻撃が、殻に逸らされて狙えないか（target が殻蟹で、距離が Combat.RANGED_DISTANCE 以上）。
static func shell_turns_away(from: Vector2i, target: Unit) -> bool:
	return target.has_trait(Evolution.Trait.SHELLED) and Combat.distance(from, target.cell) >= Combat.RANGED_DISTANCE


## attacker の攻撃が、胞子で弱まる量（attacker の周り 8 マスに、attacker の敵の糸茸がいれば SPORE_PENALTY。いなければ 0）。
static func spore_penalty(battle: Battle, attacker: Unit) -> int:
	for unit in battle.units:
		if unit != attacker and unit.has_trait(Evolution.Trait.SPORES) and unit.is_enemy_of(attacker) and _touches(unit.cell, attacker.cell):
			return SPORE_PENALTY
	return 0


## attacker の周り 8 マスにいる、attacker の敵の糸茸（上の行から、左の列から）。予測の見せ方と CPU が読む。
static func spore_sources(battle: Battle, attacker: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in battle.units:
		if unit != attacker and unit.has_trait(Evolution.Trait.SPORES) and unit.is_enemy_of(attacker) and _touches(unit.cell, attacker.cell):
			result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool: return Board.in_reading_order(a.cell, b.cell))
	return result


## a と b が、周り 8 マスの間柄か（同じマスは含まない）。
static func _touches(a: Vector2i, b: Vector2i) -> bool:
	return a != b and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


## 糸喰い fallen が倒れて弾けたとき、巻き込まれる駒（周り 8 マス。陣営を問わない。上の行から、左の列から）。fallen はもう盤にいなくてよい。
## 同じ爆発やスキルで HP が 0 になり、取り除かれるのを待っている駒は含まない（2 度当てない）。
static func burst_victims(battle: Battle, fallen: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in MapObject.blast_victims(battle, fallen.cell):
		if unit != fallen and unit.hp > 0:
			result.append(unit)
	return result


static func _burst(battle: Battle, fallen: Unit, by: Unit) -> Array[BattleEvent]:
	var victims := burst_victims(battle, fallen)
	var victim_ids: Array[int] = []
	for victim in victims:
		victim_ids.append(victim.id)
	var events: Array[BattleEvent] = [
		BurstEvent.new(fallen, by, MapObject.blast_cells(battle.board, fallen.cell), victim_ids)
	]
	# 起爆樽の爆発と同じく、同時に当たる。全員のダメージを先に並べ、倒れた駒はそのあとにまとめて取り除く。
	var after: Array[BattleEvent] = []
	for victim in victims:
		var hit := Hit.resolve(null, victim, BURST_DAMAGE, UnitDamagedEvent.Cause.EXPLOSION)
		after.append_array(hit.apply())
		events.append(ExplosionDamagedEvent.new(fallen.cell, hit))
	events.append_array(after)
	for victim in victims:
		if victim.hp == 0 and battle.units.has(victim):
			events.append_array(battle.remove_unit(victim, by))
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
	# 次の自分のフェーズの終わりまで（自分のフェーズの途中なら、このフェーズの終わりまで）。
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
