class_name MapObject
extends RefCounted
## 環境オブジェクト（起爆樽、回復の泉、ポータル）の種類と、その効果の計算。
##
## どこに何があるかは Board が持つ（Board.object_at）。ここの計算は状態を変えない。
## 状態を変えるのは行動の側（AttackBarrelAction、EndPhaseAction、MoveAction）で、戦闘予測も同じ計算を使う。
##
## - 起爆樽: 入れない。攻撃されると爆発して消え、周り 8 マスの駒すべてに固定のダメージ
## - 回復の泉: 入れる。プレイヤーのフェーズの始めに、乗っているそのプレイヤーの駒が回復する
## - 砲台: 入れる。選べる決まり（TrialRules.BATTERY）が入のときだけ置かれる。乗った後衛の射程が伸びる（Unit.site_range）
## - 拠点: 入れる。選べる決まり（TrialRules.STRONGHOLD）が入のときだけ置かれる。乗って番を終えると確保が進む（Stronghold）
## - ポータル: 入れる。対になるポータルへ、移動力を使わずに移れる（Movement、Battle.portal_exit）

enum Type {
	NONE,  ## 何も無い
	BARREL,  ## 起爆樽
	SPRING,  ## 回復の泉
	PORTAL,  ## ポータル
	BATTERY,  ## 砲台（選べる決まり）
	STRONGHOLD,  ## 拠点（Stronghold）
}

## 起爆樽の耐久力。攻撃 1 回で（攻撃力によらず）1 減るので、攻撃されれば必ず爆発する。
const BARREL_HP := 1
## 起爆樽の爆発のダメージ。攻撃力にも地形にもよらない。
const BLAST_DAMAGE := 15
## 回復の泉の回復量。
const SPRING_HEAL := 12
## 砲台に乗った後衛の射程の伸び。
const BATTERY_RANGE := 4


## unit が cell に立ったときの、砲台による射程の伸び。後衛が、置かれた砲台（Board.battery_cells）のマスに立ったときだけ BATTERY_RANGE。
static func battery_bonus(board: Board, unit: Unit, cell: Vector2i) -> int:
	if board.battery_cells.is_empty() or UnitKind.role(unit.kind) != UnitKind.Role.REARGUARD:
		return 0
	return BATTERY_RANGE if board.battery_cells.has(cell) else 0


static func is_walkable(type: Type) -> bool:
	return type != Type.BARREL


## attacker がいまの位置から cell の起爆樽を攻撃できるか。射程の測り方は駒への攻撃と同じ（間に盾があれば届かない）。
static func can_attack_barrel(battle: Battle, attacker: Unit, cell: Vector2i) -> bool:
	if attacker == null or battle.board.object_at(cell) != Type.BARREL:
		return false
	if UnitKind.role(attacker.kind) == UnitKind.Role.HEALER:
		return false
	return Combat.reaches(battle, attacker.cell, cell, attacker.attack_range())


## いまの位置から攻撃できる起爆樽のマス。並びは盤面の上の行から、左の列から。
static func barrel_targets(battle: Battle, attacker: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in battle.board.barrel_cells:
		if can_attack_barrel(battle, attacker, cell):
			result.append(cell)
	result.sort_custom(Board.in_reading_order)
	return result


## cell の樽が爆発したときに巻き込むマス（周り 8 マスのうち盤の中のもの）。上の行から、左の列から。
static func blast_cells(board: Board, cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := cell + Vector2i(dx, dy)
			if near != cell and board.in_bounds(near):
				result.append(near)
	return result


## cell の樽が爆発したときに巻き込まれる駒（陣営を問わない）。上の行から、左の列から。
static func blast_victims(battle: Battle, cell: Vector2i) -> Array[Unit]:
	var result: Array[Unit] = []
	for near in blast_cells(battle.board, cell):
		var unit := battle.unit_at(near)
		if unit != null:
			result.append(unit)
	return result


## 爆発が unit に当たったら、どうなるか（ダメージの解決。Hit）。状態は変えない。
## 量は固定（攻撃力にも地形にもよらない）。バリアには防がれる。
static func blast_hit(unit: Unit) -> Hit:
	return Hit.resolve(null, unit, BLAST_DAMAGE, UnitDamagedEvent.Cause.EXPLOSION)


## 爆発が unit に与えるダメージ（予測にも使う）。バリアに防がれるなら 0。
static func blast_damage(unit: Unit) -> int:
	return blast_hit(unit).amount


## side のフェーズの始めに、回復の泉で回復する駒（HP が減っているものだけ）。上の行から、左の列から。
static func spring_targets(battle: Battle, side: Unit.Side) -> Array[Unit]:
	var result: Array[Unit] = []
	if side == Unit.Side.NEUTRAL:
		return result
	for unit in battle.units:
		if unit.side == side and battle.board.object_at(unit.cell) == Type.SPRING and spring_heal(unit) > 0:
			result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool: return Board.in_reading_order(a.cell, b.cell))
	return result


## 回復の泉で unit の HP が実際に増える量。最大 HP を超えるぶんは切り捨てる。
static func spring_heal(unit: Unit) -> int:
	return clampi(unit.max_hp() - unit.hp, 0, SPRING_HEAL)
