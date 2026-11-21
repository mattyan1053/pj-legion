extends RefCounted
## 対戦のログ（docs/battle-log.md）。起きたこと（BattleEvent）を順に食わせて、読める行の列にする。ノードに依存しない。
##
## 対戦の状態は読まない（数え始めに盤上の駒と盤面を控えることだけ。BattleStats と同じ）。駒の名前・陣営・いるマスは、
## 控えた駒をイベントで追いかけて知る（倒れた駒も、名前は残る）。
## どのイベントをどう読むかは readers() の表に載せる。載っていない種類があると、テストが落ちる。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")

const NO_CELL := Vector2i(-1, -1)
const WIN_TEXTS := {
	GameWonEvent.Reason.KING_DEFEATED: "battle.log.won.king_defeated",
	GameWonEvent.Reason.HQ_CAPTURED: "battle.log.won.hq_captured",
	GameWonEvent.Reason.TURNS_HELD: "battle.log.won.turns_held",
	GameWonEvent.Reason.ROUTED: "battle.log.won.routed",
	GameWonEvent.Reason.BOSS_SLAIN: "battle.log.won.boss_slain",
}
const DRAW_TEXTS := {
	GameDrawnEvent.Reason.BOTH_KINGS_DEFEATED: "battle.log.drawn.both_kings_defeated",
}


## ログの 1 行。header が真なら、フェーズの区切り（「ターン 3　プレイヤー1（青）の番」）。
## side は色を付ける陣営（行の主の陣営。決まらなければ -1）。details は、まとめた続きの行（スキルで当たった駒など）。
## cell はその出来事のあったマス（無ければ NO_CELL）、unit_ids は関わった駒。行を選んだとき、ここへカメラを寄せ、駒を示す。
class Entry:
	extends RefCounted
	var turn: int
	var phase: int
	var header := false
	var side := -1
	var text := ""
	var details: Array[String] = []
	var cell := NO_CELL
	var unit_ids: Array[int] = []

	func _init(turn_: int, phase_: int) -> void:
		turn = turn_
		phase = phase_

	## 画面に出す文（続きの行も含める）。
	func full_text() -> String:
		var lines: Array[String] = [text]
		for detail in details:
			lines.append(Text.t("battle.log.detail", {"text": detail}))
		return "\n".join(lines)


## 控えている駒 1 体（名前と、いまいるマス）。
class Known:
	extends RefCounted
	var kind: UnitKind.Id
	var side: Unit.Side
	var evolution := Evolution.Id.NONE
	var cell: Vector2i

	func _init(kind_: UnitKind.Id, side_: Unit.Side, cell_: Vector2i) -> void:
		kind = kind_
		side = side_
		cell = cell_


var entries: Array[Entry] = []
## 見出しに出す陣営の名前（プレイヤー番号ごと。中立は「中立」）。
var side_names: Array[String] = [
	Names.side(Unit.Side.PLAYER1), Names.side(Unit.Side.PLAYER2), Names.side(Unit.Side.NEUTRAL),
]

var _board: Board
var _turn := 1
var _phase := Unit.Side.PLAYER1
var _units: Dictionary[int, Known] = {}
## 前に take_changes() してから書き換えた、いちばん前の行の番号（画面は、そこから先を作り直す）。
var _changed_from := 0
## まとめ先の行（スキル・必殺技・樽の爆発）。続く効果（当たった駒、置いた効果、付いた状態）を、この行の続きに書く。
var _group: Entry = null
## まとめ先の行に書いた状態（Status.Type -> [続きの行の番号, 名前の列, ターン数]）。
var _group_statuses := {}
## まとめ先の行の主（スキルを使った駒。必殺技なら 0）。
var _group_user := 0
## 駒の番号 -> このフェーズの、いちばん最近の移動の行の控え（[行, 出発したマス, 巡航か, ポータルを通ったか]）。
var _moves := {}
## このフェーズに、移動のほかに何かした（攻撃・回復・スキル）駒。待機の行を出すかを決める。
var _did_something := {}
## 倒れたことを、もうダメージの行に書いた駒と、壊れたことを書いた盾。
var _noted_defeats := {}
var _noted_effects := {}
## 盤の上の効果の番号 -> [種類, 陣営, 中心のマス]（消えたときのイベントは陣営を持たない）。
var _effects := {}
## 直前の行が、湧いた駒の行なら、その種類（続けて湧いたぶんを 1 行にまとめる）。湧いたマスの控え。
var _spawn_kind := -1
var _spawn_cells: Array[Vector2i] = []
## 直前のイベントが移動の取り消しか（取り消しで戻った状態は、書かない）。
var _undoing := false


