extends "res://tests/base_test.gd"
## ダメージの段の順（docs/combat.md の「ダメージの解決」）: 攻撃力（確定クリティカル）→ 軍略で足すもの → 森 → 軍略で引くもの（隊列）→ 胞子 → 受ける側の状態（バリア）。
##
## 段の量は、どれも定数から読む（隊列や軍略の数が変わっても、このテストは直さなくてよい）。
## 段を並べ替えた順 1 つずつに、「書いた順で解いた結果」と「その順で解いた結果」が違う攻撃力を、その場で探して使う。
## だから、Combat.hit の段の順を入れ替えると、必ずどれかのテストが落ちる。
## 単騎（いま差し替えの途中）には頼らない。足す軍略は集中砲火、引く軍略は隊列で見る。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL
const K := UnitKind.Id

## 段の名前。並びは docs/combat.md の順（バリアと煙幕は、ほかのテストで別に見る）。
const ORDER: Array[String] = ["crit", "boost", "forest", "ranks", "spores"]
## 探す攻撃力の上限。
const MAX_POWER := 60

## 攻撃する駒（先手）、受ける駒（後手）の置き場所。森は受ける駒のマス。
const ATTACKER_CELL := Vector2i(1, 2)
const TARGET_CELL := Vector2i(2, 2)


# ---- 書いた順で解く手本 ----


## 段の量（定数から）。
func _amounts(battle: Battle) -> Dictionary:
	return {
		"crit": PrecisionAimSkill.CRITICAL_PERCENT,
		"boost": Traits.FOCUS_BONUS,
		"forest": Seam.forest_rate_percent(battle),
		"ranks": Traits.RANKS_GUARD,
		"spores": Monsters.SPORE_PENALTY,
	}


## 攻撃力 power から、order の順に段 active を当てた結果: [残る量, 隊列が引いた量（引かなければ 0）, 胞子が効いたか]。
func _solve(order: Array[String], active: Array[String], power: int, amounts: Dictionary) -> Array:
	var amount := power
	var ranks := 0
	var spores := false
	for stage in order:
		if not active.has(stage):
			continue
		match stage:
			"crit":
				amount = amount * int(amounts.crit) / Status.NORMAL_PERCENT
			"boost":
				amount += int(amounts.boost)
			"forest":
				amount = amount * int(amounts.forest) / 100
			"ranks":
				if amount > 0:
					ranks = mini(int(amounts.ranks), amount)
					amount = maxi(0, amount - int(amounts.ranks))
			"spores":
				if amount > 0:
					spores = true
					amount = maxi(0, amount - int(amounts.spores))
	return [amount, ranks, spores]


## items の並べ方の全部。
func _permutations(items: Array[String]) -> Array[Array]:
	if items.size() <= 1:
		return [items.duplicate()]
	var result: Array[Array] = []
	for i in items.size():
		var rest := items.duplicate()
		rest.remove_at(i)
		for tail in _permutations(rest):
			result.append([items[i]] + tail)
	return result


## active の段を書いた順で解いた結果が、並べ方 swapped で解いた結果と違う攻撃力。見つからなければ -1。
## 0 より大きく残るものを先に探す。隊列と胞子はどちらも引くだけなので、順は「隊列が引いた量」と「胞子が効いたか」にしか出ず、
## それが分かれるのは 0 で止まるときだけのことがある。そのときは 0 で止まるものを使う。
func _telling_power(active: Array[String], swapped: Array[String], amounts: Dictionary) -> int:
	for floor_amount: int in [0, -1]:
		for power in range(1, MAX_POWER + 1):
			var expected := _solve(ORDER, active, power, amounts)
			if int(expected[0]) > floor_amount and _solve(swapped, active, power, amounts) != expected:
				return power
	return -1


## active の段のほかの並べ方（書いた順を除く）。3 つまでは全部の並べ方、4 つ以上は 2 つの段を入れ替えたもの全部
## （全部の並べ方には、隊列と胞子の量しだいで、どの攻撃力でも同じ結果になるものが混じる）。
func _other_orders(active: Array[String]) -> Array[Array]:
	var documented: Array[String] = []
	for stage in ORDER:
		if active.has(stage):
			documented.append(stage)
	var result: Array[Array] = []
	if documented.size() <= 3:
		for order in _permutations(documented):
			if order != documented:
				result.append(order)
		return result
	for i in documented.size():
		for j in range(i + 1, documented.size()):
			var swapped := documented.duplicate()
			swapped[i] = documented[j]
			swapped[j] = documented[i]
			result.append(swapped)
	return result


# ---- 場面 ----


