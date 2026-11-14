class_name Combat
extends RefCounted
## 攻撃の届く範囲と、ダメージの計算。
##
## - 射程はマンハッタン距離（上下左右の歩数）。地形は射程を遮らない（壁越しに撃てる）
## - ただし、攻撃する駒と相手の間のマス（cells_between）に盾があると届かない（docs/field-effects.md）
## - 攻撃できるのは敵（違う陣営）の駒だけ。中立の駒は両プレイヤーの敵
## - ダメージは攻撃側の攻撃力（確定クリティカルなら倍率を掛ける）。守る側が森にいれば 0.8 倍（端数切り捨て）
## - 受ける側にバリアがあれば 0（Hit。駒の HP を減らすものは、どれも Hit を通す）
## - 煙幕の中の持ち主の駒への、離れたところ（距離 RANGED_DISTANCE 以上）からの攻撃は、ダメージが 0 になる（FieldEffects.smoke_covering）
## - 回復役（衛生兵・プリースト）は攻撃しない（かわりに味方を回復する。Healing）

const FOREST_DAMAGE_RATE_PERCENT := 80
## この距離から先の攻撃が「離れたところからの攻撃」。煙幕が防ぐ。
const RANGED_DISTANCE := 2


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## from から to へ、射程 attack_range の攻撃が届くか。距離が射程以内で、間のマスに盾が無いこと。
## 駒への攻撃、起爆樽・盾への攻撃のどれも、これで測る。
static func reaches(battle: Battle, from: Vector2i, to: Vector2i, attack_range: int) -> bool:
	if distance(from, to) > attack_range:
		return false
	return not is_line_blocked(battle.board, from, to)


## from と to の間に、射線を遮る盾があるか。
static func is_line_blocked(board: Board, from: Vector2i, to: Vector2i) -> bool:
	if not board.has_barricades():
		return false
	for cell in cells_between(from, to):
		if board.barricade_at(cell) != null:
			return true
	return false


## from と to の「間のマス」（両端は含まない。上の行から、左の列から）。
## 2 つのマスの中心を結ぶ線分が、マスの内側を通るマス。マスの角に触れるだけのマスは含まない。
## 縦か横に並んでいれば、その間に並ぶマス。斜めにちょうど並んでいれば、その対角線上のマス。どちら向きに測っても同じになる。
static func cells_between(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var d := to - from
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			var cell := Vector2i(x, y)
			if cell != from and cell != to and _segment_crosses(from, d, cell):
				result.append(cell)
	return result


## from から from + d への線分（マスの中心どうし）が、cell の内側（辺と角を除く）を通るか。
static func _segment_crosses(from: Vector2i, d: Vector2i, cell: Vector2i) -> bool:
	var lo := 0.0
	var hi := 1.0
	for axis in 2:
		var start := from[axis]
		var step := d[axis]
		var middle := cell[axis]
		if step == 0:
			if start != middle:
				return false
			continue
		var t1 := (middle - 0.5 - start) / float(step)
		var t2 := (middle + 0.5 - start) / float(step)
		lo = maxf(lo, minf(t1, t2))
		hi = minf(hi, maxf(t1, t2))
	return lo < hi


static func can_attack(battle: Battle, attacker: Unit, target: Unit) -> bool:
	if attacker == null or target == null or not attacker.is_enemy_of(target):
		return false
	if UnitKind.role(attacker.kind) == UnitKind.Role.HEALER:
		return false
	if not battle.units.has(target):
		return false
	return reaches(battle, attacker.cell, target.cell, attacker.attack_range())


## いまの位置から攻撃できる駒。並びは盤面の上の行から、左の列から。
static func targets(battle: Battle, attacker: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in battle.units:
		if can_attack(battle, attacker, unit):
			result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	return result


## attacker の、いまの攻撃 1 回の攻撃力。確定クリティカルの状態（照準）なら、その倍率を掛けた値。
## 駒への攻撃と、盾への攻撃が使う。
static func attack_power(attacker: Unit) -> int:
	return attacker.power() * Statuses.critical_percent(attacker) / Status.NORMAL_PERCENT


## attacker がいまの位置から target を攻撃したら、どうなるか（ダメージの解決。Hit）。状態は変えない。
## 順に、煙幕（阻まれたら 0。ここで終わり）、攻撃力（確定クリティカルなら倍率を掛ける）、森の軽減、受ける側の状態（バリア）。
## 予測と CPU は、これ（か damage）を読む。実際の攻撃（strike）も同じ結果を適用する。
static func hit(battle: Battle, attacker: Unit, target: Unit) -> Hit:
	var smoke := FieldEffects.smoke_covering(battle, attacker.cell, target)
	if smoke != null:
		return Hit.smoked(attacker, target, smoke)
	var amount := attack_power(attacker)
	if battle.board.terrain_at(target.cell) == Terrain.Type.FOREST:
		amount = amount * FOREST_DAMAGE_RATE_PERCENT / 100
	var result := Hit.resolve(attacker, target, amount, UnitDamagedEvent.Cause.ATTACK)
	result.critical = Statuses.critical_percent(attacker) != Status.NORMAL_PERCENT
	return result


## attacker がいまの位置から target に与えるダメージ（予測にも使う）。煙幕かバリアに防がれるなら 0。
static func damage(battle: Battle, attacker: Unit, target: Unit) -> int:
	return hit(battle, attacker, target).amount


## attacker が target を攻撃する（届くかどうかは呼ぶ側が確かめる）。起きたことを返す。
## 煙幕に阻まれたら SmokeBlockedEvent。そうでなければ AttackDamagedEvent と、防いだ状態（バリア）が外れる StatusRemovedEvent。
## 続けて、攻撃で外れる攻撃側の状態（照準）の StatusRemovedEvent、倒れたら UnitDefeatedEvent。
## プレイヤーの駒の攻撃（AttackAction）と中立の駒の攻撃（Neutral）が同じものを使う。経験値と行動の終わりは呼ぶ側。
static func strike(battle: Battle, attacker: Unit, target: Unit) -> Array[BattleEvent]:
	var resolved := hit(battle, attacker, target)
	var after := resolved.apply()
	var events: Array[BattleEvent] = []
	if resolved.smoke != null:
		events.append(SmokeBlockedEvent.new(attacker.id, target.id, resolved.smoke.id))
	else:
		events.append(AttackDamagedEvent.new(resolved))
	events.append_array(after)
	events.append_array(Statuses.after_attack(attacker))
	if target.hp == 0:
		events.append(battle.remove_unit(target))
	return events