## battle の数え始め（ふつうは始まる前）。盤上の駒と盤面を控え、いまのフェーズの見出しを置く。
## names は見出しに出す陣営の名前（プレイヤー1、プレイヤー2 の順。CPU なら、そう書いたもの）。空なら既定の名前。
func _init(battle: Battle, names: Array[String] = []) -> void:
	if names.size() >= 2:
		side_names = [names[0], names[1], Names.side(Unit.Side.NEUTRAL)]
	_board = battle.board
	for unit in battle.units:
		var known := Known.new(unit.kind, unit.side, unit.cell)
		known.evolution = unit.evolution
		_units[unit.id] = known
	_start_phase(battle.turn, battle.phase)
	# 始めからゲージがたまっている陣営（対戦モードの先手、ゲージの手前から始める話）は、そう書いておく。
	if battle.turn == 1 and battle.phase == Unit.Side.PLAYER1:
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			if Ults.of(battle, side) != null and Ults.gauge(battle, side) > 0:
				_line(Text.t("battle.log.start_gauge", {"side": Names.side_word(side), "percent": Ults.percent(battle, side)}), side)


## イベントの種類（スクリプト）-> 読むメソッドの名前。rules/events/ のイベントは、すべてここに載せる。
## 行にしない（ほかの行に書いたことと重なる、細かすぎる）種類は &"_skip" にする。なぜ省くかは docs/battle-log.md。
static func readers() -> Dictionary:
	return {
		PhaseStartedEvent: &"_read_phase_started",
		UnitMovedEvent: &"_read_moved",
		UnitWarpedEvent: &"_read_warped",
		MoveUndoneEvent: &"_read_undone",
		UnitActedEvent: &"_read_acted",
		AttackDamagedEvent: &"_read_attack_damaged",
		SmokeBlockedEvent: &"_read_smoke_blocked",
		SkillUsedEvent: &"_read_skill_used",
		SkillDamagedEvent: &"_read_effect_damaged",
		ExplosionDamagedEvent: &"_read_effect_damaged",
		BarrelExplodedEvent: &"_read_barrel_exploded",
		BarricadeDamagedEvent: &"_read_barricade_damaged",
		BarricadePlacedEvent: &"_read_field_effect_placed",
		AreaEffectPlacedEvent: &"_read_field_effect_placed",
		FieldEffectRemovedEvent: &"_read_field_effect_removed",
		UnitTeleportedEvent: &"_read_teleported",
		UnitsSwappedEvent: &"_read_swapped",
		UnitReactivatedEvent: &"_read_reactivated",
		HealerHealedEvent: &"_read_healer_healed",
		SpringHealedEvent: &"_read_healed",
		RegenerationHealedEvent: &"_read_healed",
		SanctuaryHealedEvent: &"_read_healed",
		StatusAppliedEvent: &"_read_status_applied",
		UltUsedEvent: &"_read_ult_used",
		UltReadyEvent: &"_read_ult_ready",
		UnitDefeatedEvent: &"_read_defeated",
		MidBossDefeatedEvent: &"_read_mid_boss_defeated",
		RelicGainedEvent: &"_read_relic_gained",
		UnitSpawnedEvent: &"_read_spawned",
		LevelUpEvent: &"_read_level_up",
		UnitEvolvedEvent: &"_read_evolved",
		CaptureProgressEvent: &"_read_capture",
		GameWonEvent: &"_read_won",
		GameDrawnEvent: &"_read_drawn",
		# 行にしないもの。
		ExperienceGainedEvent: &"_skip",  # 毎回の経験値は細かすぎる。レベルアップの行で足りる
		EvolutionOfferedEvent: &"_skip",  # 選んだ進化先の行（UnitEvolvedEvent）で足りる
		FieldEffectTickedEvent: &"_skip",  # 残りのターン数が減るだけ。消えたときに書く
		SkillReadyEvent: &"_skip",  # 毎フェーズの細かいこと。駒の情報で分かる
		StatusRemovedEvent: &"_skip",  # 防いだ・外れたことは、ダメージの行と移動の行で分かる
	}


