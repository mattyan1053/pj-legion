extends "res://game/battle_playback/playback_units.gd"
## 盤のイベントの再生: 起爆樽、倒れた糸喰いが弾けた、盤の上の効果（盾・煙幕・聖域・結び目）、骸骨旗手の奮起、本陣の占拠と拠点の確保、中ボスと聖遺物。


## 攻撃の動きのあと、樽を消して、爆発の届いたマスを塗る（続くダメージの再生の間も塗ったまま）。
func _play_barrel_exploded(event: BarrelExplodedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	if _views.has(event.attacker_id):
		var attacker := _view(event.attacker_id)
		attacker.face(at - attacker.position)
		await _strike(attacker, at)
	_board_view.remove_barrel(event.cell)
	var colors := {event.cell: COLOR_BLAST}
	for cell in event.blast_cells:
		colors[cell] = COLOR_BLAST
	_board_view.show_cells(colors)
	_flash(at + Vector3(0.0, 0.3, 0.0), Color("ff8a2a"), 2.6)
	_sound(&"explosion")
	_pop_number(at, Text.t("battle.pop.exploded"), Color("ff8a2a"))
	await after(0.3)


## 盤の上に効果が置かれた。描いて、中心に光を出す。
func _play_field_effect_placed(event: FieldEffectPlacedEvent) -> void:
	_board_view.add_field_effect(event.effect_id, event.type, event.side, event.cells)
	var at := BoardView.cell_center(event.center)
	_flash(at + Vector3(0.0, 0.3, 0.0), team_colors[event.side], 1.2 if event.type == FieldEffect.Type.BARRICADE else 2.4)
	if not _after_skill:
		_pop_number(at, Names.field_effect(event.type), team_colors[event.side].lightened(0.4))
	await after(0.3)


## 煙幕・聖域の残りが減った。描き方は変えない（残りはマスの説明に出る）。
func _play_field_effect_ticked(_event: FieldEffectTickedEvent) -> void:
	pass


## 盤の上の効果が消えた（期間が尽きた・盾が壊れた・結び目がほどけた・結び目から立ち直った）。
func _play_field_effect_removed(event: FieldEffectRemovedEvent) -> void:
	_board_view.remove_field_effect(event.effect_id)
	var at := BoardView.cell_center(event.cells[0])
	match event.reason:
		FieldEffectRemovedEvent.Reason.DESTROYED:
			_flash(at + Vector3(0.0, 0.3, 0.0), Color("d8d0c0"), 1.4)
			_pop_number(at, Text.t("battle.pop.barricade_broken"), Color("d8d0c0"))
			await after(0.3)
		FieldEffectRemovedEvent.Reason.UNTIED:
			_flash(at + Vector3(0.0, 0.2, 0.0), Color("d8d0c0"), 1.2)
			_pop_number(at, Text.t("battle.pop.knot_untied"), Color("d8d0c0"))
			await after(0.3)
		FieldEffectRemovedEvent.Reason.REFORMED:
			_flash(at + Vector3(0.0, 0.3, 0.0), Palette.MONSTER_GLOW, 2.0)
			_pop_number(at, Text.t("battle.pop.knot_reformed"), Palette.MONSTER_GLOW)
			await after(0.3)


## 骸骨旗手が倒れ、周りの味方が奮起した。倒れたマスに「旗が倒れた」を出す（続く奮起は、状態が付いたことの再生が出す）。
func _play_rally(event: RallyEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	_flash(at + Vector3(0.0, 0.3, 0.0), Palette.MONSTER_GLOW, 2.4)
	_pop_number(at, Text.t("battle.pop.rally"), Palette.MONSTER_GLOW)
	await after(0.3)


## 糸喰いが倒れて弾けた。届いたマスを塗り、糸の色の爆発を出す（続くダメージの再生の間も塗ったまま）。
func _play_burst(event: BurstEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var colors := {event.cell: COLOR_BLAST}
	for cell in event.blast_cells:
		colors[cell] = COLOR_BLAST
	_board_view.show_cells(colors)
	_flash(at + Vector3(0.0, 0.3, 0.0), Palette.MONSTER_GLOW, 2.6)
	_sound(&"explosion")
	_pop_number(at, Text.t("battle.pop.burst"), Palette.MONSTER_GLOW)
	await after(0.3)


## 盾を攻撃した。攻撃の動きのあと、減った耐久を出す。
func _play_barricade_damaged(event: BarricadeDamagedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var attacker := _view(event.attacker_id)
	attacker.face(at - attacker.position)
	await _strike(attacker, at)
	_board_view.set_barricade_durability(event.effect_id, event.durability)
	_pop_number(at, Text.t("battle.pop.durability", {"amount": event.amount}), Color("ffe9a8"))
	await after(0.3)


## 攻撃が煙幕に阻まれた。攻撃の動きのあと、相手に灰色の光と「防いだ」を出す（HP は変わらない）。
func _play_smoke_blocked(event: SmokeBlockedEvent) -> void:
	var target := _view(event.target_id)
	var attacker := _view(event.attacker_id)
	_show_strike(event.attacker_id, attacker, target)
	attacker.face(target.position - attacker.position)
	target.face(attacker.position - target.position)
	await _strike(attacker, target.position)
	_flash(target.position + Vector3(0.0, 0.3, 0.0), BoardView.COLOR_SMOKE, 1.2)
	_pop_number(target.position, Text.t("battle.pop.smoked"), Color("d0d4da"))
	await after(0.4)


## 中ボスが倒れた（駒が消えるのは UnitDefeatedEvent が見せた）。倒した陣営を、その色で知らせる。
func _play_mid_boss_defeated(event: MidBossDefeatedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var side := BattleLog.mid_boss_place(replay.board, event.boss_index)
	if event.slayer_side < 0:
		_pop_number(at, Text.t("battle.log.boss_fell", {"place": side}))
		return
	var color: Color = team_colors[event.slayer_side]
	_flash(at + Vector3(0.0, 0.6, 0.0), color, 2.4)
	_pop_number(at, Text.t("battle.log.boss_slain", {"side": side_name.call(event.slayer_side as Unit.Side), "place": side}), color.lightened(0.4))
	await after(0.6)


## 陣営が聖遺物を受け取った。控えめに見せる: 上の帯に聖遺物の名前を出し、効果の掛かった駒の HP のバーを描き直し、
## 駒の上に小さい光と、効果（最大 HP +N など）を出す。画面を覆う演出はしない。
func _play_relic_gained(event: RelicGainedEvent) -> void:
	refresh_status.call(replay.turn, replay.phase)
	var color: Color = team_colors[event.side]
	var text := Names.relic_effect(event.relic)
	_sound(&"relic")
	for unit_id in event.unit_ids:
		if not _views.has(unit_id):
			continue
		var view := _view(unit_id)
		view.set_max_hp(event.max_hp[unit_id])
		view.set_hp(event.hp[unit_id])
		_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_RELIC, 1.0)
		_pop_number(view.position + Vector3(0.0, 0.5, 0.0), text, COLOR_RELIC)
	_hud.show_banner(Text.t("battle.banner.relic", {"side": side_name.call(event.side), "relic": Names.relic(event.relic), "effect": Names.relic_summary(event.relic)}), color)
	await after(0.7)


func _play_capture(event: CaptureProgressEvent) -> void:
	refresh_status.call(replay.turn, replay.phase)
	var hq := replay.board.hq_cells[1 - event.player]
	var text := Text.t("battle.pop.capture", {"turns": event.turns, "needed": Battle.CAPTURE_TURNS_TO_WIN}) if event.turns > 0 else Text.t("battle.pop.capture_broken")
	if event.turns > 0:
		_sound(&"capture")
	_pop_number(BoardView.cell_center(hq), text, team_colors[event.player].lightened(0.4))


## 拠点の確保が進んだ・途切れた（選べる決まり）。拠点のマスに数を出し、旗をその陣営の色にする。
## あと 1 回で勝つところまで来たら、画面の中央にも知らせる。
func _play_stronghold(event: StrongholdProgressEvent) -> void:
	refresh_status.call(replay.turn, replay.phase)
	var cell := replay.board.stronghold_cell
	var color: Color = team_colors[event.player]
	if event.holds == 0:
		_pop_number(BoardView.cell_center(cell), Text.t("battle.pop.stronghold_lost", {"side": side_name.call(event.player)}), color.lightened(0.4))
		if replay.stronghold_holds[1 - event.player] == 0:
			_board_view.set_stronghold_progress(0, Stronghold.HOLDS_TO_WIN, BoardView.COLOR_STRONGHOLD_FLAG)
		return
	_board_view.set_stronghold_progress(event.holds, Stronghold.HOLDS_TO_WIN, color)
	_sound(&"capture")
	_pop_number(BoardView.cell_center(cell), Text.t("battle.pop.stronghold", {"holds": event.holds, "needed": Stronghold.HOLDS_TO_WIN}), color.lightened(0.4))
	if event.holds == Stronghold.HOLDS_TO_WIN - 1:
		_hud.show_banner(Text.t("battle.banner.stronghold_near", {"side": side_name.call(event.player)}), color, true)
		await after(0.6)