## 段 active が効く場面。攻撃する駒の攻撃力は power（照準の倍率を掛ける前）。
## crit: 攻撃する駒に照準。boost: 先手が集中砲火で、受ける駒はこのターンに味方に撃たれている。forest: 受ける駒が森。
## ranks: 後手が隊列で、受ける駒の隣に同じ兵種の味方。spores: 攻撃する駒の隣に中立の糸茸。
func _scene(active: Array[String], power: int) -> Array:
	var rows: Array[String] = [".......", ".......", ".......", ".......", "......."]
	if active.has("forest"):
		rows[TARGET_CELL.y] = rows[TARGET_CELL.y].substr(0, TARGET_CELL.x) + "F" + rows[TARGET_CELL.y].substr(TARGET_CELL.x + 1)
	var battle := Maps.battle(rows)
	battle.traits = [Traits.Id.FOCUS if active.has("boost") else Traits.NONE, Traits.Id.RANKS if active.has("ranks") else Traits.NONE]
	var attacker := battle.add_unit(K.COMMANDO, P1, ATTACKER_CELL)
	attacker.relic_bonus[Unit.Stat.POWER] = power - attacker.base_stat(Unit.Stat.POWER)
	var target := battle.add_unit(K.PALADIN, P2, TARGET_CELL)
	target.hp = target.max_hp()
	if active.has("crit"):
		Statuses.add(attacker, Status.Type.AIM, 2)
	if active.has("boost"):
		var ally := battle.add_unit(K.SNIPER, P1, Vector2i(6, 4))
		Traits.note_attack(battle, ally, target)
	if active.has("ranks"):
		battle.add_unit(K.PALADIN, P2, TARGET_CELL + Vector2i(1, 0))
	else:
		battle.add_unit(K.SNIPER, P2, TARGET_CELL + Vector2i(1, 0))  # 同じ盤の形のまま、隊列は効かない
	if active.has("spores"):
		var shroom := battle.add_unit(K.SHROOM, NEUTRAL, ATTACKER_CELL + Vector2i(0, -1))
		shroom.home_cell = shroom.cell
	return [battle, attacker, target]


## 段 active を重ねた場面で、Combat.hit が書いた順の結果を出すこと。
## ほかの並べ方 1 つずつに、その並べ方なら結果が変わる攻撃力を選んで確かめる（選べなければ落ちる）。
func _check_order(active: Array[String]) -> void:
	var amounts := _amounts(_scene(active, 1)[0])
	var powers: Array[int] = []
	for order in _other_orders(active):
		var swapped: Array[String] = []
		swapped.assign(order)
		var power := _telling_power(active, swapped, amounts)
		assert_ne(power, -1, "順で結果が変わる攻撃力が見つからない: %s" % ",".join(swapped))
		if power != -1 and not powers.has(power):
			powers.append(power)
	for power in powers:
		_check_hit(active, power, amounts)


## 攻撃力 power で、Combat.hit が書いた順の結果を出すこと。
func _check_hit(active: Array[String], power: int, amounts: Dictionary) -> void:
	var label := "%s、攻撃力 %d" % [",".join(active), power]
	var scene := _scene(active, power)
	var expected := _solve(ORDER, active, power, amounts)
	var hit := Combat.hit(scene[0], scene[1], scene[2])
	assert_eq(hit.amount, int(expected[0]), "残る量（%s）" % label)
	assert_eq(int(hit.traits.get(Traits.Id.RANKS, 0)), int(expected[1]), "隊列が引いた量（%s）" % label)
	assert_eq(int(hit.traits.get(Traits.Id.FOCUS, 0)), Traits.FOCUS_BONUS if active.has("boost") else 0, "集中砲火が足した量（%s）" % label)
	assert_eq(hit.spores, bool(expected[2]), "胞子が効いたか（%s）" % label)
	assert_eq(hit.forest, active.has("forest"), "森（%s）" % label)
	assert_eq(hit.critical, active.has("crit"), "確定クリティカル（%s）" % label)
	assert_eq(hit.blocked_by, -1)


# ---- 2 つずつ ----


func test_critical_before_trait_boosts() -> void:
	_check_order(["crit", "boost"] as Array[String])


func test_trait_boosts_before_forest() -> void:
	_check_order(["boost", "forest"] as Array[String])


func test_forest_before_ranks() -> void:
	_check_order(["forest", "ranks"] as Array[String])


func test_ranks_before_spores() -> void:
	_check_order(["ranks", "spores"] as Array[String])


func test_critical_before_forest() -> void:
	_check_order(["crit", "forest"] as Array[String])


func test_trait_boosts_before_ranks() -> void:
	_check_order(["boost", "ranks"] as Array[String])


func test_forest_before_spores() -> void:
	_check_order(["forest", "spores"] as Array[String])


# ---- 3 つ以上を重ねる ----


## 軍略 + 状態 + 地形（集中砲火 + 照準 + 森）。
func test_trait_status_and_terrain_together() -> void:
	_check_order(["crit", "boost", "forest"] as Array[String])


## 軍略で足す + 地形 + 軍略で引く（集中砲火 + 森 + 隊列）。
func test_boost_forest_and_ranks_together() -> void:
	_check_order(["boost", "forest", "ranks"] as Array[String])