func feed_all(events: Array[BattleEvent]) -> void:
	for event in events:
		feed(event)


## 起きたことを 1 つ読む。Battle.apply() が返した順に食わせる
## （画面は再生した順に食わせる。中立の動くだけの駒をまとめて同時に流しても、駒ごとの順は保たれる）。
func feed(event: BattleEvent) -> void:
	var kind: Script = event.get_script()
	var method: StringName = readers().get(kind, &"")
	if method == &"":
		push_error("ログに読み方の無いイベント: %s" % kind.resource_path)
		return
	call(method, event)
	if not event is UnitSpawnedEvent:
		_spawn_kind = -1
	_undoing = event is MoveUndoneEvent or (_undoing and (event is CaptureProgressEvent or event is StatusAppliedEvent))


## 前に呼んでから書き換えた、いちばん前の行の番号を返し、覚えを空にする（画面は、そこから先を作り直す）。
## 書き換えていなければ entries.size()。
func take_changes() -> int:
	var from := _changed_from
	_changed_from = entries.size()
	return from


## 盤の上の効果の名前（「青の盾」。だれのものか分からなければ「盾」）。
func _effect_name(type: FieldEffect.Type, owner: int) -> String:
	if owner < 0:
		return Names.field_effect(type)
	return Text.t("battle.log.effect_owned", {"side": Names.side_word(owner as Unit.Side), "effect": Names.field_effect(type)})


## 駒の名前（「青のパラディン」。進化していれば進化先の名前。中立の駒には陣営を付けない）。知らない駒は「駒」。
func unit_name(unit_id: int) -> String:
	var known: Known = _units.get(unit_id)
	if known == null:
		return Text.t("battle.log.unknown_unit")
	var name := Names.kind(known.kind) if known.evolution == Evolution.Id.NONE else Names.evolution(known.evolution)
	return name if known.side == Unit.Side.NEUTRAL else Text.t("battle.log.unit", {"side": Names.side_word(known.side), "unit": name})


## 中ボスの呼び方（「左の中ボス」）。中ボスは左右（中央平原・迷宮回廊）か上下（双子結晶）に 1 体ずつ。番号 0 が左か上。
static func mid_boss_place(board: Board, boss_index: int) -> String:
	var cells := board.mid_boss_cells
	var stacked := cells.size() == 2 and absi(cells[0].y - cells[1].y) > absi(cells[0].x - cells[1].x)
	if boss_index == 0:
		return Text.t("battle.log.boss_place.top") if stacked else Text.t("battle.log.boss_place.left")
	return Text.t("battle.log.boss_place.bottom") if stacked else Text.t("battle.log.boss_place.right")


static func cell_text(cell: Vector2i) -> String:
	return Text.t("common.cell", {"x": cell.x, "y": cell.y})


## 対戦の途中の会話の台詞を 1 行に書く（battle_cues.gd。イベントではないので、画面が台詞を出すときに呼ぶ）。
func say(speaker: String, text: String, side: int) -> void:
	_group = null
	_line(Text.t("battle.log.say", {"speaker": speaker, "text": text}), side)


# ---- 行の足し方 ----


