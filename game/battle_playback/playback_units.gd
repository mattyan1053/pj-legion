extends "res://game/battle_playback/playback_base.gd"
## 駒のイベントの再生: 動く・戻す・転移、当たる、回復、経験とレベルアップ、進化、跳ぶ・入れ替わる、倒れる、湧く。


func _play_moved(event: UnitMovedEvent) -> void:
	if event.path.size() < 2:
		return
	var view := _view(event.unit_id)
	var unit := battle.unit_by_id(event.unit_id)
	var step_time := CRUISE_STEP_TIME if event.cruise else STEP_TIME
	if unit != null and unit.side == Unit.Side.NEUTRAL:
		step_time = NEUTRAL_STEP_TIME
	# 自分で動かしていない駒（CPU の駒、中立の駒）は、歩いている間、カメラが追いかける（長く歩いても、画面の外へ出ていかない）。
	var followed := _camera_follows(unit)
	if followed:
		camera_follows[event.unit_id] = camera_follows.get(event.unit_id, 0) + 1
		_rig.follow(view)
	view.play_run()
	for i in range(1, event.path.size()):
		var target := BoardView.cell_center(event.path[i])
		view.face(target - view.position)
		var tween := create_tween()
		tween.tween_property(view, "position", target, step_time)
		await tween.finished
	view.play_idle()
	if followed:
		_rig.follow(null)


func _play_undone(event: MoveUndoneEvent) -> void:
	var view := _view(event.unit_id)
	var tween := create_tween()
	tween.tween_property(view, "position", BoardView.cell_center(event.to), 0.15)
	await tween.finished


## 道順どおりに歩いたあとの、ポータルの転移。入ったポータルで縮んで消え、出たポータルに現れる。
func _play_warped(event: UnitWarpedEvent) -> void:
	var view := _view(event.unit_id)
	var color := BoardView.portal_color(battle.board, event.from)
	var to := BoardView.cell_center(event.to)
	_flash(BoardView.cell_center(event.from), color, 0.9)
	_sound(&"portal")
	var shrink := create_tween()
	shrink.tween_property(view, "scale", Vector3.ONE * 0.05, 0.16)
	await shrink.finished
	view.position = to
	if not _quiet_playback:
		_rig.focus_on(to)  # 行き先が画面の外でも、どこへ出たかが見えるようにする（静かな場面では、カメラを動かさない）。
	_flash(to, color, 0.9)
	var grow := create_tween()
	grow.tween_property(view, "scale", Vector3.ONE, 0.16)
	await grow.finished


## 駒の攻撃。攻撃の動きのあとに被弾。
func _play_attack_damaged(event: AttackDamagedEvent) -> void:
	var target := _view(event.unit_id)
	var attacker := _view(event.attacker_id)
	_show_strike(event.attacker_id, attacker, target)
	attacker.face(target.position - attacker.position)
	target.face(attacker.position - target.position)
	await _strike(attacker, target.position)
	await _play_hit(event, Color("ffe9a8"), 0.45)


## 爆発のダメージ（攻撃した駒がいない）は、被弾だけを続けて見せる。
func _play_explosion_damaged(event: ExplosionDamagedEvent) -> void:
	await _play_hit(event, Color("ffb14a"), 0.15)


## スキルのダメージ（使った駒の動きは SkillUsedEvent が見せた）は、被弾だけを続けて見せる。
func _play_skill_damaged(event: SkillDamagedEvent) -> void:
	await _play_hit(event, Color("ff7a4a"), 0.15)


func _play_hit(event: UnitDamagedEvent, color: Color, wait: float) -> void:
	var target := _view(event.unit_id)
	target.play_hit()
	target.set_hp(event.hp)
	if event.is_blocked():
		_sound(&"blocked")
		_pop_number(target.position, Text.t("battle.pop.blocked", {"status": Names.status(event.blocked_by as Status.Type)}), Color("9fd8ff"))
	elif event.critical:
		_sound(&"critical")
		_pop_number(target.position, Text.t("battle.pop.critical", {"amount": event.amount}), Color("ff5a4a"))
	else:
		_pop_number(target.position, "-%d" % event.amount, color)
	await after(wait)


## 回復役の回復。回復役が相手のほうを向いて手を振り、相手に光と数を出す。
func _play_healer_healed(event: HealerHealedEvent) -> void:
	var healer := _view(event.healer_id)
	var target := _view(event.unit_id)
	healer.face(target.position - healer.position)
	_acted_with_effect = true
	await after(healer.play_attack())
	await _play_heal(event, true)


## 回復の泉（フェーズの始め）は、光と数を出す。
func _play_spring_healed(event: SpringHealedEvent) -> void:
	await _play_heal(event, true)


## 再生（進化先の特性。フェーズの始め）も、光と数を出す。
func _play_regeneration_healed(event: RegenerationHealedEvent) -> void:
	await _play_heal(event, true)


func _play_heal(event: UnitHealedEvent, glow: bool) -> void:
	var view := _view(event.unit_id)
	view.set_hp(event.hp)
	_sound(&"heal")
	_pop_number(view.position, "+%d" % event.amount, Color("9cf09c"))
	if glow:
		_flash(view.position, BoardView.COLOR_SPRING_CROSS, 0.8)
	await after(0.35)


