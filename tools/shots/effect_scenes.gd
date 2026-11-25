extends "res://tools/shots/battle_info_scenes.gd"
## スクリーンショットの場面: 演出の途中（攻撃が当たる瞬間、スキル、必殺技）と、相手の番の見え方。


func _scene_hit_slam() -> bool:
	return await _attack_frame([UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.PALADIN], 0.08)


func _scene_hit_slash() -> bool:
	return await _attack_frame([UnitKind.Id.COMMANDO, UnitKind.Id.SPELLBLADE], 0.08)


func _scene_hit_shot() -> bool:
	return await _attack_frame([UnitKind.Id.SNIPER], 0.06)


func _scene_hit_magic() -> bool:
	return await _attack_frame([UnitKind.Id.SORCERER], -0.07)


func _scene_auto_confirm() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 2 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	await _idle()
	_scene.press_auto()
	return _scene.is_confirming_auto()


func _scene_cpu_watch() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 2 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	await _idle()
	_scene.set_opponent(true)
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.press_end_turn()
	_scene.pass_confirm_guard()
	_scene.press_end_turn()
	await get_tree().create_timer(0.4).timeout
	_mid_animation = true
	return _scene.watch_controls_state()[0]


func _scene_wait_sign() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 2 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var unit: Unit = null
	for candidate in _own_units():
		if _battle.can_act(candidate) and candidate.kind != UnitKind.Id.KING:
			unit = candidate
			break
	if unit == null:
		return false
	await _settle_camera(unit.cell)
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(WaitAction.new(unit.id))
	await get_tree().create_timer(0.15).timeout
	_mid_animation = true
	return true


## skill を持つ駒が使える場面まで進め、使って、使った瞬間から after 秒あとに撮る。
## 対象は、駒のいるマス（自分のほか）を優先する。カメラは対象へ寄せる。
func _skill_frame(skill: Skill.Id, after: float) -> bool:
	var find := func() -> Array:
		if _battle.phase == Unit.Side.NEUTRAL:
			return []
		for unit in _own_units():
			if Skills.of(unit) == null or Skills.of(unit).id() != skill or not _battle.can_act(unit):
				continue
			var cells := Queries.skill_cells(_battle, unit)
			if cells.is_empty():
				continue
			for cell in cells:
				if cell != unit.cell and _battle.unit_at(cell) != null:
					return [unit, cell]
			return [unit, cells[0]]
		return []
	if not _advance(func() -> bool: return not find.call().is_empty()):
		return false
	var found: Array = find.call()
	var unit: Unit = found[0]
	_show()
	await _settle_camera((unit.cell + found[1]) / 2)
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(UseSkillAction.new(unit.id, found[1]))
	await get_tree().create_timer(after).timeout
	_mid_animation = true
	return true


func _scene_skill_fireball() -> bool:
	return await _skill_frame(Skill.Id.FIREBALL, 0.43)


func _scene_skill_barricade() -> bool:
	return await _skill_frame(Skill.Id.TACTICAL_BARRICADE, 0.47)


## 置いたばかりの盾（青）と、削られた盾（赤。残りの耐久 7）を並べ、削られた盾にマウスを乗せる。
func _scene_barricade_worn() -> bool:
	_new_battle()
	var spots: Array[Vector2i] = []
	var middle := _battle.board.size / 2
	for y in range(middle.y - 3, middle.y + 4):
		for x in range(middle.x - 4, middle.x + 4):
			var cell := Vector2i(x, y)
			var next := cell + Vector2i(2, 0)
			if spots.is_empty() and FieldEffects.can_place_barricade(_battle, cell) and FieldEffects.can_place_barricade(_battle, next):
				spots = [cell, next]
	if spots.is_empty():
		return false
	FieldEffects.place_barricade(_battle, Unit.Side.PLAYER1, spots[0])
	FieldEffects.place_barricade(_battle, Unit.Side.PLAYER2, spots[1])
	_battle.board.barricade_at(spots[1]).durability = 7
	_show()
	await _settle_camera(spots[0] + Vector2i(1, 0))
	_scene.click_cell(spots[1])
	_scene.hover(spots[1])
	return _scene.barricade_bar_durability(_battle.board.barricade_at(spots[1]).id) == 7


func _scene_skill_smoke() -> bool:
	return await _skill_frame(Skill.Id.SMOKE_GRENADE, 0.5)


func _scene_skill_saint() -> bool:
	return await _skill_frame(Skill.Id.SAINT_PLACE, 0.5)


func _scene_skill_shield() -> bool:
	return await _skill_frame(Skill.Id.DIVINE_SHIELD, 0.5)


func _scene_skill_aim() -> bool:
	return await _skill_frame(Skill.Id.PRECISION_AIM, 0.55)


func _scene_skill_shadow() -> bool:
	return await _skill_frame(Skill.Id.SHADOW_STEP, 0.48)


func _scene_skill_adrenaline() -> bool:
	return await _skill_frame(Skill.Id.ADRENALINE_SHOT, 0.58)


## army の必殺技が使える場面まで進め、使って、使った瞬間から after 秒あとに撮る。
func _ult_frame(army: UnitKind.Army, after: float) -> bool:
	var ready := func() -> bool:
		return Ults.can_use(_battle) and Ults.of(_battle, _battle.phase) != null and Ults.of(_battle, _battle.phase).army() == army
	if not _advance(ready):
		return false
	_show()
	# 効果の掛かる駒（いまの番の陣営の駒）が、いちばん多く集まっているところを見る。
	var units := _own_units()
	var best := units[0].cell
	var best_count := -1
	for unit in units:
		var count := 0
		for other in units:
			if _distance(unit.cell, other.cell) <= 4:
				count += 1
		if count > best_count:
			best = unit.cell
			best_count = count
	_aim(17.0, 0.0, OrbitCamera.DEFAULT_PITCH)
	_scene.focus_camera(best)
	await get_tree().create_timer(SETTLE).timeout
	await _banner_gone()
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(UseUltAction.new())
	await get_tree().create_timer(after).timeout
	_mid_animation = true
	return true


func _scene_ult_assault() -> bool:
	return await _ult_frame(UnitKind.Army.MILITARY, 0.1)


func _scene_ult_eruption() -> bool:
	return await _ult_frame(UnitKind.Army.FANTASY, 0.62)
