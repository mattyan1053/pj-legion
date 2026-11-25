extends "res://game/battle_screen/screen_rules_view.gd"
## 対戦の場面の表示の作り直し: 駒の見た目を合わせる、盤の塗り、上の帯と情報の枠、マウスの下のマスと戦闘予測。


func _add_view(unit: Unit) -> void:
	var view: UnitView = UnitView.new()
	view.position = BoardView.cell_center(unit.cell)
	add_child(view)
	view.setup(unit.kind, TEAM_COLORS[unit.side], unit.hp, unit.max_hp(), _look_of(unit))
	if unit.level > 1:
		view.set_growth(unit.level, unit.max_hp())
		view.set_hp(unit.hp)
	if unit.evolution != Evolution.Id.NONE:
		view.set_evolved(unit.max_hp())
		view.set_hp(unit.hp)
	# 敵の本陣のほうを向いて立つ。
	var enemy_hq := battle.board.hq_cells[1 - unit.side] if unit.side != Unit.Side.NEUTRAL else unit.cell + Vector2i.DOWN
	view.face(BoardView.cell_center(enemy_hq) - view.position)
	view.set_acted(unit.acted)
	_views[unit.id] = view


## 終盤に入ったら、終盤の曲へフェードで替える（1 回だけ。戻さない。新しい対戦を始めると、その対戦の曲に戻る）。
func _update_climax() -> void:
	if _climax or not SoundCatalog.climax_reached(battle, _climax_kings):
		return
	_climax = true
	context.play_scene_music(source.climax_music())


## 相手の番の下の帯のボタン（早送り・スキップ）を出すか。見ているだけの番で、再生か CPU の番を進めている間。
func _show_watch_controls() -> void:
	_hud.set_watch_controls(_watching_other() and (_ui.busy or _ui.cpu_running), fast_forward, not _playback.skipping)


## 見せずに済ませたあと、盤の見た目（駒・樽・盤の上の効果）を、いまの盤から作り直す。
func _sync_views() -> void:
	for id: int in _views.keys():
		(_views[id] as UnitView).queue_free()
	_views.clear()  # 再生と同じ辞書なので、作り直さずに空ける
	for unit in battle.units:
		_add_view(unit)
	for cell in _board_view.barrel_cells():
		if not battle.board.barrel_cells.has(cell):
			_board_view.remove_barrel(cell)
	var effect_ids: Array[int] = []
	for effect in battle.board.field_effects:
		effect_ids.append(effect.id)
		if not _board_view.field_effect_ids().has(effect.id):
			_board_view.add_field_effect(effect.id, effect.type, effect.side, effect.cells, effect.durability)
		elif effect.type == FieldEffect.Type.BARRICADE:
			_board_view.set_barricade_durability(effect.id, effect.durability)
	for id in _board_view.field_effect_ids():
		if not effect_ids.has(id):
			_board_view.remove_field_effect(id)
	_sync_stronghold_flag()
	_refresh_status(battle.turn, battle.phase)


