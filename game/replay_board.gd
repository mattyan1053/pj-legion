extends RefCounted
## 再生の盤: 再生（battle_playback.gd）が見せている盤の、いまの姿。始めの盤の写し（of）と、出来事の列（feed）だけから作る。
## ルールを動かさず、対戦（Battle）の進んだあとの状態も読まない（docs/battle-view.md の「再生の盤」）。
## 対戦の場面では、行動をルールに渡す前に写しを取り直し（場面の外で盤が変わっても、ずれを持ち越さない）、再生しながら出来事を食わせる。
## リプレイやカットシーンでは、始めの写しを 1 度だけ取り、あとは出来事だけで進める。
##
## 持つのは、盤の上で目に見えるもの（駒の位置・HP・最大 HP・レベル・進化・行動済み・状態の種類、樽、盤の上の効果、
## 本陣の占拠と拠点の確保の数、聖遺物、いまのターンと番、決着）。目に見えないもの（経験値、クールダウン、必殺技のゲージ）は持たない。


## 盤の上の駒 1 体の見え方。
class Piece:
	extends RefCounted

	var id: int
	var side: Unit.Side
	var kind: UnitKind.Id
	var cell: Vector2i
	var hp: int
	var max_hp: int
	var level := 1
	var evolution := Evolution.Id.NONE
	var acted := false
	## 付いている状態（Status.Type -> true）。
	var statuses := {}

	## 付いている状態の種類（小さい順。Statuses.types_of と同じ並び）。
	func status_types() -> Array[Status.Type]:
		var result: Array[Status.Type] = []
		result.assign(statuses.keys())
		result.sort()
		return result


## 盤の形（本陣・拠点・ポータル・中ボスの場所）。始めの写しで、樽と盤の上の効果の出入りは、この盤でなく下の欄で持つ。
var board: Board
var turn := 1
var phase := Unit.Side.PLAYER1
## 駒の番号 -> Piece（盤にいる駒だけ。倒れた駒は消える）。
var pieces: Dictionary[int, Piece] = {}
## 残っている樽のマス。
var barrels: Array[Vector2i] = []
## 盤の上の効果の番号 -> [種類, 陣営, マスの列, 耐久]。
var field_effects := {}
var capture_turns: Array[int] = [0, 0]
var stronghold_holds: Array[int] = [0, 0]
## 陣営ごとの、受け取った聖遺物（Relics.Id）の列。
var relics: Array[Array] = [[], []]
## 決着: 勝った陣営（引き分けは Unit.Side.NEUTRAL）。決着していなければ -1。
var winner := -1


## battle のいまを写す（始めの盤）。
static func of(battle: Battle) -> RefCounted:
	var result := new()
	result._take(battle)
	return result


func _take(battle: Battle) -> void:
	board = battle.board.copy()
	turn = battle.turn
	phase = battle.phase
	for unit in battle.units:
		var taken := Piece.new()
		taken.id = unit.id
		taken.side = unit.side
		taken.kind = unit.kind
		taken.cell = unit.cell
		taken.hp = unit.hp
		taken.max_hp = unit.max_hp()
		taken.level = unit.level
		taken.evolution = unit.evolution
		taken.acted = unit.acted
		for status: Status.Type in Statuses.types_of(unit):
			taken.statuses[status] = true
		pieces[unit.id] = taken
	barrels.assign(battle.board.barrel_cells)
	for effect in battle.board.field_effects:
		field_effects[effect.id] = [effect.type, effect.side, effect.cells.duplicate(), effect.durability]
	capture_turns = battle.capture_turns.duplicate()
	stronghold_holds = battle.stronghold_holds.duplicate()
	relics = [battle.relics[0].duplicate(), battle.relics[1].duplicate()]
	winner = battle.winner


func piece(unit_id: int) -> Piece:
	return pieces.get(unit_id)


## 駒 unit_id の陣営。盤にいなければ -1。
func side_of(unit_id: int) -> int:
	var found := piece(unit_id)
	return found.side if found != null else -1