## 全部の段を重ねる。
func test_every_stage_together() -> void:
	_check_order(ORDER)


# ---- 0 で止まる、バリア、煙幕 ----


func test_ranks_stop_at_zero_and_leave_nothing_for_spores() -> void:
	var active: Array[String] = ["forest", "ranks", "spores"]
	var scene := _scene(active, 1)
	var battle: Battle = scene[0]
	var amounts := _amounts(battle)
	# 森のあとに隊列でちょうど 0 になる攻撃力（それより小さいものも 0）。
	var power := 1
	while (power + 1) * int(amounts.forest) / 100 <= Traits.RANKS_GUARD:
		power += 1
	scene = _scene(active, power)
	battle = scene[0]
	var hit := Combat.hit(battle, scene[1], scene[2])
	assert_eq(hit.amount, 0, "0 より下にならない")
	assert_eq(int(hit.traits[Traits.Id.RANKS]), power * int(amounts.forest) / 100, "隊列が引くのは、残っていた量まで")
	assert_false(hit.spores, "隊列で 0 になったら、胞子は効かない")


func test_spores_stop_at_zero() -> void:
	var scene := _scene(["spores"] as Array[String], maxi(1, Monsters.SPORE_PENALTY - 1))
	var hit := Combat.hit(scene[0], scene[1], scene[2])
	assert_eq(hit.amount, 0)
	assert_true(hit.spores)


## バリアは最後: どれだけ重ねても 0 で、軍略の増減も胞子も出さない。森と確定クリティカルの印は残る。
func test_barrier_comes_last_over_every_stage() -> void:
	var scene := _scene(ORDER, 20)
	var battle: Battle = scene[0]
	var target: Unit = scene[2]
	Statuses.add(target, Status.Type.BARRIER, 2)
	var hit := Combat.hit(battle, scene[1], target)
	assert_eq(hit.amount, 0)
	assert_eq(hit.blocked_by, Status.Type.BARRIER)
	assert_true(hit.traits.is_empty(), "バリアに防がれたら、軍略の増減は出さない")
	assert_false(hit.spores)
	assert_true(hit.forest)
	assert_true(hit.critical)
	var result := battle.apply(AttackAction.new(scene[1].id, target.id))
	assert_true(result.accepted)
	for event in result.events:
		assert_false(event is TraitTriggeredEvent, "バリアに防がれたら、軍略は効かない")
	assert_eq(target.hp, target.max_hp())
	assert_false(Statuses.has(target, Status.Type.BARRIER), "バリアは外れる")


## 煙幕は最初: 阻まれたら、ほかの段もバリアも見ない（バリアは残る）。
func test_smoke_comes_first_over_every_stage() -> void:
	var scene := _scene(ORDER, 20)
	var battle: Battle = scene[0]
	var attacker: Unit = scene[1]
	var target: Unit = scene[2]
	Statuses.add(target, Status.Type.BARRIER, 2)
	attacker.cell = TARGET_CELL + Vector2i(-2, 0)  # 離れたところから（煙幕が防ぐ距離）
	attacker.temporary_bonus[Unit.Stat.ATTACK_RANGE] = 4
	FieldEffects.place_smoke(battle, P2, target.cell)
	var hit := Combat.hit(battle, attacker, target)
	assert_true(hit.smoke != null)
	assert_eq(hit.amount, 0)
	assert_true(hit.traits.is_empty())
	assert_eq(hit.blocked_by, -1, "バリアまで届かない")


# ---- 実際の攻撃 ----


## 全部の段を重ねた攻撃を実際に行い、起きた出来事の数が Combat.hit と同じであること（集中砲火・隊列の量、ダメージ、残りの HP）。
func test_real_attack_with_every_stage_matches_the_hit() -> void:
	var power := 20
	var scene := _scene(ORDER, power)
	var battle: Battle = scene[0]
	var attacker: Unit = scene[1]
	var target: Unit = scene[2]
	var hit := Combat.hit(battle, attacker, target)
	var before := target.hp
	var result := battle.apply(AttackAction.new(attacker.id, target.id))
	assert_true(result.accepted)
	var traits := {}
	var damaged: AttackDamagedEvent = null
	for event in result.events:
		if event is TraitTriggeredEvent:
			var triggered := event as TraitTriggeredEvent
			traits[triggered.trait_id] = triggered.amount
		elif event is AttackDamagedEvent:
			damaged = event as AttackDamagedEvent
	assert_true(damaged != null)
	assert_eq(traits, hit.traits)
	assert_eq(damaged.amount, hit.amount)
	assert_eq(damaged.hp, before - hit.amount)
	assert_eq(target.hp, before - hit.amount)
	assert_true(damaged.critical and damaged.forest)
	assert_eq(damaged.spores, hit.spores)