## いまの状態と選択から、塗るマス・メニュー・文字を作り直す。
func _refresh() -> void:
	var unit := selected_unit()
	_move_cells = Queries.move_cells(battle, unit)
	_targets = Queries.attack_targets(battle, unit)
	_barrel_targets = Queries.barrel_targets(battle, unit)
	_barricade_targets = Queries.barricade_targets(battle, unit)
	_heal_targets = Queries.heal_targets(battle, unit)
	_skill_cells = Queries.skill_cells(battle, unit)
	_warp = Queries.warp_exit(battle, unit)
	_portals = Queries.reachable_portals(battle, unit)
	# 盾の上の棒を、いまの残りの耐久に合わせる（変わっていなければ描き直さない）。
	for effect in battle.board.field_effects:
		if effect.type == FieldEffect.Type.BARRICADE:
			_board_view.set_barricade_durability(effect.id, effect.durability)
	var cpu_turn := _ui.cpu_running or _is_cpu_turn()
	_ui.reconcile(
		unit != null, unit != null and battle.can_act(unit), inspected_unit() != null, battle.is_over(), cpu_turn,
		battle.can_apply(UseUltAction.new()), _can_attack(), not _heal_targets.is_empty(), not _skill_cells.is_empty()
	)
	var inspected := inspected_unit()

	_painted = {}
	if inspected != null:
		_paint_view(inspected)  # 見ている間は、見ている駒の範囲だけを塗る（選んでいる駒の範囲は、見終わると戻る）
	elif unit != null and not battle.is_over():
		if _ui.mode == Mode.SKILL:
			for cell in _skill_cells:
				_painted[cell] = COLOR_SKILL
		elif battle.can_act(unit):
			if _ui.mode == Mode.NONE:
				for cell: Vector2i in _move_cells:
					_painted[cell] = COLOR_CRUISE if _move_cells[cell] else COLOR_MOVE
				_painted.merge(_portal_paint(unit), true)
			if _ui.mode != Mode.HEAL:
				for target in _targets:
					_painted[target.cell] = COLOR_TARGET
				for cell in _barrel_targets:
					_painted[cell] = COLOR_TARGET
				for cell in _barricade_targets:
					_painted[cell] = COLOR_TARGET
			if _ui.mode != Mode.ATTACK:
				for target in _heal_targets:
					_painted[target.cell] = COLOR_HEAL
		else:
			_paint_view(unit)
	if _ui.confirming_end and inspected == null:
		# ターン終了の確かめの理由（まだ行動していない駒）は、ボタンには書かず、その駒の足元を光らせて見せる。
		for unacted in Queries.unacted_units(battle):
			_painted[unacted.cell] = COLOR_UNACTED
	_show_painted()
	var threats: Array[Vector2i] = []
	if _threat_shown and not battle.is_over():
		threats = Threat.against(battle, _viewer_side()).cells()
	_board_view.show_danger(threats)
	_hud.set_threat_button(_threat_shown)
	_ui.drop_missing_pins(func(id: int) -> bool: return battle.unit_by_id(id) != null)
	var pinned: Array = []
	if not battle.is_over():
		for id in _ui.pinned_ids:
			pinned.append(Queries.threat_cells(battle, battle.unit_by_id(id)))
	_board_view.show_pinned(pinned)

	_selection_ring.visible = unit != null
	if unit != null:
		_selection_ring.position = BoardView.cell_center(unit.cell) + Vector3(0.0, 0.04, 0.0)
	_inspect_ring.visible = inspected != null
	if inspected != null:
		_inspect_ring.position = BoardView.cell_center(inspected.cell) + Vector3(0.0, 0.04, 0.0)

	_board_view.set_marked(_ui.inspected_cell)
	# 状態（バリア、照準など）が付いている駒は、足元の輪で分かるようにする。
	for shown in battle.units:
		if _views.has(shown.id):
			_view(shown.id).set_status_mark(not Statuses.types_of(shown).is_empty())
	_refresh_traits()
	_refresh_status(battle.turn, battle.phase)
	var guide: Array[Dictionary] = []
	if not _auto_running() and not (_talk != null and _talk.is_holding()):
		guide = BattleTexts.guide(
			battle, unit, inspected_unit(), _ui.mode, cpu_turn, _ui.confirming_ult or _ui.confirming_auto,
			Queries.unacted_count(battle) if _ui.confirming_end else 0, _ui.pinned_ids.size()
		)
	_hud.set_guide(guide)
	var evolving := battle.evolving_unit()
	if evolving != null and not battle.is_over() and not cpu_turn:
		var healer := UnitKind.role(evolving.kind) == UnitKind.Role.HEALER
		var texts: Array[String] = []
		for choice in battle.options(evolving.id).evolutions:
			texts.append(BattleHud.evolution_text(choice, healer))
		_hud.show_evolution(Text.t("battle.evolution.title", {"unit": Names.kind(evolving.kind)}), texts, evolving.kind, evolving.side)
	else:
		_hud.hide_evolution()
	var unacted := Queries.unacted_count(battle)
	_hud.set_auto_button(
		not cpu_turn and not battle.is_over() and battle.phase != Unit.Side.NEUTRAL and battle.acting_unit_id == 0 and evolving == null,
		_ui.confirming_auto
	)
	if cpu_turn:
		_hud.set_end_turn(false, Text.t("battle.end_turn.auto") if battle.phase == _auto_side else Text.t("battle.end_turn.foe" if Names.story_sides else "battle.end_turn.cpu"))
	elif _ui.confirming_end:
		_hud.set_end_turn(true, Text.t("battle.end_turn.confirm"))
	else:
		var can_end := not battle.is_over() and evolving == null
		_hud.set_end_turn(can_end, Text.t("battle.hud.end_turn"), can_end and unacted == 0)
	_hud.set_menu(
		BattleTexts.menu_items(
			battle, unit, _ui.mode, _can_attack(), not _heal_targets.is_empty(), not _skill_cells.is_empty(),
			_warp
		)
		if not cpu_turn and evolving == null else []
	)
	_layout.mark_menu_dirty()
	_hud.set_ult_button(
		BattleTexts.ult_button_text(battle, _ult_side(), _ui.confirming_ult), not cpu_turn and battle.can_apply(UseUltAction.new()), _ult_summary(), _ui.confirming_ult,
		Ults.percent(battle, _ult_side()) if Ults.of(battle, _ult_side()) != null else -1, _ult_side()
	)
	_show_watch_controls()
	_update_info()


