extends RefCounted
## 対戦のログ（docs/battle-log.md）。起きたこと（BattleEvent）を順に食わせて、読める行の列にする。ノードに依存しない。
##
## 対戦の状態は読まない（数え始めに盤上の駒と盤面を控えることだけ。BattleStats と同じ）。駒の名前・陣営・いるマスは、
## 控えた駒をイベントで追いかけて知る（倒れた駒も、名前は残る）。
## どのイベントをどう読むかは readers() の表に載せる。載っていない種類があると、テストが落ちる。

const Names := preload("res://game/names.gd")

const NO_CELL := Vector2i(-1, -1)
const WIN_TEXTS := {
	GameWonEvent.Reason.KING_DEFEATED: "敵の将を倒した",
	GameWonEvent.Reason.HQ_CAPTURED: "敵の本陣を占拠し続けた",
}
const DRAW_TEXTS := {
	GameDrawnEvent.Reason.BOTH_KINGS_DEFEATED: "両方の将が同時に倒れた",
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
			lines.append("　" + detail)
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
	Names.SIDE_NAMES[Unit.Side.PLAYER1], Names.SIDE_NAMES[Unit.Side.PLAYER2], Names.SIDE_NAMES[Unit.Side.NEUTRAL],
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
		side_names = [names[0], names[1], Names.SIDE_NAMES[Unit.Side.NEUTRAL]]
	_board = battle.board
	for unit in battle.units:
		var known := Known.new(unit.kind, unit.side, unit.cell)
		known.evolution = unit.evolution
		_units[unit.id] = known
	_start_phase(battle.turn, battle.phase)


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


## 駒の名前（「青のパラディン」。進化していれば進化先の名前。中立の駒には陣営を付けない）。知らない駒は「駒」。
func unit_name(unit_id: int) -> String:
	var known: Known = _units.get(unit_id)
	if known == null:
		return "駒"
	var name := UnitKind.display_name(known.kind) if known.evolution == Evolution.Id.NONE else Evolution.display_name(known.evolution)
	return name if known.side == Unit.Side.NEUTRAL else "%sの%s" % [Names.SIDE_WORDS[known.side], name]


## 中ボスの呼び方（「左の中ボス」）。中ボスは左右（中央平原・迷宮回廊）か上下（双子結晶）に 1 体ずつ。番号 0 が左か上。
static func mid_boss_place(board: Board, boss_index: int) -> String:
	var cells := board.mid_boss_cells
	var stacked := cells.size() == 2 and absi(cells[0].y - cells[1].y) > absi(cells[0].x - cells[1].x)
	return ("上" if stacked else "左") if boss_index == 0 else ("下" if stacked else "右")


static func cell_text(cell: Vector2i) -> String:
	return "(%d, %d)" % [cell.x, cell.y]


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


## 「12 ダメージ、残り HP 8」。倒れたら「12 ダメージ、倒した」（defeat_word）。防がれたら「バリアで防がれた」。
func _damage_text(hit: UnitDamagedEvent, defeat_word: String, blocked_word: String) -> String:
	if hit.is_blocked():
		return "%sで%s" % [Status.display_name(hit.blocked_by as Status.Type), blocked_word]
	var text := "%d ダメージ、" % hit.amount
	if hit.hp <= 0:
		text += defeat_word
		_noted_defeats[hit.unit_id] = true
	else:
		text += "残り HP %d" % hit.hp
	var notes: Array[String] = []
	if hit.critical:
		notes.append("クリティカル")
	if hit.forest:
		notes.append("森で軽減")
	if not notes.is_empty():
		text += "（%s）" % "・".join(notes)
	return text


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
	var entry := _line("ターン %d　%s の番" % [turn, side_names[side]], side)
	entry.header = true


func _read_phase_started(event: PhaseStartedEvent) -> void:
	_start_phase(event.turn, event.side)


func _read_moved(event: UnitMovedEvent) -> void:
	_group = null
	if event.path.is_empty():
		return
	var to: Vector2i = event.path[-1]
	_set_cell(event.unit_id, to)
	# ポータルを通った移動は、歩いた区間ごとに分かれて来る。続きの区間は、同じ行に書き足す。
	var move: Array = _moves.get(event.unit_id, [])
	if not move.is_empty() and move[3] and (move[0] as Entry).cell == event.path[0]:
		_redo_move(event.unit_id, to)
		return
	if event.path.size() < 2:
		return
	var entry := _line("", _side_of(event.unit_id), to, [event.unit_id])
	_moves[event.unit_id] = [entry, event.path[0], event.cruise, false]
	_redo_move(event.unit_id, to)


func _read_warped(event: UnitWarpedEvent) -> void:
	_group = null
	_set_cell(event.unit_id, event.to)
	var move: Array = _moves.get(event.unit_id, [])
	if move.is_empty() or (move[0] as Entry).cell != event.from:
		# 歩かずにポータルへ入った（ポータルのマスから動き出した）。
		var entry := _line("", _side_of(event.unit_id), event.to, [event.unit_id])
		move = [entry, event.from, event.cruise, true]
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
		notes.append("巡航")
	if move[3]:
		notes.append("ポータル経由")
	var waited_text := "して待機" if waited or entry.text.contains("して待機") else ""
	entry.text = "%s が %s → %s へ移動%s" % [unit_name(unit_id), cell_text(move[1]), cell_text(to), waited_text]
	if not notes.is_empty():
		entry.text += "（%s）" % "・".join(notes)
	_touch(entry)


## 移動を取り消した: その移動は無かったことにする（行を消す）。
func _read_undone(event: MoveUndoneEvent) -> void:
	_group = null
	_set_cell(event.unit_id, event.to)
	var move: Array = _moves.get(event.unit_id, [])
	_moves.erase(event.unit_id)
	var index := entries.rfind(move[0]) if not move.is_empty() else -1
	if index < 0:
		_line("%s が移動を取り消した" % unit_name(event.unit_id), _side_of(event.unit_id), event.to, [event.unit_id])
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
			_line("%s は待機" % unit_name(unit_id), _side_of(unit_id), _cell_of(unit_id), [unit_id])
	_moves.erase(unit_id)
	_did_something.erase(unit_id)


func _read_attack_damaged(event: AttackDamagedEvent) -> void:
	_group = null
	_did_something[event.attacker_id] = true
	var text := "%s が %s を攻撃: %s" % [
		unit_name(event.attacker_id), unit_name(event.unit_id), _damage_text(event, "倒した", "防がれた"),
	]
	_line(text, _side_of(event.attacker_id), _cell_of(event.unit_id), [event.attacker_id, event.unit_id])


func _read_smoke_blocked(event: SmokeBlockedEvent) -> void:
	_group = null
	_did_something[event.attacker_id] = true
	var text := "%s が %s を攻撃: 煙幕に阻まれた" % [unit_name(event.attacker_id), unit_name(event.target_id)]
	_line(text, _side_of(event.attacker_id), _cell_of(event.target_id), [event.attacker_id, event.target_id])


func _read_skill_used(event: SkillUsedEvent) -> void:
	_did_something[event.unit_id] = true
	var text := "%s が「%s」を使った" % [unit_name(event.unit_id), Skills.by_id(event.skill).display_name()]
	if event.target != _cell_of(event.unit_id):
		text += "（%s）" % cell_text(event.target)
	_begin_group(_line(text, _side_of(event.unit_id), event.target, [event.unit_id]), event.unit_id)


## スキル・樽の爆発のダメージ。まとめ先（スキルの行、爆発の行）の続きに書く。
func _read_effect_damaged(event: UnitDamagedEvent) -> void:
	var text := "%s に %s" % [unit_name(event.unit_id), _damage_text(event, "倒れた", "防いだ")]
	if event.is_blocked():
		text = "%s: %s" % [unit_name(event.unit_id), _damage_text(event, "", "防いだ")]
	_detail(text, _side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


func _read_barrel_exploded(event: BarrelExplodedEvent) -> void:
	_did_something[event.attacker_id] = true
	var text := "%s が %s の起爆樽を攻撃: 爆発した" % [unit_name(event.attacker_id), cell_text(event.cell)]
	if event.victim_ids.is_empty():
		text += "（巻き込まれた駒はいない）"
	_begin_group(_line(text, _side_of(event.attacker_id), event.cell, [event.attacker_id]))


func _read_barricade_damaged(event: BarricadeDamagedEvent) -> void:
	_group = null
	_did_something[event.attacker_id] = true
	var owner: int = _effects.get(event.effect_id, [FieldEffect.Type.BARRICADE, -1])[1]
	var owner_text := "%sの" % Names.SIDE_WORDS[owner] if owner >= 0 else ""
	var text := "%s が %s盾を攻撃: %d ダメージ、" % [unit_name(event.attacker_id), owner_text, event.amount]
	if event.durability <= 0:
		text += "壊した"
		_noted_effects[event.effect_id] = true
	else:
		text += "残りの耐久 %d" % event.durability
	_line(text, _side_of(event.attacker_id), event.cell, [event.attacker_id])


func _read_field_effect_placed(event: FieldEffectPlacedEvent) -> void:
	_effects[event.effect_id] = [event.type, event.side, event.center]
	var name: String = Names.FIELD_EFFECT_NAMES[event.type]
	var text := ""
	if event is BarricadePlacedEvent:
		text = "%sを %s に置いた（耐久 %d）" % [name, cell_text(event.center), (event as BarricadePlacedEvent).durability]
	else:
		text = "%sを %s のまわりに張った（%d ターン）" % [name, cell_text(event.center), (event as AreaEffectPlacedEvent).turns_left]
	if _group == null:
		text = "%s が%s" % [Names.SIDE_WORDS[event.side], text]
	_detail(text, event.side, event.center)


func _read_field_effect_removed(event: FieldEffectRemovedEvent) -> void:
	var known: Array = _effects.get(event.effect_id, [event.type, -1, NO_CELL])
	_effects.erase(event.effect_id)
	if _noted_effects.has(event.effect_id):
		_noted_effects.erase(event.effect_id)
		return
	var owner: int = known[1]
	var owner_text := "%sの" % Names.SIDE_WORDS[owner] if owner >= 0 else ""
	var verb := "壊れた" if event.reason == FieldEffectRemovedEvent.Reason.DESTROYED else "消えた"
	_line("%s%sが%s" % [owner_text, Names.FIELD_EFFECT_NAMES[event.type], verb], owner, known[2])


func _read_teleported(event: UnitTeleportedEvent) -> void:
	_set_cell(event.unit_id, event.to)
	_detail("%s が %s → %s へ移った" % [unit_name(event.unit_id), cell_text(event.from), cell_text(event.to)],
		_side_of(event.unit_id), event.to, [event.unit_id])


func _read_swapped(event: UnitsSwappedEvent) -> void:
	_set_cell(event.unit_id, event.other_from)
	_set_cell(event.other_id, event.from)
	_detail("%s と %s の位置が入れ替わった" % [unit_name(event.unit_id), unit_name(event.other_id)],
		_side_of(event.unit_id), event.other_from, [event.unit_id, event.other_id])


func _read_reactivated(event: UnitReactivatedEvent) -> void:
	_moves.erase(event.unit_id)
	_did_something.erase(event.unit_id)
	_detail("%s がもう一度行動できる" % unit_name(event.unit_id), _side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


func _read_healer_healed(event: HealerHealedEvent) -> void:
	_group = null
	_did_something[event.healer_id] = true
	var text := "%s が %s を %d 回復（HP %d）" % [unit_name(event.healer_id), unit_name(event.unit_id), event.amount, event.hp]
	_line(text, _side_of(event.healer_id), _cell_of(event.unit_id), [event.healer_id, event.unit_id])


## フェーズの始めの回復（泉・再生・聖域）。
func _read_healed(event: UnitHealedEvent) -> void:
	var source := "聖域"
	if event is SpringHealedEvent:
		source = "回復の泉"
	elif event is RegenerationHealedEvent:
		source = "再生"
	_line("%s が%sで %d 回復（HP %d）" % [unit_name(event.unit_id), source, event.amount, event.hp],
		_side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


## 状態が付いた。まとめ先があれば、状態ごとに 1 行にまとめる（「突撃（2 ターン）: 青の将、青のパラディン…」）。
func _read_status_applied(event: StatusAppliedEvent) -> void:
	if _undoing:
		return  # 移動を取り消して、元に戻っただけ
	var name := Status.display_name(event.status)
	if _group == null:
		_line("%s に%s（%d ターン）" % [unit_name(event.unit_id), name, event.turns], _side_of(event.unit_id),
			_cell_of(event.unit_id), [event.unit_id])
		return
	var known: Array = _group_statuses.get(event.status, [])
	if known.is_empty():
		known = [_group.details.size(), [] as Array[String], event.turns]
		_group.details.append("")
		_group_statuses[event.status] = known
	(known[1] as Array[String]).append(unit_name(event.unit_id))
	_group.details[known[0]] = "%s（%d ターン）: %s" % [name, known[2], "、".join(known[1])]
	if _group_user != 0 and known[1] == [unit_name(_group_user)]:
		_group.details[known[0]] = "%sが付いた（%d ターン）" % [name, known[2]]  # 使った駒が自分に付けた
	if not _group.unit_ids.has(event.unit_id):
		_group.unit_ids.append(event.unit_id)
	_touch(_group)


func _read_ult_used(event: UltUsedEvent) -> void:
	var text := "%s が必殺技「%s」を使った" % [Names.SIDE_WORDS[event.side], Ults.by_id(event.ult).display_name()]
	_begin_group(_line(text, event.side))


func _read_ult_ready(event: UltReadyEvent) -> void:
	_line("%s の必殺技「%s」が使えるようになった" % [Names.SIDE_WORDS[event.side], Ults.by_id(event.ult).display_name()], event.side)


func _read_defeated(event: UnitDefeatedEvent) -> void:
	_set_cell(event.unit_id, event.cell)
	if _noted_defeats.has(event.unit_id):
		_noted_defeats.erase(event.unit_id)  # ダメージの行に「倒した」と書いた
		return
	_detail("%s が倒れた" % unit_name(event.unit_id), event.side, event.cell, [event.unit_id])


func _read_mid_boss_defeated(event: MidBossDefeatedEvent) -> void:
	_group = null
	var place := mid_boss_place(_board, event.boss_index)
	if event.slayer_side < 0:
		_line("%sの中ボスが倒れた" % place, -1, event.cell)
		return
	_line("%s が%sの中ボスを倒した" % [Names.SIDE_WORDS[event.slayer_side], place], event.slayer_side, event.cell, [event.slayer_id])


func _read_relic_gained(event: RelicGainedEvent) -> void:
	_group = null
	var text := "%s が聖遺物「%s」を手に入れた（%s）" % [
		Names.SIDE_WORDS[event.side], Relics.display_name(event.relic), Relics.summary(event.relic),
	]
	_line(text, event.side)


## 駒が湧いた。続けて湧いた同じ種類の駒は、1 行にまとめる。
func _read_spawned(event: UnitSpawnedEvent) -> void:
	_group = null
	_units[event.unit_id] = Known.new(event.kind, event.side, event.cell)
	var name := UnitKind.display_name(event.kind)
	var verb := "現れた" if event.kind == UnitKind.Id.ELITE_MINION else "湧いた"
	if _spawn_kind == event.kind and not entries.is_empty():
		var entry := entries[-1]
		_spawn_cells.append(event.cell)
		var cells: Array[String] = []
		for cell in _spawn_cells:
			cells.append(cell_text(cell))
		entry.text = "%s が %d 体%s: %s" % [name, _spawn_cells.size(), verb, "、".join(cells)]
		entry.unit_ids.append(event.unit_id)
		_touch(entry)
		return
	_spawn_kind = event.kind
	_spawn_cells = [event.cell]
	_line("%s が %s に%s" % [name, cell_text(event.cell), verb], event.side, event.cell, [event.unit_id])


func _read_level_up(event: LevelUpEvent) -> void:
	var known: Known = _units.get(event.unit_id)
	var healer := known != null and UnitKind.role(known.kind) == UnitKind.Role.HEALER
	var gains: Array[String] = []
	for stat: Unit.Stat in Names.STAT_NAMES:
		if event.gains.get(stat, 0) != 0:
			var stat_name: String = "回復" if healer and stat == Unit.Stat.POWER else Names.STAT_NAMES[stat]
			gains.append("%s %+d" % [stat_name, event.gains[stat]])
	var text := "%s が レベル %d に上がった" % [unit_name(event.unit_id), event.level]
	if not gains.is_empty():
		text += "（%s）" % "・".join(gains)
	_line(text, _side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


func _read_evolved(event: UnitEvolvedEvent) -> void:
	var before := unit_name(event.unit_id)
	var known: Known = _units.get(event.unit_id)
	if known != null:
		known.evolution = event.evolution
	_line("%s が %s に進化した" % [before, Evolution.display_name(event.evolution)], _side_of(event.unit_id),
		_cell_of(event.unit_id), [event.unit_id])


func _read_capture(event: CaptureProgressEvent) -> void:
	_group = null
	var hq := _board.hq_cells[1 - event.player] if _board.hq_cells.size() == 2 else NO_CELL
	var enemy: String = Names.SIDE_WORDS[1 - event.player]
	var text := "%s が%sの本陣を占拠: %d / %d" % [Names.SIDE_WORDS[event.player], enemy, event.turns, Battle.CAPTURE_TURNS_TO_WIN]
	if event.turns == 0:
		text = "%s の、%sの本陣の占拠が途切れた" % [Names.SIDE_WORDS[event.player], enemy]
	_line(text, event.player, hq)


func _read_won(event: GameWonEvent) -> void:
	_group = null
	_line("%s の勝ち（%s）" % [side_names[event.winner], WIN_TEXTS[event.reason]], event.winner)


func _read_drawn(event: GameDrawnEvent) -> void:
	_group = null
	_line("引き分け（%s）" % DRAW_TEXTS[event.reason], -1)