## 盤にいる、陣営 side の駒の番号（小さい順）。
func ids_of(side: Unit.Side) -> Array[int]:
	var ids: Array[int] = []
	for id: int in pieces:
		if pieces[id].side == side:
			ids.append(id)
	ids.sort()
	return ids


func is_over() -> bool:
	return winner >= 0


## 起きたことを 1 つ、盤に映す（親の種類で読むものは、子もそこで読む）。
func feed(event: BattleEvent) -> void:
	if event is UnitMovedEvent:
		_moved(event)
	elif event is UnitWarpedEvent:
		_warped(event)
	elif event is UnitTeleportedEvent:
		_teleported(event)
	elif event is UnitsSwappedEvent:
		_swapped(event)
	elif event is MoveUndoneEvent:
		_undone(event)
	elif event is UnitDamagedEvent:
		_damaged(event)
	elif event is UnitHealedEvent:
		_healed(event)
	elif event is LevelUpEvent:
		_level_up(event)
	elif event is UnitEvolvedEvent:
		_evolved(event)
	elif event is RelicGainedEvent:
		_relic(event)
	elif event is UnitDefeatedEvent:
		_defeated(event)
	elif event is UnitSpawnedEvent:
		_spawned(event)
	elif event is StatusAppliedEvent:
		_status_applied(event)
	elif event is StatusRemovedEvent:
		_status_removed(event)
	elif event is UnitActedEvent:
		_acted(event)
	elif event is UnitReactivatedEvent:
		_reactivated(event)
	elif event is PhaseStartedEvent:
		_phase_started(event)
	elif event is CaptureProgressEvent:
		_capture(event)
	elif event is StrongholdProgressEvent:
		_stronghold(event)
	elif event is BarrelExplodedEvent:
		_barrel(event)
	elif event is FieldEffectPlacedEvent:
		_effect_placed(event)
	elif event is BarricadeDamagedEvent:
		_barricade_damaged(event)
	elif event is FieldEffectRemovedEvent:
		_effect_removed(event)
	elif event is GameWonEvent:
		_won(event)
	elif event is GameDrawnEvent:
		_drawn(event)


func _moved(event: UnitMovedEvent) -> void:
	if not event.path.is_empty() and pieces.has(event.unit_id):
		pieces[event.unit_id].cell = event.path[-1]


func _warped(event: UnitWarpedEvent) -> void:
	_place(event.unit_id, event.to)


func _teleported(event: UnitTeleportedEvent) -> void:
	_place(event.unit_id, event.to)


func _swapped(event: UnitsSwappedEvent) -> void:
	_place(event.unit_id, event.other_from)
	_place(event.other_id, event.from)


func _undone(event: MoveUndoneEvent) -> void:
	_place(event.unit_id, event.to)


func _place(unit_id: int, cell: Vector2i) -> void:
	if pieces.has(unit_id):
		pieces[unit_id].cell = cell


func _damaged(event: UnitDamagedEvent) -> void:
	if pieces.has(event.unit_id):
		pieces[event.unit_id].hp = event.hp


func _healed(event: UnitHealedEvent) -> void:
	if pieces.has(event.unit_id):
		pieces[event.unit_id].hp = event.hp


func _level_up(event: LevelUpEvent) -> void:
	if pieces.has(event.unit_id):
		var found := pieces[event.unit_id]
		found.level = event.level
		found.max_hp = event.max_hp
		found.hp = event.hp


func _evolved(event: UnitEvolvedEvent) -> void:
	if pieces.has(event.unit_id):
		var found := pieces[event.unit_id]
		found.evolution = event.evolution
		found.max_hp = event.max_hp
		found.hp = event.hp


func _relic(event: RelicGainedEvent) -> void:
	relics[event.side].append(event.relic)
	for unit_id in event.unit_ids:
		if pieces.has(unit_id):
			pieces[unit_id].max_hp = event.max_hp[unit_id]
			pieces[unit_id].hp = event.hp[unit_id]


func _defeated(event: UnitDefeatedEvent) -> void:
	pieces.erase(event.unit_id)


func _spawned(event: UnitSpawnedEvent) -> void:
	var found := Piece.new()
	found.id = event.unit_id
	found.side = event.side
	found.kind = event.kind
	found.cell = event.cell
	found.hp = event.hp
	found.max_hp = event.max_hp
	found.acted = event.acted
	pieces[event.unit_id] = found