func _line(text: String, side: int, cell := NO_CELL, unit_ids: Array[int] = []) -> Entry:
	var entry := Entry.new(_turn, _phase)
	entry.text = text
	entry.side = side
	entry.cell = cell
	entry.unit_ids = unit_ids.duplicate()
	entries.append(entry)
	return entry


## まとめ先の行があれば、その続きに書く。無ければ 1 行にする。
func _detail(text: String, side: int, cell := NO_CELL, unit_ids: Array[int] = []) -> void:
	if _group == null:
		_line(text, side, cell, unit_ids)
		return
	_group.details.append(text)
	for unit_id in unit_ids:
		if not _group.unit_ids.has(unit_id):
			_group.unit_ids.append(unit_id)
	_touch(_group)


## 行を書き換えたことを覚える。
func _touch(entry: Entry) -> void:
	var index := entries.rfind(entry)
	if index >= 0:
		_changed_from = mini(_changed_from, index)


func _begin_group(entry: Entry, user_id := 0) -> void:
	_group = entry
	_group_user = user_id
	_group_statuses = {}


func _side_of(unit_id: int) -> int:
	var known: Known = _units.get(unit_id)
	return known.side if known != null else -1


func _cell_of(unit_id: int) -> Vector2i:
	var known: Known = _units.get(unit_id)
	return known.cell if known != null else NO_CELL


func _set_cell(unit_id: int, cell: Vector2i) -> void:
	var known: Known = _units.get(unit_id)
	if known != null:
		known.cell = cell


## 「12 ダメージ、残り HP 8」。倒れたら「12 ダメージ、倒した」（攻撃した側から。by_attack が偽なら「倒れた」）。防がれたら「バリアで防がれた」（「防いだ」）。
func _damage_text(hit: UnitDamagedEvent, by_attack: bool) -> String:
	if hit.is_blocked():
		var blocked := "battle.log.damage.attack.blocked" if by_attack else "battle.log.damage.effect.blocked"
		return Text.t(blocked, {"status": Names.status(hit.blocked_by as Status.Type)})
	var text := ""
	if hit.hp <= 0:
		text = Text.t("battle.log.damage.attack.defeated" if by_attack else "battle.log.damage.effect.defeated", {"amount": hit.amount})
		_noted_defeats[hit.unit_id] = true
	else:
		text = Text.t("battle.log.damage.left", {"amount": hit.amount, "hp": hit.hp})
	var notes: Array[String] = []
	if hit.critical:
		notes.append(Text.t("battle.log.note.critical"))
	if hit.forest:
		notes.append(Text.t("battle.log.note.forest"))
	return text + Text.notes(notes)


# ---- 読み方 ----


## 行にしないイベント（readers() の表に、省く理由とともに載せる）。
func _skip(_event: BattleEvent) -> void:
	pass


func _start_phase(turn: int, side: Unit.Side) -> void:
	# 何も起きなかった中立のフェーズの見出しは、残さない（ほとんどのフェーズがそうで、区切りが増えるだけ）。
	if not entries.is_empty() and entries[-1].header and entries[-1].phase == Unit.Side.NEUTRAL:
		entries.remove_at(entries.size() - 1)
		_changed_from = mini(_changed_from, entries.size())
	_turn = turn
	_phase = side
	_group = null
	_moves.clear()
	_did_something.clear()
	var entry := _line(Text.t("battle.log.phase", {"turn": turn, "side": side_names[side]}), side)
	entry.header = true


func _read_phase_started(event: PhaseStartedEvent) -> void:
	_start_phase(event.turn, event.side)