## 経験値が入った。数を小さく出すだけ（たまった量は左下の駒の情報に出る）。
func _play_experience_gained(event: ExperienceGainedEvent) -> void:
	var view := _view(event.unit_id)
	_pop_number(view.position + Vector3(0.0, 0.35, 0.0), Text.t("battle.pop.experience", {"amount": event.amount}), COLOR_EXPERIENCE)
	await after(0.2)


## レベルが上がった。札のレベルと HP のバーを描き直し、光と知らせを出す。
func _play_level_up(event: LevelUpEvent) -> void:
	var view := _view(event.unit_id)
	view.set_growth(event.level, event.max_hp)
	view.set_hp(event.hp)
	_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_LEVEL_UP, 1.4)
	_sound(&"level_up")
	_pop_number(view.position + Vector3(0.0, 0.6, 0.0), Text.t("battle.pop.level_up", {"level": event.level}), COLOR_LEVEL_UP)
	await after(0.5)


## 進化先を選べるようになった。光と知らせだけ（選択肢は、再生が終わったあとに _refresh が出す）。
func _play_evolution_offered(event: EvolutionOfferedEvent) -> void:
	var view := _view(event.unit_id)
	_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_EVOLUTION, 1.6)
	_pop_number(view.position + Vector3(0.0, 0.6, 0.0), Text.t("battle.pop.evolution_ready"), COLOR_EVOLUTION)
	await after(0.4)


## 進化した。札に印を付け、HP のバーを新しい最大 HP で描き直し、進化先の名前を出す。
func _play_evolved(event: UnitEvolvedEvent) -> void:
	var view := _view(event.unit_id)
	view.set_evolved(event.max_hp)
	view.set_hp(event.hp)
	_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_EVOLUTION, 1.8)
	_sound(&"evolved")
	_pop_number(view.position + Vector3(0.0, 0.6, 0.0), Names.evolution(event.evolution), COLOR_EVOLUTION)
	await after(0.6)


## スキルで跳んだ（シャドウステップ）。その場で縮んで消え、着いたマスに現れる。
func _play_teleported(event: UnitTeleportedEvent) -> void:
	await _blink([[_view(event.unit_id), event.to]])


## 2 体の位置が入れ替わった（シャドウステップ）。2 体とも同時に消えて、互いのマスに現れる。
func _play_swapped(event: UnitsSwappedEvent) -> void:
	await _blink([[_view(event.unit_id), event.other_from], [_view(event.other_id), event.from]])


## 駒を、間を通さずに別のマスへ移す。moves は [駒の見た目, 行き先のマス] の列（同時に移す）。
func _blink(moves: Array[Array]) -> void:
	var color := Color("b98cff")
	var shrink := create_tween().set_parallel()
	for move in moves:
		var view: UnitView = move[0]
		_flash(view.position, color, 0.9)
		shrink.tween_property(view, "scale", Vector3.ONE * 0.05, 0.14)
	await shrink.finished
	var grow := create_tween().set_parallel()
	for move in moves:
		var view: UnitView = move[0]
		view.position = BoardView.cell_center(move[1])
		_flash(view.position, color, 0.9)
		grow.tween_property(view, "scale", Vector3.ONE, 0.14)
	_rig.focus_on((moves[0][0] as UnitView).position)
	await grow.finished


## 行動済みの駒が、行動前に戻った（アドレナリン注射）。行動済みの見た目を戻し、光と知らせを出す。
func _play_reactivated(event: UnitReactivatedEvent) -> void:
	var view := _view(event.unit_id)
	view.set_acted(false)
	_flash(view.position, Color("ffd24a"), 0.9)
	_pop_number(view.position + Vector3(0.0, 0.3, 0.0), Text.t("battle.pop.refreshed"), Color("ffd24a"))
	await after(0.25)


## 聖域（フェーズの始め）も、光と数を出す。
func _play_sanctuary_healed(event: SanctuaryHealedEvent) -> void:
	await _play_heal(event, true)


func _play_defeated(event: UnitDefeatedEvent) -> void:
	var view := _view(event.unit_id)
	_views.erase(event.unit_id)
	_sound(&"defeated")
	await view.play_death()


## 中立の駒が結晶泉に湧いた（中ボスが現れた。骨起こしで骸骨兵が起きた）。光とともに、小さい形から大きくする。
## 行動済みで現れた駒（骨起こし）は、行動済みの姿で置く。
func _play_spawned(event: UnitSpawnedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var view: UnitView = UnitView.new()
	view.position = at
	_stage.add_child(view)
	view.setup(event.kind, team_colors[event.side], event.hp, event.max_hp)
	view.face(BoardView.cell_center(event.cell + Vector2i.DOWN) - at)
	if event.acted:
		view.set_acted(true)
	_views[event.unit_id] = view
	if not _quiet_playback:
		_rig.focus_on(at)
	_flash(at + Vector3(0.0, 0.4, 0.0), team_colors[event.side], 1.6)
	if event.kind == Neutral.MID_BOSS_KIND:
		_sound(&"boss_roar")
	view.scale = Vector3.ONE * 0.05
	var grow := create_tween()
	grow.tween_property(view, "scale", Vector3.ONE, 0.3)
	await grow.finished