func _status_applied(event: StatusAppliedEvent) -> void:
	if pieces.has(event.unit_id):
		pieces[event.unit_id].statuses[event.status] = true


func _status_removed(event: StatusRemovedEvent) -> void:
	if pieces.has(event.unit_id):
		pieces[event.unit_id].statuses.erase(event.status)


func _acted(event: UnitActedEvent) -> void:
	if pieces.has(event.unit_id):
		pieces[event.unit_id].acted = true


func _reactivated(event: UnitReactivatedEvent) -> void:
	if pieces.has(event.unit_id):
		pieces[event.unit_id].acted = false


## 番の始め: その陣営の駒は、行動前に戻る（rules/actions/end_phase_action.gd の _start_phase）。
func _phase_started(event: PhaseStartedEvent) -> void:
	turn = event.turn
	phase = event.side
	for found: Piece in pieces.values():
		if found.side == event.side:
			found.acted = false


func _capture(event: CaptureProgressEvent) -> void:
	capture_turns[event.player] = event.turns


func _stronghold(event: StrongholdProgressEvent) -> void:
	stronghold_holds[event.player] = event.holds


func _barrel(event: BarrelExplodedEvent) -> void:
	barrels.erase(event.cell)


func _effect_placed(event: FieldEffectPlacedEvent) -> void:
	var durability: int = (event as BarricadePlacedEvent).durability if event is BarricadePlacedEvent else 0
	field_effects[event.effect_id] = [event.type, event.side, event.cells.duplicate(), durability]


func _barricade_damaged(event: BarricadeDamagedEvent) -> void:
	if field_effects.has(event.effect_id):
		field_effects[event.effect_id][3] = event.durability


func _effect_removed(event: FieldEffectRemovedEvent) -> void:
	field_effects.erase(event.effect_id)


func _won(event: GameWonEvent) -> void:
	winner = event.winner


func _drawn(_event: GameDrawnEvent) -> void:
	winner = Unit.Side.NEUTRAL


# ---- 出来事の表（tests/game/test_event_readers.gd が見張る。docs/battle.md の「出来事を 1 つ足すとき」） ----


## 再生の盤が名前で読む出来事（このファイルの `is` / `as` に出てくるもの。親を読めば子も読む）。
static func read_events() -> Array[Script]:
	return [
		UnitMovedEvent,
		UnitWarpedEvent,
		UnitTeleportedEvent,
		UnitsSwappedEvent,
		MoveUndoneEvent,
		UnitDamagedEvent,
		UnitHealedEvent,
		LevelUpEvent,
		UnitEvolvedEvent,
		RelicGainedEvent,
		UnitDefeatedEvent,
		UnitSpawnedEvent,
		StatusAppliedEvent,
		StatusRemovedEvent,
		UnitActedEvent,
		UnitReactivatedEvent,
		PhaseStartedEvent,
		CaptureProgressEvent,
		StrongholdProgressEvent,
		BarrelExplodedEvent,
		FieldEffectPlacedEvent,
		BarricadePlacedEvent,
		BarricadeDamagedEvent,
		FieldEffectRemovedEvent,
		GameWonEvent,
		GameDrawnEvent,
	]


## 再生の盤が読まないと決めた出来事（新しい出来事を足したら、読むか、ここに理由と足す）。
static func skipped_events() -> Array[Script]:
	return [
		# 盤の見え方を変えない（知らせ・数字の飛び出し・光だけ。駒の出入りと HP は、続く出来事が運ぶ）
		ExperienceGainedEvent,
		EvolutionOfferedEvent,
		MidBossDefeatedEvent,
		RallyEvent,
		BurstEvent,
		SmokeBlockedEvent,
		TraitTriggeredEvent,
		SkillUsedEvent,
		UltUsedEvent,
		# 目に見えない数（残りのターン数・クールダウン・必殺技のゲージ）だけを運ぶ。再生の盤は持たない
		FieldEffectTickedEvent,
		SkillReadyEvent,
		UltReadyEvent,
	]