## 動ける範囲に重ねる、ポータルの塗り（マス -> 色）。範囲の中の、転移に使えるポータル（止まると「転移」を選べる）と、
## その対の出るポータルを、ポータルと同じ色で塗る（範囲は転移の先まで広げない。出るポータルの印で、どこへ出るかを見せる）。
func _portal_paint(unit: Unit) -> Dictionary:
	var result := {}
	for portal: Vector2i in _portals:
		if portal != unit.cell:
			result[portal] = portal_paint_color(portal)
		result[_portals[portal]] = portal_paint_color(portal)
	return result


## 拠点の札に、決めた確保の数 holds と拠点ごとの持ち主 owners を出す（スクリーンショットの道具用。拠点が複数のときの札の形を見る。
## いまの決まりでは拠点は盤に 1 つなので、対戦からは作れない）。次に画面を描き直すと、対戦の中身に戻る。
func show_stronghold_sample(holds: Array[int], owners: Array[int]) -> void:
	_hud.set_stronghold(holds, Stronghold.HOLDS_TO_WIN, -1, WinText.stronghold_note(battle), owners)


## 拠点の札の旗の並びが見せている、拠点ごとの持ち主（道具と検査用）。
func stronghold_sample_owners() -> Array[int]:
	return _hud.stronghold_owners()


## 塗りの色の見本を出す（スクリーンショットの道具用。景色ごとに、範囲の色が地面に沈まないかを並べて比べる）。
## samples: 種類（&"move" 移動、&"target" 攻撃の相手、&"heal" 回復、&"skill" スキル、&"path" 道、&"portal" ポータルの対、
## &"threat" 敵の全員の脅威範囲）-> マスの列。前に塗ったものは消える。
func show_paint_samples(samples: Dictionary) -> void:
	var colors := {}
	var raised := {}
	var kinds := {&"move": COLOR_MOVE, &"target": COLOR_TARGET, &"heal": COLOR_HEAL, &"skill": COLOR_SKILL, &"path": COLOR_PATH}
	for kind: StringName in samples:
		for cell: Vector2i in samples[kind]:
			if kinds.has(kind):
				colors[cell] = kinds[kind]
			elif kind == &"portal" and not battle.board.portal_exits.is_empty():
				colors[cell] = portal_paint_color(battle.board.portal_exits.keys()[0])
			# 対戦の中と同じに、ポータルの上の塗り（道を除く）は、ポータルの面に隠れないよう上に塗る（_show_painted）。
			if colors.has(cell) and battle.board.object_at(cell) == MapObject.Type.PORTAL and colors[cell] != COLOR_PATH:
				raised[cell] = true
	_board_view.show_cells(colors, raised)
	var threat: Array[Vector2i] = []
	threat.assign(samples.get(&"threat", []))
	_board_view.show_danger(threat)
	_board_view.set_grid_emphasis(true)


## ポータルの対を塗る色（ポータルの色を、塗りの濃さにしたもの）。
func portal_paint_color(portal: Vector2i) -> Color:
	return Color(BoardView.portal_color(battle.board, portal), 0.75)


## 塗っているマスの色（塗っていなければ透明）。検査用。
func painted_color(cell: Vector2i) -> Color:
	return _painted.get(cell, Color.TRANSPARENT)


## 見るだけの駒（相手、中立、行動を終えた駒）の範囲を塗る。相手の駒（中立も）は、次の番に攻撃・スキルが届くマス
## （脅威範囲）を薄い赤で。その上に、動ける範囲を白で。
func _paint_view(unit: Unit) -> void:
	if unit.side != battle.phase:
		for cell in Queries.threat_cells(battle, unit):
			_painted[cell] = COLOR_THREAT
	for cell in Queries.inspect_cells(battle, unit):
		_painted[cell] = COLOR_INSPECT