func _read_moved(event: UnitMovedEvent) -> void:
	_group = null
	if event.path.is_empty():
		return
	var to: Vector2i = event.path[-1]
	_set_cell(event.unit_id, to)
	# ポータルを通った移動は、歩く・転移・続きを歩く、に分かれて来る。続きの区間は、同じ行に書き足す。
	var move: Array = _moves.get(event.unit_id, [])
	if not move.is_empty() and move[3] and (move[0] as Entry).cell == event.path[0]:
		move[2] = move[2] or event.cruise  # 転移のあとの続きを巡航にした
		_redo_move(event.unit_id, to)
		return
	if event.path.size() < 2:
		return
	var entry := _line("", _side_of(event.unit_id), to, [event.unit_id])
	_moves[event.unit_id] = [entry, event.path[0], event.cruise, false, false]
	_redo_move(event.unit_id, to)


func _read_warped(event: UnitWarpedEvent) -> void:
	_group = null
	_set_cell(event.unit_id, event.to)
	var move: Array = _moves.get(event.unit_id, [])
	if move.is_empty() or (move[0] as Entry).cell != event.from:
		# 歩かずにポータルへ入った（ポータルのマスから動き出した）。
		var entry := _line("", _side_of(event.unit_id), event.to, [event.unit_id])
		move = [entry, event.from, event.cruise, true, false]
		_moves[event.unit_id] = move
	move[3] = true
	_redo_move(event.unit_id, event.to)


## 移動の行を書き直す。「青のパラディン が (1, 2) → (5, 6) へ移動して待機（巡航・ポータル経由）」。
func _redo_move(unit_id: int, to: Vector2i, waited := false) -> void:
	var move: Array = _moves[unit_id]
	var entry: Entry = move[0]
	entry.cell = to
	var notes: Array[String] = []
	if move[2]:
		notes.append(Text.t("battle.log.note.cruise"))
	if move[3]:
		notes.append(Text.t("battle.log.note.portal"))
	move[4] = move[4] or waited  # 一度「して待機」と書いたら、書き直しても残す
	var key := "battle.log.move_and_wait" if move[4] else "battle.log.move"
	entry.text = Text.t(key, {"unit": unit_name(unit_id), "from": cell_text(move[1]), "to": cell_text(to)}) + Text.notes(notes)
	_touch(entry)


## 移動を取り消した: その移動は無かったことにする（行を消す）。
func _read_undone(event: MoveUndoneEvent) -> void:
	_group = null
	_set_cell(event.unit_id, event.to)
	var move: Array = _moves.get(event.unit_id, [])
	_moves.erase(event.unit_id)
	var index := entries.rfind(move[0]) if not move.is_empty() else -1
	if index < 0:
		_line(Text.t("battle.log.undo", {"unit": unit_name(event.unit_id)}), _side_of(event.unit_id), event.to, [event.unit_id])
		return
	entries.remove_at(index)
	_changed_from = mini(_changed_from, index)


## 行動を終えた。移動のほかに何もしていなければ、待機と書く（動いていれば、移動の行に「して待機」と書き足す）。
func _read_acted(event: UnitActedEvent) -> void:
	_group = null
	var unit_id := event.unit_id
	if not _did_something.has(unit_id):
		if _moves.has(unit_id):
			var move: Array = _moves[unit_id]
			_redo_move(unit_id, (move[0] as Entry).cell, true)
		else:
			_line(Text.t("battle.log.wait", {"unit": unit_name(unit_id)}), _side_of(unit_id), _cell_of(unit_id), [unit_id])
	_moves.erase(unit_id)
	_did_something.erase(unit_id)


func _read_attack_damaged(event: AttackDamagedEvent) -> void:
	_group = null
	_did_something[event.attacker_id] = true
	var text := Text.t("battle.log.attack", {
		"attacker": unit_name(event.attacker_id), "target": unit_name(event.unit_id), "result": _damage_text(event, true),
	})
	_line(text, _side_of(event.attacker_id), _cell_of(event.unit_id), [event.attacker_id, event.unit_id])


func _read_smoke_blocked(event: SmokeBlockedEvent) -> void:
	_group = null
	_did_something[event.attacker_id] = true
	var text := Text.t("battle.log.attack_smoked", {"attacker": unit_name(event.attacker_id), "target": unit_name(event.target_id)})
	_line(text, _side_of(event.attacker_id), _cell_of(event.target_id), [event.attacker_id, event.target_id])


