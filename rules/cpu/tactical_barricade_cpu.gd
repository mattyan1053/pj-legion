extends CpuSkillEstimate
class_name CpuTacticalBarricade
## CPU が、戦術バリケード（盾）を使う手を見積もる（スキルは rules/skills/tactical_barricade_skill.gd）。見積もり方は docs/skills/ のこのスキルの文書の「CPU」。
## 共通の決まり（試し方、比べ方）は cpu_skill_estimate.gd と docs/cpu-ai.md。

## 置いたあとの盤面で危険を数え直し、味方が受けうるダメージの減るぶんの価値の何倍を見込むか
## （敵は回り込める・盾を壊せるので、1 より小さい）。味方の離れた攻撃を遮るぶんは、同じ倍率で引く。
const COVER_RATE := 0.75
## 1 回に試す置き場所の数の上限（危険を数え直すので、1 か所ごとに時間がかかる）。
const TRIES := 6


## 盾を置く価値のありそうなマス。危険のある味方がいるときだけ、次の 2 通りを、unit に近い順に TRIES か所まで。
## - 次の相手の番に敵が止まれるマスのうち、通路のようなマス（上下左右の入れるマスが 2 つ以下）。ふさげば、敵が寄れなくなる
## - 離れた敵（射程 2 以上）に狙われている味方の、その敵の側の隣のマス。射線が切れる
func targets(cpu: Variant, unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var found: Dictionary[Vector2i, bool] = {}
	var width: int = cpu._board.size.x
	var endangered := false
	for friend: Unit in cpu._battle.units:
		if friend.side != cpu._me or not cpu._threats.has(friend.cell):
			continue
		endangered = true
		var by: Dictionary = cpu._threats[friend.cell]
		for enemy_id: int in by:
			var enemy: Unit = cpu._battle.unit_by_id(enemy_id)
			if enemy == null or enemy.attack_range() < Combat.RANGED_DISTANCE:
				continue
			var apart := Combat.distance(friend.cell, enemy.cell)
			for direction in Board.DIRECTIONS:
				var near := friend.cell + direction
				if Combat.distance(near, enemy.cell) < apart:
					found[near] = true
	if not endangered:
		return found
	var reach := unit.move_range() + TacticalBarricadeSkill.PLACE_DISTANCE * 2
	for cell: Vector2i in cpu._foe_stops:
		if Combat.distance(cell, unit.cell) > reach:
			continue
		var open := 0
		for direction in Board.DIRECTIONS:
			var near := cell + direction
			if cpu._board.in_bounds(near) and cpu._walkable[near.y * width + near.x] == 1:
				open += 1
		if open <= 2:
			found[cell] = true
	var cells: Array[Vector2i] = []
	cells.assign(found.keys())
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Combat.distance(a, unit.cell)
		var db := Combat.distance(b, unit.cell)
		return da < db or (da == db and Board.in_reading_order(a, b)))
	var wanted: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		if wanted.size() >= TRIES:
			break
		if FieldEffects.can_place_barricade(cpu._battle, cell) or cell == unit.cell:
			wanted[cell] = true
	return wanted


## 盾を置いた価値。置いたあとの盤面（sim）で危険を数え直して、味方が次の相手の番に受けうるダメージ（HP まで）の
## 減るぶんを見込む。通路をふさいで敵が寄れなくなるぶんも、離れた攻撃の射線を切るぶんも、ここに入る。
## 倒されうる味方（将を除く）が倒されなくなるなら、その駒の役割の「倒されうるマス」の重さを足す。
## いま届いている味方の離れた攻撃が、盾で届かなくなるぶんは引く（置く前と置いたあとのルールの答えを比べる）。
func value(cpu: Variant, used: SkillUsedEvent, sim: Battle) -> float:
	cpu._build_threats()
	var after_map: Threat.Map = cpu._threats_of(sim)
	# 比べる相手は「同じマスに立って、盾を置かなかったとき」。動いてから置く手では、動いただけの盤面で数え直す
	# （前衛は、立つだけでも道をふさぐ。そのぶんを盾の手柄にしない）。
	var before_state: Battle = cpu._battle
	var before_map: Threat.Map = cpu._threat_map
	var user: Unit = cpu._battle.unit_by_id(used.unit_id)
	if cpu._stand != Board.NO_CELL and cpu._stand != user.cell:
		if not cpu._moved_threats.has(cpu._stand):
			var moved_state: Battle = cpu._battle.clone()
			CpuPlayer._move_in(moved_state, user.id, cpu._stand)
			cpu._moved_threats[cpu._stand] = [moved_state, cpu._threats_of(moved_state)]
		before_state = cpu._moved_threats[cpu._stand][0]
		before_map = cpu._moved_threats[cpu._stand][1]
	var worth := 0.0
	for friend in sim.units:
		if friend.side != cpu._me:
			continue
		var was: Unit = before_state.unit_by_id(friend.id)
		var before := mini(friend.hp, cpu._danger_in(before_map, was, was.cell, 0, before_state))
		var after := mini(friend.hp, cpu._danger_in(after_map, friend, friend.cell, 0, sim))
		var rate := CpuPlayer.KING_DAMAGE_VALUE if friend.kind == UnitKind.Id.KING else CpuPlayer.DAMAGE_VALUE
		worth += COVER_RATE * rate * (before - after)
		if before >= friend.hp and after < friend.hp and friend.kind != UnitKind.Id.KING:
			# 倒されうる味方が、倒されなくなる（将は、自分で逃げる）。その駒の「倒されうるマス」の重さを足す。
			worth += CpuPlayer.STYLES[UnitKind.role(friend.kind)][CpuPlayer._LETHAL]
	for shooter: Unit in cpu._battle.units:
		if shooter.side != cpu._me or shooter.attack_range() < Combat.RANGED_DISTANCE:
			continue
		var moved := sim.unit_by_id(shooter.id)
		if moved.cell != shooter.cell:
			continue  # 盾を置いた駒自身（動いてから置いた）
		for target: Unit in cpu._battle.units:
			if target.side != cpu._foe or not Combat.can_attack(cpu._battle, shooter, target):
				continue
			if not Combat.can_attack(sim, moved, sim.unit_by_id(target.id)):
				var rate := CpuPlayer.KING_DAMAGE_VALUE if target.kind == UnitKind.Id.KING else CpuPlayer.DAMAGE_VALUE
				worth -= COVER_RATE * rate * Combat.damage(cpu._battle, shooter, target)
	return worth