## 選んでいる駒が、いまの位置から攻撃できるもの（相手・樽・盾）があるか。
func _can_attack() -> bool:
	return not (_targets.is_empty() and _barrel_targets.is_empty() and _barricade_targets.is_empty())


## 必殺技のボタンが、どのプレイヤーのものか（_viewer_side）。
func _ult_side() -> Unit.Side:
	return _viewer_side()


## 必殺技のボタンの上に出す説明。
func _ult_summary() -> String:
	var ult := Ults.of(battle, _ult_side())
	return Names.ult_summary(ult) if ult != null else ""


## 選べる対象が自分のマスだけのスキル（自分に使うスキル）を、選んでいるか。
func _is_self_skill(unit: Unit) -> bool:
	return unit != null and _skill_cells.size() == 1 and _skill_cells[0] == unit.cell


func _refresh_status(turn: int, phase: Unit.Side) -> void:
	_update_climax()
	_sync_stronghold_flag()
	var counts: Array[int] = [
		Queries.unit_count(battle, Unit.Side.PLAYER1), Queries.unit_count(battle, Unit.Side.PLAYER2),
	]
	var relics: Array[String] = []
	var relic_notes: Array[String] = []
	var held: Array = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		held.append(Relics.held(battle, side))
		var names: Array[String] = []
		var notes: Array[String] = []
		for relic in Relics.held(battle, side):
			names.append(Names.relic_short(relic))
			notes.append(Text.t("battle.hud.relic_note", {"relic": Names.relic(relic), "effect": Names.relic_summary(relic)}))
		relics.append(Text.join_dot(names))
		relic_notes.append("
".join(notes))
	_hud.set_relics(relics, relic_notes, held)
	var trait_ids: Array[int] = []
	var trait_notes: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		trait_ids.append(Traits.of_side(battle, side))
		trait_notes.append(TraitText.band_tooltip(battle, side))
	_hud.set_traits(trait_ids, trait_notes)
	var shown: Array[bool] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		shown.append(battle.wins_by(side, GameWonEvent.Reason.HQ_CAPTURED))
	_hud.set_status(
		WinText.turn_text(turn), phase, counts, battle.capture_turns, Battle.CAPTURE_TURNS_TO_WIN, shown,
		WinText.goal_tag(battle, turn, _viewer_side()), WinText.goal_note(battle, _viewer_side()),
		WinText.goal_tag_marks(battle, _viewer_side()),
	)
	_hud.set_stronghold(battle.stronghold_holds, WinText.stronghold_goal(battle), WinText.stronghold_near(battle), WinText.stronghold_note(battle), WinText.stronghold_owners(battle))
	var percents: Array[int] = []
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var ult := Ults.of(battle, side)
		percents.append(Ults.percent(battle, side))
		names.append(Names.ult(ult) if ult != null else "")
	_hud.set_ult_gauges(percents, names)


## 塗ったマスに、マウスの下のマスまでの道か、マウスの下の樽の爆発が届くマスを重ねて出す。
func _show_painted() -> void:
	var colors := _painted
	var unit := selected_unit() if _ui.inspected_id == 0 else null  # 見ている間は、選んでいる駒の道や効果の及ぶマスを重ねない
	if unit != null and not _ui.busy and _ui.mode == Mode.SKILL:
		if _skill_cells.has(_hover_cell):
			colors = _painted.duplicate()
			for cell in Skills.of(unit).affected_cells(battle, unit, _hover_cell):
				colors[cell] = COLOR_SKILL_AREA
	elif unit != null and not _ui.busy and _barrel_targets.has(_hover_cell):
		colors = _painted.duplicate()
		for cell in MapObject.blast_cells(battle.board, _hover_cell):
			colors[cell] = BattlePlayback.COLOR_BLAST
	elif unit != null and not _ui.busy and _ui.mode == Mode.NONE and _move_cells.has(_hover_cell):
		colors = _painted.duplicate()
		for cell in Movement.search_now(battle, unit, _move_cells[_hover_cell]).path(_hover_cell):
			if cell != unit.cell:
				colors[cell] = COLOR_PATH
	# 駒のいるマスの、攻撃・回復・スキルの対象の色は、駒の足元の円盤に隠れないよう、その上に塗る。
	# ポータルの塗りは、ポータルの面に隠れないよう、いつもその上に塗る。
	var raised := {}
	for cell: Vector2i in colors:
		if colors[cell] in [COLOR_TARGET, COLOR_HEAL, COLOR_SKILL, COLOR_SKILL_AREA] and battle.unit_at(cell) != null:
			raised[cell] = true
		elif battle.board.object_at(cell) == MapObject.Type.PORTAL and colors[cell] != COLOR_PATH:
			raised[cell] = true
	_board_view.show_cells(colors, raised)
	_board_view.set_grid_emphasis(_ui.selected_id != 0 or _ui.inspected_id != 0 or not colors.is_empty())


## マウスを cell に乗せたことにする（検査用。NO_CELL で、マウスの位置に戻す）。
## いまマウスの下にある（ことにしている）マス。無ければ NO_CELL。検査用。
func hovered_cell() -> Vector2i:
	return _hover_cell


func hover(cell: Vector2i) -> void:
	_hover_forced = cell
	_update_hover()


func _update_hover() -> void:
	var cell := _cell_under_mouse() if not _hud.is_mouse_over_ui() else NO_CELL
	if _hover_forced != NO_CELL:
		cell = _hover_forced
	if not battle.board.in_bounds(cell):
		cell = NO_CELL
	if cell == _hover_cell:
		return
	_hover_cell = cell
	_board_view.set_cursor(cell)
	if not _ui.busy:
		_show_painted()
		_update_info()


## マウスの下の駒（いなければ見ている駒、選んでいる駒。それも無ければ、クリックしたマス）の情報を左下の枠に、
## マウスの下のマスの短い説明を下の帯に出す。行動の対象にマウスを乗せていれば、戦闘予測のパネルも出す（_update_forecast）。
func _update_info() -> void:
	_update_info_panel()
	# 「詳細」は、マウスを離しても枠に残る駒（見ている駒・選んでいる駒）がいるときだけ出す（ボタンへ動かす間に枠が替わらないように）。
	_hud.set_detail_button(not battle.is_over() and _detail_unit() != null)


func _update_info_panel() -> void:
	if battle.is_over():
		# 決着のあとは、リザルトの画面が前に出る。後ろの盤の駒やマスの情報は出さない（左下の枠が、リザルトのボタンに重なる）。
		_hud.show_cell("")
		_hud.hide_forecast()
		_hud.show_unit(null, "", "")
		return
	var hovered: Unit = null
	if _hover_cell != NO_CELL:
		hovered = battle.unit_at(_hover_cell)
	_hud.show_cell(BattleTexts.cell_line(battle, _hover_cell) if _hover_cell != NO_CELL else "")
	_hud.viewer_side = _viewer_side()
	_hud.side_armies = battle.armies
	_hud.battle = battle
	_update_forecast()

	var shown := hovered if hovered != null else inspected_unit()
	if shown == null:
		shown = selected_unit()
	if shown == null:
		if _ui.inspected_cell != NO_CELL:
			_hud.show_cell_info(BattleTexts.cell_title(battle, _ui.inspected_cell), BattleTexts.cell_body(battle, _ui.inspected_cell))
		else:
			_hud.show_unit(null, "", "")
		return
	if _ui.mode == Mode.SKILL and hovered == null and _ui.inspected_id == 0:
		# スキルの対象を選んでいる間は、使う駒と、スキルの説明を出す（見込みは、予測のパネル）。
		var user := selected_unit()
		var skill := Skills.of(user)
		_hud.show_unit(user, Text.t("battle.skill.choosing", {"skill": Names.skill(skill)}), Names.skill_summary(skill), false)
		return
	if _ui.menu_hover_id != &"" and selected_unit() != null and hovered == null and _hud.menu_ids().has(_ui.menu_hover_id):
		# メニューの項目にマウスを乗せている間は、その項目を押すと何が起きるかを出す。
		# 名前で分かる項目（待機など）は説明が無い。そのときは、いつもの駒の情報のまま。
		var note := BattleTexts.menu_note(_ui.menu_hover_id, selected_unit(), battle)
		if note != "":
			_hud.show_unit(selected_unit(), "", note, _ui.menu_hover_id != MENU_SKILL)
			return
	_hud.show_unit(shown, BattleTexts.unit_state(battle, shown), "")
	# 見ている（クリックした）相手の駒なら、その範囲を表示したままにするスイッチを出す。
	_hud.set_pin_switch(shown.id == _ui.inspected_id and _can_pin(shown), _ui.pinned_ids.has(shown.id))


## いまマウスを乗せている対象への行動（攻撃・樽・盾・回復・スキル）と、予測のパネルの見出し。無ければ空の列。
## 自分に使うスキルは、対象が 1 つなので、マウスを乗せなくても出す。
func _hovered_action() -> Array:
	var actor := selected_unit()
	if actor == null or _ui.inspected_id != 0 or _ui.busy or battle.is_over() or _ui.menu_hover_id != &"":
		return []
	if _ui.mode == Mode.SKILL:
		var skill := Skills.of(actor)
		var target := _hover_cell if _skill_cells.has(_hover_cell) else (actor.cell if _is_self_skill(actor) else NO_CELL)
		if target == NO_CELL:
			return []
		return [UseSkillAction.new(actor.id, target), Names.skill(skill), target]
	var hovered := battle.unit_at(_hover_cell) if _hover_cell != NO_CELL else null
	var aiming := _ui.mode == Mode.NONE or _ui.mode == Mode.ATTACK
	if hovered != null and aiming and _targets.has(hovered):
		return [AttackAction.new(actor.id, hovered.id), Text.t("battle.menu.attack"), _hover_cell]
	if hovered != null and (_ui.mode == Mode.NONE or _ui.mode == Mode.HEAL) and _heal_targets.has(hovered):
		return [HealAction.new(actor.id, hovered.id), Text.t("battle.menu.heal"), _hover_cell]
	if aiming and _barrel_targets.has(_hover_cell):
		return [AttackBarrelAction.new(actor.id, _hover_cell), Text.t("battle.forecast.barrel", {"damage": MapObject.BLAST_DAMAGE}), _hover_cell]
	if aiming and _barricade_targets.has(_hover_cell):
		return [AttackBarricadeAction.new(actor.id, _hover_cell), Text.t("battle.forecast.barricade"), _hover_cell]
	return []


## 戦闘予測のパネルを、いまの対象で作り直す（中身は Forecast.of をそのまま読む）。対象が無ければ消す。
func _update_forecast() -> void:
	var found := _hovered_action()
	if found.is_empty():
		_hud.hide_forecast()
		_layout.clear_forecast()
		return
	var action: BattleAction = found[0]
	var actor := selected_unit()
	var summary := ForecastText.summarize(battle, Forecast.of(battle, action), actor)
	_hud.show_forecast(found[1], summary)
	# パネルで隠したくないマス: 何かが起きる駒と、効果の及ぶマス（スキルの範囲、樽の爆発）。
	var avoid: Array[Vector2i] = []
	for row in summary.rows:
		var unit := battle.unit_by_id(row.unit_id)
		if unit != null:
			avoid.append(unit.cell)
	if action is UseSkillAction:
		avoid.append_array(Skills.of(actor).affected_cells(battle, actor, found[2]))
	elif action is AttackBarrelAction:
		avoid.append_array(MapObject.blast_cells(battle.board, found[2]))
	_layout.set_forecast(battle, actor, found[2], avoid)


## 戦闘予測のパネルに出している中身（出していなければ空）と、画面に占める四角。検査用。
func forecast_text() -> String:
	return _hud.forecast_text()


func forecast_rect() -> Rect2:
	_layout.place_forecast(battle, selected_unit())
	return _hud.forecast_rect()


func _cell_under_mouse() -> Vector2i:
	# 自動の対戦では、本物のマウスの位置を見ない。窓ありで回したとき（スクリーンショットや実機での確かめ）に、
	# 机の上のマウスの下のマスが、検査の乗せたこと（hover）を上書きしないように。検査は hover で乗せる。
	if context.checking == AppContext.CHECK_AUTOPLAY:
		return NO_CELL
	return _cell_at(get_viewport().get_mouse_position())


## 画面の at（px）の下にあるマス。盤の外へ外れることもある。
func _cell_at(at: Vector2) -> Vector2i:
	var camera: Camera3D = _rig.camera
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(at), camera.project_ray_normal(at))
	if hit == null:
		return NO_CELL
	var point: Vector3 = hit
	return BoardView.cell_of(point)