func _read_skill_used(event: SkillUsedEvent) -> void:
	_did_something[event.unit_id] = true
	var text := Text.t("battle.log.skill", {"unit": unit_name(event.unit_id), "skill": Names.skill(Skills.by_id(event.skill))})
	if event.target != _cell_of(event.unit_id):
		text += Text.paren(cell_text(event.target))
	_begin_group(_line(text, _side_of(event.unit_id), event.target, [event.unit_id]), event.unit_id)


## スキル・樽の爆発のダメージ。まとめ先（スキルの行、爆発の行）の続きに書く。
func _read_effect_damaged(event: UnitDamagedEvent) -> void:
	var key := "battle.log.effect_blocked" if event.is_blocked() else "battle.log.effect_damage"
	var text := Text.t(key, {"unit": unit_name(event.unit_id), "result": _damage_text(event, false)})
	_detail(text, _side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


func _read_barrel_exploded(event: BarrelExplodedEvent) -> void:
	_did_something[event.attacker_id] = true
	var key := "battle.log.barrel_alone" if event.victim_ids.is_empty() else "battle.log.barrel"
	var text := Text.t(key, {"attacker": unit_name(event.attacker_id), "cell": cell_text(event.cell)})
	_begin_group(_line(text, _side_of(event.attacker_id), event.cell, [event.attacker_id]))


func _read_barricade_damaged(event: BarricadeDamagedEvent) -> void:
	_group = null
	_did_something[event.attacker_id] = true
	var owner: int = _effects.get(event.effect_id, [FieldEffect.Type.BARRICADE, -1])[1]
	var args := {"attacker": unit_name(event.attacker_id), "effect": _effect_name(FieldEffect.Type.BARRICADE, owner),
			"amount": event.amount, "durability": event.durability}
	var text := Text.t("battle.log.barricade_hit", args)
	if event.durability <= 0:
		text = Text.t("battle.log.barricade_broken", args)
		_noted_effects[event.effect_id] = true
	_line(text, _side_of(event.attacker_id), event.cell, [event.attacker_id])


func _read_field_effect_placed(event: FieldEffectPlacedEvent) -> void:
	_effects[event.effect_id] = [event.type, event.side, event.center]
	var args := {"side": Names.side_word(event.side), "effect": Names.field_effect(event.type), "cell": cell_text(event.center)}
	# まとめ先（スキルの行）が無ければ、だれが置いたかを書く（_by）。
	var key := "battle.log.area_placed" if _group != null else "battle.log.area_placed_by"
	if event is BarricadePlacedEvent:
		key = "battle.log.barricade_placed" if _group != null else "battle.log.barricade_placed_by"
		args["durability"] = (event as BarricadePlacedEvent).durability
	else:
		args["turns"] = (event as AreaEffectPlacedEvent).turns_left
	var text := Text.t(key, args)
	_detail(text, event.side, event.center)


func _read_field_effect_removed(event: FieldEffectRemovedEvent) -> void:
	var known: Array = _effects.get(event.effect_id, [event.type, -1, NO_CELL])
	_effects.erase(event.effect_id)
	if _noted_effects.has(event.effect_id):
		_noted_effects.erase(event.effect_id)
		return
	var owner: int = known[1]
	var key := "battle.log.effect_destroyed" if event.reason == FieldEffectRemovedEvent.Reason.DESTROYED else "battle.log.effect_expired"
	_line(Text.t(key, {"effect": _effect_name(event.type, owner)}), owner, known[2])


func _read_teleported(event: UnitTeleportedEvent) -> void:
	_set_cell(event.unit_id, event.to)
	_detail(Text.t("battle.log.warped", {"unit": unit_name(event.unit_id), "from": cell_text(event.from), "to": cell_text(event.to)}),
		_side_of(event.unit_id), event.to, [event.unit_id])


func _read_swapped(event: UnitsSwappedEvent) -> void:
	_set_cell(event.unit_id, event.other_from)
	_set_cell(event.other_id, event.from)
	_detail(Text.t("battle.log.swapped", {"unit": unit_name(event.unit_id), "other": unit_name(event.other_id)}),
		_side_of(event.unit_id), event.other_from, [event.unit_id, event.other_id])


func _read_reactivated(event: UnitReactivatedEvent) -> void:
	_moves.erase(event.unit_id)
	_did_something.erase(event.unit_id)
	_detail(Text.t("battle.log.refreshed", {"unit": unit_name(event.unit_id)}), _side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


func _read_healer_healed(event: HealerHealedEvent) -> void:
	_group = null
	_did_something[event.healer_id] = true
	var text := Text.t("battle.log.heal", {"healer": unit_name(event.healer_id), "target": unit_name(event.unit_id), "amount": event.amount, "hp": event.hp})
	_line(text, _side_of(event.healer_id), _cell_of(event.unit_id), [event.healer_id, event.unit_id])


## フェーズの始めの回復（泉・再生・聖域）。
func _read_healed(event: UnitHealedEvent) -> void:
	var key := "battle.log.healed.sanctuary"
	if event is SpringHealedEvent:
		key = "battle.log.healed.spring"
	elif event is RegenerationHealedEvent:
		key = "battle.log.healed.regeneration"
	_line(Text.t(key, {"unit": unit_name(event.unit_id), "amount": event.amount, "hp": event.hp}),
		_side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


## 状態が付いた。まとめ先があれば、状態ごとに 1 行にまとめる（「突撃（2 ターン）: 青の将、青のパラディン…」）。
func _read_status_applied(event: StatusAppliedEvent) -> void:
	if _undoing:
		return  # 移動を取り消して、元に戻っただけ
	var name := Names.status(event.status)
	if _group == null:
		_line(Text.t("battle.log.status", {"unit": unit_name(event.unit_id), "status": name, "turns": event.turns}), _side_of(event.unit_id),
			_cell_of(event.unit_id), [event.unit_id])
		return
	var known: Array = _group_statuses.get(event.status, [])
	if known.is_empty():
		known = [_group.details.size(), [] as Array[String], event.turns]
		_group.details.append("")
		_group_statuses[event.status] = known
	(known[1] as Array[String]).append(unit_name(event.unit_id))
	_group.details[known[0]] = Text.t("battle.log.status_group", {"status": name, "turns": known[2], "units": Text.join_comma(known[1])})
	if _group_user != 0 and known[1] == [unit_name(_group_user)]:
		_group.details[known[0]] = Text.t("battle.log.status_self", {"status": name, "turns": known[2]})  # 使った駒が自分に付けた
	if not _group.unit_ids.has(event.unit_id):
		_group.unit_ids.append(event.unit_id)
	_touch(_group)


func _read_ult_used(event: UltUsedEvent) -> void:
	var text := Text.t("battle.log.ult", {"side": Names.side_word(event.side), "ult": Names.ult(Ults.by_id(event.ult))})
	_begin_group(_line(text, event.side))


func _read_ult_ready(event: UltReadyEvent) -> void:
	_line(Text.t("battle.log.ult_ready", {"side": Names.side_word(event.side), "ult": Names.ult(Ults.by_id(event.ult))}), event.side)


func _read_defeated(event: UnitDefeatedEvent) -> void:
	_set_cell(event.unit_id, event.cell)
	if _noted_defeats.has(event.unit_id):
		_noted_defeats.erase(event.unit_id)  # ダメージの行に「倒した」と書いた
		return
	_detail(Text.t("battle.log.defeated", {"unit": unit_name(event.unit_id)}), event.side, event.cell, [event.unit_id])


func _read_mid_boss_defeated(event: MidBossDefeatedEvent) -> void:
	_group = null
	var place := mid_boss_place(_board, event.boss_index)
	if event.slayer_side < 0:
		_line(Text.t("battle.log.boss_fell", {"place": place}), -1, event.cell)
		return
	_line(Text.t("battle.log.boss_slain", {"side": Names.side_word(event.slayer_side), "place": place}), event.slayer_side, event.cell, [event.slayer_id])


func _read_relic_gained(event: RelicGainedEvent) -> void:
	_group = null
	var text := Text.t("battle.log.relic", {
		"side": Names.side_word(event.side), "relic": Names.relic(event.relic), "effect": Names.relic_summary(event.relic),
	})
	_line(text, event.side)


## 駒が湧いた。続けて湧いた同じ種類の駒は、1 行にまとめる。
func _read_spawned(event: UnitSpawnedEvent) -> void:
	_group = null
	_units[event.unit_id] = Known.new(event.kind, event.side, event.cell)
	var name := Names.kind(event.kind)
	var elite := event.kind == UnitKind.Id.ELITE_MINION  # 中ボスは「現れた」、雑兵は「湧いた」
	if _spawn_kind == event.kind and not entries.is_empty():
		var entry := entries[-1]
		_spawn_cells.append(event.cell)
		var cells: Array[String] = []
		for cell in _spawn_cells:
			cells.append(cell_text(cell))
		entry.text = Text.t("battle.log.appeared_many" if elite else "battle.log.spawned_many", {"unit": name, "count": _spawn_cells.size(), "cells": Text.join_comma(cells)})
		entry.unit_ids.append(event.unit_id)
		_touch(entry)
		return
	_spawn_kind = event.kind
	_spawn_cells = [event.cell]
	_line(Text.t("battle.log.appeared" if elite else "battle.log.spawned", {"unit": name, "cell": cell_text(event.cell)}), event.side, event.cell, [event.unit_id])


func _read_level_up(event: LevelUpEvent) -> void:
	var known: Known = _units.get(event.unit_id)
	var healer := known != null and UnitKind.role(known.kind) == UnitKind.Role.HEALER
	var gains: Array[String] = []
	for stat: Unit.Stat in Names.STATS:
		if event.gains.get(stat, 0) != 0:
			var stat_name: String = Text.t("battle.log.stat_heal") if healer and stat == Unit.Stat.POWER else Names.stat(stat)
			gains.append(Text.t("battle.log.stat_gain", {"stat": stat_name, "amount": "%+d" % event.gains[stat]}))
	var text := Text.t("battle.log.level_up", {"unit": unit_name(event.unit_id), "level": event.level}) + Text.notes(gains)
	_line(text, _side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


func _read_evolved(event: UnitEvolvedEvent) -> void:
	var before := unit_name(event.unit_id)
	var known: Known = _units.get(event.unit_id)
	if known != null:
		known.evolution = event.evolution
	_line(Text.t("battle.log.evolved", {"unit": before, "evolution": Names.evolution(event.evolution)}), _side_of(event.unit_id),
		_cell_of(event.unit_id), [event.unit_id])


func _read_capture(event: CaptureProgressEvent) -> void:
	_group = null
	var hq := _board.hq_cells[1 - event.player] if _board.hq_cells.size() == 2 else NO_CELL
	var enemy: String = Names.side_word(1 - event.player)
	var args := {"side": Names.side_word(event.player), "enemy": enemy, "turns": event.turns, "needed": Battle.CAPTURE_TURNS_TO_WIN}
	var text := Text.t("battle.log.capture", args)
	if event.turns == 0:
		text = Text.t("battle.log.capture_broken", args)
	_line(text, event.player, hq)


func _read_won(event: GameWonEvent) -> void:
	_group = null
	_line(Text.t("battle.log.won", {"side": side_names[event.winner], "reason": Text.t(WIN_TEXTS[event.reason])}), event.winner)


func _read_drawn(event: GameDrawnEvent) -> void:
	_group = null
	_line(Text.t("battle.log.drawn", {"reason": Text.t(DRAW_TEXTS[event.reason])}), -1)
