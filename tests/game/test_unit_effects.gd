extends "res://tests/base_test.gd"
## 兵に乗っている効果（game/unit_effects.gd）と、その札の並び（game/effect_chips.gd）。docs/battle-view.md の「兵に乗っている効果」。

const Maps := preload("res://tests/support/maps.gd")
const UnitEffects := preload("res://game/unit_effects.gd")
const EffectChips := preload("res://game/effect_chips.gd")
const UnitSheet := preload("res://game/unit_sheet.gd")
const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const K := UnitKind.Id
const T := Traits.Id


func _battle(rows: Array[String], mine := Traits.NONE, theirs := Traits.NONE) -> Battle:
	var battle := Maps.battle(rows)
	battle.traits = [mine, theirs]
	return battle


func _find(effects: Array[UnitEffects.Effect], name: String) -> UnitEffects.Effect:
	for effect in effects:
		if effect.name == name:
			return effect
	return null


func test_focus_mark_shows_on_the_struck_enemy_with_the_same_number_as_the_forecast() -> void:
	var battle := _battle([".......", ".......", ".......", "......."], T.FOCUS)
	var first := battle.add_unit(K.SNIPER, P1, Vector2i(0, 1))
	var second := battle.add_unit(K.COMMANDO, P1, Vector2i(3, 2))
	var target := battle.add_unit(K.PALADIN, P2, Vector2i(3, 1))
	assert_eq(_find(UnitEffects.of(battle, target), Names.troop_trait(T.FOCUS)), null, "攻撃される前は出ない")
	assert_true(battle.apply(AttackAction.new(first.id, target.id)).accepted)
	var focus := _find(UnitEffects.of(battle, target), Names.troop_trait(T.FOCUS))
	assert_true(focus != null, "攻撃された敵に、集中砲火が乗る")
	assert_false(focus.good, "狙われる側には悪い効果")
	var forecast := Forecast.of(battle, AttackAction.new(second.id, target.id))
	for outcome in forecast.units:
		if outcome.unit_id == target.id:
			assert_true(focus.value.contains("+%d" % outcome.traits[T.FOCUS]), "予測の内訳と数が食い違う: %s" % focus.value)
	assert_false(focus.in_stats, "ダメージの増減は能力値の行に入らない")


func test_ranks_and_guard_show_on_own_units() -> void:
	var battle := _battle([".......", ".......", "......."], T.RANKS, T.GUARD)
	var a := battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(1, 1))
	battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(2, 1))
	var knight := battle.add_unit(K.PALADIN, P2, Vector2i(5, 1))
	var ranks := _find(UnitEffects.of(battle, a), Names.troop_trait(T.RANKS))
	assert_true(ranks != null and ranks.good and ranks.value.contains("-%d" % Traits.RANKS_GUARD), "隊列が出ない")
	assert_true(_find(UnitEffects.of(battle, knight), Names.troop_trait(T.GUARD)) == null, "ひとりのパラディンは守られない")
	var priest := battle.add_unit(K.PRIEST, P2, Vector2i(5, 2))
	var guard := _find(UnitEffects.of(battle, priest), Names.troop_trait(T.GUARD))
	assert_true(guard != null and guard.good and guard.value.contains("-%d" % Traits.GUARD_SHIELD), "守護が出ない")


func test_a_status_shows_its_number_and_turns_and_is_in_the_stat_line() -> void:
	var battle := _battle([".....", "....."])
	var unit := battle.add_unit(K.COMMANDO, P1, Vector2i(1, 1))
	Statuses.add(unit, Status.Type.RESOLVE, 2)
	var resolve := _find(UnitEffects.of(battle, unit), Names.status(Status.Type.RESOLVE))
	assert_true(resolve != null and resolve.good and resolve.turns == 2 and resolve.in_stats)
	assert_true(resolve.value.contains("+%d" % Monsters.RESOLVE_POWER))
	var sheet: UnitSheet = UnitSheet.of_unit(unit)
	assert_eq(sheet.stat_line(Unit.Stat.POWER).delta(), Monsters.RESOLVE_POWER, "能力値の行に、状態の増減が入っている")


func test_forest_and_spring_show_on_the_cell() -> void:
	var battle := _battle(["F.S", "..."])
	var in_forest := battle.add_unit(K.COMMANDO, P1, Vector2i(0, 0))
	var on_spring := battle.add_unit(K.COMMANDO, P1, Vector2i(2, 0))
	var forest := _find(UnitEffects.of(battle, in_forest), Text.t("battle.cell.forest"))
	assert_true(forest != null and forest.value.contains("-%d" % (100 - Combat.FOREST_DAMAGE_RATE_PERCENT)), "森が出ない")
	assert_true(_find(UnitEffects.of(battle, on_spring), Text.t("battle.cell.spring")) != null, "回復の泉が出ない")
	assert_eq(UnitEffects.of(battle, battle.add_unit(K.COMMANDO, P1, Vector2i(1, 1))).size(), 0, "何も乗っていない兵は空")


## 札の欄は、効果が無くても多くても同じ大きさ。入りきらないぶんは「ほか N」。
func test_chips_keep_their_size_and_fold_the_rest() -> void:
	var chips := EffectChips.new(320.0, 2)
	await settle(chips)
	var empty := chips.get_combined_minimum_size()
	var many: Array[UnitEffects.Effect] = []
	for i in 9:
		many.append(UnitEffects.Effect.new(Names.troop_trait(T.FOCUS), Text.t("battle.effect.taken", {"amount": "+2"}), i % 2 == 0))
	chips.show_effects(many)
	await settle(chips)
	assert_eq(chips.get_combined_minimum_size(), empty, "効果が多いと欄が伸びる")
	var lines := chips.lines()
	assert_true(lines.size() < many.size() and lines[lines.size() - 1] == Text.t("battle.effect.more", {"count": many.size() - lines.size() + 1}), "ほか N にまとまらない: %s" % [lines])
	chips.show_effects([])
	await settle(chips)
	assert_eq(chips.get_combined_minimum_size(), empty, "効果が無いと欄が縮む")
	chips.free()
