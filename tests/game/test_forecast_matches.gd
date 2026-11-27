extends "res://tests/base_test.gd"
## 予測 = 実際（docs/battle-forecast.md）: 予測のパネルに出す数（game/forecast_text.gd の行）と、予測の出来事が、
## 直後に同じ行動を battle.apply したときに起きた出来事と一致すること。
## 効果を重ねた場面（軍略 + 状態 + 地形 + 魔物）と、控えた CPU どうしの 1 局（tests/support/cpu_game.gd）の全部の手で比べる。
## 比べるのは、出来事の並び（種類と、中の値の全部）、行ごとのダメージ・あとの HP・倒れるか・付く状態と外れる状態・軍略の増減。
## 軍略の量は定数から読む。

const Maps := preload("res://tests/support/maps.gd")
const CpuGame := preload("res://tests/support/cpu_game.gd")
const ForecastText := preload("res://game/forecast_text.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL
const K := UnitKind.Id


## 予測（パネルの行と、予測の出来事）を取ってから action を実際に行い、両方が一致することを確かめる。label は落ちたときの見出し。
func _matches(battle: Battle, action: BattleAction, label: String) -> ActionResult:
	var actor := _actor(battle, action)
	var forecast := Forecast.of(battle, action)
	var summary := ForecastText.summarize(battle, forecast, actor)
	var result := battle.apply(action)
	assert_eq(result.accepted, forecast.accepted, label + ": 受け付けるか")
	if not result.accepted:
		return result
	_same_events(forecast.events, result.events, label)
	var damage := {}
	var defeated := {}
	var applied := {}
	var removed := {}
	var traits := {}
	for event in result.events:
		if event is UnitDamagedEvent:
			var damaged := event as UnitDamagedEvent
			damage[damaged.unit_id] = int(damage.get(damaged.unit_id, 0)) + damaged.amount
			for id: int in damaged.traits:
				var by_unit: Dictionary = traits.get(damaged.unit_id, {})
				by_unit[id] = int(by_unit.get(id, 0)) + int(damaged.traits[id])
				traits[damaged.unit_id] = by_unit
		elif event is SmokeBlockedEvent:
			damage[(event as SmokeBlockedEvent).target_id] = int(damage.get((event as SmokeBlockedEvent).target_id, 0))
		elif event is UnitDefeatedEvent:
			defeated[(event as UnitDefeatedEvent).unit_id] = true
		elif event is StatusAppliedEvent:
			var added := event as StatusAppliedEvent
			var turns: Dictionary = applied.get(added.unit_id, {})
			turns[added.status] = added.turns
			applied[added.unit_id] = turns
		elif event is StatusRemovedEvent:
			var gone := event as StatusRemovedEvent
			var types: Array = removed.get(gone.unit_id, [])
			types.append(gone.status)
			removed[gone.unit_id] = types
	var shown := {}
	for row in summary.rows:
		shown[row.unit_id] = true
		var name := "%s（駒 %d）" % [label, row.unit_id]
		var unit := battle.unit_by_id(row.unit_id)
		assert_eq(row.damage, int(damage.get(row.unit_id, -1)), name + ": ダメージ")
		assert_eq(row.hp_after, unit.hp if unit != null else 0, name + ": 残りの HP")
		assert_eq(row.defeated, defeated.has(row.unit_id), name + ": 倒れるか")
		var outcome := forecast.outcome(row.unit_id)
		assert_eq(Dictionary(outcome.statuses_applied), applied.get(row.unit_id, {}), name + ": 付く状態")
		assert_eq(Array(outcome.statuses_removed), removed.get(row.unit_id, []), name + ": 外れる状態")
		assert_eq(Dictionary(outcome.traits), traits.get(row.unit_id, {}), name + ": 軍略の増減")
	for unit_id: int in damage:
		assert_true(shown.has(unit_id) or battle.unit_by_id(unit_id) == null and not defeated.has(unit_id),
			"%s: ダメージを受けた駒 %d がパネルに出ていない" % [label, unit_id])
	for unit_id: int in defeated:
		assert_true(shown.has(unit_id), "%s: 倒れた駒 %d がパネルに出ていない" % [label, unit_id])
	return result


## パネルの「行動する駒」（行動が駒を指していればその駒、でなければ番の陣営の最初の駒）。
func _actor(battle: Battle, action: BattleAction) -> Unit:
	var unit_id: Variant = action.get("unit_id")
	if unit_id != null:
		return battle.unit_by_id(int(unit_id))
	for unit in battle.units:
		if unit.side == battle.phase:
			return unit
	return null


## 2 つの出来事の列が、種類も中の値も同じこと。
func _same_events(predicted: Array[BattleEvent], actual: Array[BattleEvent], label: String) -> void:
	assert_eq(predicted.size(), actual.size(), label + ": 出来事の数")
	for i in mini(predicted.size(), actual.size()):
		assert_eq(predicted[i].get_script(), actual[i].get_script(), "%s: %d 番目の出来事の種類" % [label, i])
		assert_eq(_values(predicted[i]), _values(actual[i]), "%s: %d 番目の出来事の値" % [label, i])


## 出来事の中の値（スクリプトの変数の全部）。
func _values(event: BattleEvent) -> Dictionary:
	var result := {}
	for property in event.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = event.get(property.name)
			result[property.name] = value
	return result


# ---- 効果を重ねた場面 ----


## 7 x 5。受ける駒のマス (2, 2) が森。先手の軍略は mine、後手は theirs。
func _battle(mine: int, theirs: int) -> Battle:
	var battle := Maps.battle([".......", ".......", "..F....", ".......", "......."])
	battle.traits = [mine, theirs]
	return battle


## 集中砲火 + 照準 + 突撃（一時的な補正）+ 森 + 隊列 + 胞子。受ける駒の HP は hp。
func _stacked(hp: int) -> Array:
	var battle := _battle(Traits.Id.FOCUS, Traits.Id.RANKS)
	var attacker := battle.add_unit(K.SNIPER, P1, Vector2i(2, 4))
	var ally := battle.add_unit(K.COMMANDO, P1, Vector2i(6, 0))
	var target := battle.add_unit(K.PALADIN, P2, Vector2i(2, 2))
	battle.add_unit(K.PALADIN, P2, Vector2i(3, 2))
	var shroom := battle.add_unit(K.SHROOM, NEUTRAL, Vector2i(1, 4))
	shroom.home_cell = shroom.cell
	Statuses.add(attacker, Status.Type.AIM, 2)
	Statuses.add(attacker, Status.Type.ASSAULT, 2)
	Traits.note_attack(battle, ally, target)
	target.hp = hp
	return [battle, attacker, target]


func test_every_effect_stacked() -> void:
	var scene := _stacked(99)
	var battle: Battle = scene[0]
	var target: Unit = scene[2]
	target.hp = target.max_hp()
	var hit := Combat.hit(battle, scene[1], target)
	assert_true(hit.critical and hit.forest and hit.spores, "全部の段が効く場面")
	assert_true(hit.traits.has(Traits.Id.FOCUS) and hit.traits.has(Traits.Id.RANKS))
	assert_true(hit.amount > 0 and hit.amount < target.hp, "倒れない量")
	_matches(battle, AttackAction.new(scene[1].id, target.id), "重ねた攻撃")


func test_every_effect_stacked_and_lethal() -> void:
	var scene := _stacked(1)
	var battle: Battle = scene[0]
	var hit := Combat.hit(battle, scene[1], scene[2])
	assert_true(hit.amount >= 1, "倒れる量")
	_matches(battle, AttackAction.new(scene[1].id, scene[2].id), "重ねて倒す攻撃")
	assert_eq(battle.unit_by_id(scene[2].id), null)


func test_every_effect_stacked_into_a_barrier() -> void:
	var scene := _stacked(99)
	var target: Unit = scene[2]
	target.hp = target.max_hp()
	Statuses.add(target, Status.Type.BARRIER, 2)
	_matches(scene[0], AttackAction.new(scene[1].id, target.id), "バリアへの重ねた攻撃")
	assert_eq(target.hp, target.max_hp())


func test_every_effect_stacked_into_smoke() -> void:
	var scene := _stacked(99)
	var battle: Battle = scene[0]
	var target: Unit = scene[2]
	FieldEffects.place_smoke(battle, P2, target.cell)
	_matches(battle, AttackAction.new(scene[1].id, target.id), "煙幕への重ねた攻撃")


## 騎士領の足すもの（仇討ち）+ 地形 + 受ける側の隊列。仇の印は、実際に味方を倒させて付ける。
func test_vengeance_forest_and_ranks() -> void:
	var battle := _battle(Traits.Id.VENGEANCE, Traits.Id.RANKS)
	var knight := battle.add_unit(K.PALADIN, P1, Vector2i(2, 3))
	var fallen := battle.add_unit(K.SNIPER, P1, Vector2i(6, 4))
	var target := battle.add_unit(K.COMMANDO, P2, Vector2i(2, 2))
	battle.add_unit(K.COMMANDO, P2, Vector2i(1, 2))
	battle.remove_unit(fallen, target)
	assert_true(Traits.slew(target, P1), "仇の印")
	_matches(battle, AttackAction.new(knight.id, target.id), "仇討ち + 森 + 隊列")


# ---- 控えた CPU どうしの 1 局 ----


func test_every_move_of_a_cpu_game() -> void:
	var battle := CpuGame.start()
	var moves := 0
	for action in CpuGame.actions():
		moves += 1
		var result := _matches(battle, action, "CPU の %d 手目" % moves)
		if not result.accepted:
			break
	assert_true(moves > 0)
