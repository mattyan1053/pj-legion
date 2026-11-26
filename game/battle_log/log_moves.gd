extends "res://game/battle_log/log_base.gd"
## 対戦のログ（game/battle_log.gd）の、動きと盤の読み方: フェーズ、移動・転移・取り消し、入れ替え、盤の上の効果、樽とバリケード、現れた駒、占拠と拠点。


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
	elif event is KnotPlacedEvent:
		key = "battle.log.knot_placed"
		args["turns"] = (event as KnotPlacedEvent).turns_left
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
	var key := "battle.log.effect_expired"
	match event.reason:
		FieldEffectRemovedEvent.Reason.DESTROYED:
			key = "battle.log.effect_destroyed"
		FieldEffectRemovedEvent.Reason.UNTIED:
			key = "battle.log.knot_untied"
		FieldEffectRemovedEvent.Reason.REFORMED:
			key = "battle.log.knot_reformed"
			_reforming = true
	_line(Text.t(key, {"effect": _effect_name(event.type, owner), "unit": Names.kind(UnitKind.Id.FRAY), "cell": cell_text(known[2])}),
		owner, known[2])


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


## 駒が湧いた。続けて湧いた同じ種類の駒は、1 行にまとめる。
func _read_spawned(event: UnitSpawnedEvent) -> void:
	_group = null
	_units[event.unit_id] = Known.new(event.kind, event.side, event.cell)
	if _reforming:
		_reforming = false  # 結び目の行（「立ち直った」）に書いた
		entries[-1].unit_ids.append(event.unit_id)
		return
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


func _read_capture(event: CaptureProgressEvent) -> void:
	_group = null
	var hq := _board.hq_cells[1 - event.player] if _board.hq_cells.size() == 2 else NO_CELL
	var enemy: String = Names.side_word(1 - event.player)
	var args := {"side": Names.side_word(event.player), "enemy": enemy, "turns": event.turns, "needed": Battle.CAPTURE_TURNS_TO_WIN}
	var text := Text.t("battle.log.capture", args)
	if event.turns == 0:
		text = Text.t("battle.log.capture_broken", args)
	_line(text, event.player, hq)


func _read_stronghold(event: StrongholdProgressEvent) -> void:
	_group = null
	var args := {"side": Names.side_word(event.player), "holds": event.holds, "needed": Stronghold.HOLDS_TO_WIN}
	var key := "battle.log.stronghold" if event.holds > 0 else "battle.log.stronghold_lost"
	_line(Text.t(key, args), event.player, _board.stronghold_cell)
