extends "res://game/battle_playback/playback_board.gd"
## スキルと必殺技、軍略、状態のイベントの再生。


## スキルを使った。対象のほうを向いて手を振り、スキルの名前をスキルの色で出す。足元にスキルの色の輪が広がり、
## スキルごとの形が対象に届く（battle_effects.gd の skill_flash）。届いてから、続くイベントが効果を見せる。
func _play_skill_used(event: SkillUsedEvent) -> void:
	var view := _view(event.unit_id)
	var at := BoardView.cell_center(event.target)
	if not at.is_equal_approx(view.position):
		view.face(at - view.position)
	_acted_with_effect = true
	_after_skill = true
	var color: Color = BattleEffects.SKILL_COLORS[event.skill]
	_pop_number(view.position + Vector3(0.0, 0.5, 0.0), Names.skill(Skills.by_id(event.skill)), color.lightened(0.45))
	_effects.skill_flash(event.skill, view.position, at)
	await after(maxf(view.play_attack(), BattleEffects.SKILL_TIME))


## スキルをまた使えるようになった。魔力解放のときだけ、駒の上に知らせる（クールダウンが明けただけのときは何も出さない。
## 残りは駒の情報とスキルのボタンに出る）。
func _play_skill_ready(event: SkillReadyEvent) -> void:
	if _in_ult_effects and _views.has(event.unit_id):
		_pop_number(_view(event.unit_id).position, Text.t("battle.pop.skill_ready"), BattleEffects.SKILL_COLORS[event.skill].lightened(0.45))


## 必殺技を使った。画面が必殺技の色に一瞬光り、必殺技の名前を大きく出す。
## 効果（駒ごとの状態など）は、続くイベントを _play_all がまとめて同時に見せる（_play_ult_effects）。
func _play_ult_used(event: UltUsedEvent) -> void:
	refresh_status.call(replay.turn, replay.phase)
	var color: Color = BattleHud.ULT_COLORS[event.ult]
	_hud.flash_screen(color)
	_sound(&"ult")  # 音の山が、続く光の柱（_play_ult_effects）に重なる
	_hud.show_banner(Text.t("battle.banner.ult", {"side": side_name.call(event.side), "ult": Names.ult(Ults.by_id(event.ult))}), color, true)
	await after(0.5)


## 必殺技の効果（必殺技のすぐあとに続く、状態が付いた・スキルが使えるようになった）を、駒ごとに順にではなく、全員に同時に見せる。
## 効果の掛かった駒に陣営の色の光の柱が立ち、それぞれの知らせが一度に出る。待つのは 1 回だけ。
func _play_ult_effects(side: Unit.Side, effects: Array[BattleEvent]) -> void:
	var points: Array[Vector3] = []
	_in_ult_effects = true
	for event in effects:
		var unit_id: int = event.get(&"unit_id")
		if _views.has(unit_id):
			points.append(_view(unit_id).position)
		_play(event)  # 待たずに始めて、同時に流す
	_in_ult_effects = false
	_effects.ult_burst(points, team_colors[side])
	await after(ULT_EFFECTS_TIME)


## 必殺技のゲージがいっぱいになった。上の帯のゲージを「READY」にする（ボタンは、自分の番に押せるようになる）。
func _play_ult_ready(_event: UltReadyEvent) -> void:
	refresh_status.call(replay.turn, replay.phase)
	_sound(&"ult_ready")


## 軍略が攻撃に効いた（docs/troop-traits.md）。軍略を持つ側の駒の上に、軍略の名前と増減の札を出す（ダメージの数の手前）。
func _play_trait_triggered(event: TraitTriggeredEvent) -> void:
	var down := Traits.shields(event.trait_id)
	var text := Text.t("battle.pop.trait_down" if down else "battle.pop.trait_up",
		{"effect": Names.troop_trait(event.trait_id), "amount": event.amount})
	_pop_number(_view(event.unit_id).position + Vector3(0.0, 0.35, 0.0), text, _trait_color(event.trait_id).lightened(0.3))
	await after(0.3)


## 補給線で回復した（docs/troop-traits.md）。回復した駒の上に、軍略の名前と回復の量を出す。
func _play_supply_healed(event: SupplyHealedEvent) -> void:
	if not _views.has(event.unit_id):
		return
	var text := Text.t("battle.pop.trait_up", {"effect": Names.troop_trait(Traits.Id.SUPPLY), "amount": event.amount})
	_pop_number(_view(event.unit_id).position + Vector3(0.0, 0.6, 0.0), text, _trait_color(Traits.Id.SUPPLY).lightened(0.3))
	await _play_heal(event, true)


## 軍略の札の色（その軍略の軍の色）。
static func _trait_color(id: int) -> Color:
	return Palette.NATION_MILITARY if Traits.army_of(id) == UnitKind.Army.MILITARY else Palette.NATION_FANTASY


## 駒に状態が付いた。状態の名前を出す（付いている状態は、駒の情報に出る）。
func _play_status_applied(event: StatusAppliedEvent) -> void:
	if _after_skill and event.status != Status.Type.FATIGUE:
		return  # スキルの名前と形が見せている（反動は、スキルの形では分からないので出す）
	_pop_number(_view(event.unit_id).position, Names.status(event.status), Color("9fd8ff"))
	await after(0.25)


## 駒の状態が外れた。使い切ったときは、ダメージや攻撃の再生が見せているので、ここでは何も出さない。
func _play_status_removed(event: StatusRemovedEvent) -> void:
	if event.reason == StatusRemovedEvent.Reason.CONSUMED:
		return
	var key := "battle.pop.status_broken" if event.reason == StatusRemovedEvent.Reason.MOVED else "battle.pop.status_expired"
	_pop_number(_view(event.unit_id).position, Text.t(key, {"status": Names.status(event.status)}), Color("b8c4d0"))
	await after(0.2)
