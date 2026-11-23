class_name BattleStats
extends RefCounted
## 1 回の対戦の戦績（docs/battle-stats.md）。起きたこと（BattleEvent）を順に食わせて数える。
##
## 対戦の状態は読まない（数え始めに盤上の駒を控えることと、ターンの数を読むことだけ）。対戦の途中でも読める。
## ルールの挙動には関わらない。食わせなくても、対戦は同じに進む。

## 決着の理由。
enum Ending {
	NONE,  ## まだ決着していない
	KING_DEFEATED,  ## 将の撃破
	HQ_CAPTURED,  ## 本陣の占拠
	TURNS_HELD,  ## 守り切った
	ROUTED,  ## 全滅させた
	DRAW,  ## 引き分け（両方の将が同時に倒れた）
	BOSS_SLAIN,  ## 中ボスの撃破
	STRONGHOLD_HELD,  ## 拠点の確保（選べる決まり）
}

## 勝った理由 -> 決着の理由。
const ENDING_OF := {
	GameWonEvent.Reason.KING_DEFEATED: Ending.KING_DEFEATED,
	GameWonEvent.Reason.HQ_CAPTURED: Ending.HQ_CAPTURED,
	GameWonEvent.Reason.TURNS_HELD: Ending.TURNS_HELD,
	GameWonEvent.Reason.ROUTED: Ending.ROUTED,
	GameWonEvent.Reason.BOSS_SLAIN: Ending.BOSS_SLAIN,
	GameWonEvent.Reason.STRONGHOLD_HELD: Ending.STRONGHOLD_HELD,
}


## 駒 1 体の戦績。
class UnitRecord:
	extends RefCounted
	var unit_id: int
	var kind: UnitKind.Id
	var side: Unit.Side
	## 敵のプレイヤーの駒（将を含む）に与えたダメージと、中立の駒（中ボスを含む）に与えたダメージ。
	## 攻撃・スキル・樽の爆発（樽を攻撃した駒のもの）を数える。量はイベントの量（残りの HP より多くてもそのまま）。
	var damage := 0
	var neutral_damage := 0
	## 敵のプレイヤーの駒から受けたダメージ（damage の裏返し。数え方は damage と同じ: 樽の爆発は樽を攻撃した駒からのもの、
	## 中立の駒から受けたものと味方から受けたものは数えない）。
	var damage_taken := 0
	## 倒した敵のプレイヤーの駒（将を含む）、倒した中立の駒（中ボスを含む）、そのうちの中ボスの数。
	var kills := 0
	var neutral_kills := 0
	var boss_kills := 0
	## 味方を回復した量（回復役の回復と、自分の置いた聖域の回復）。
	var healing := 0
	var skill_uses := 0
	var level := 1
	var evolution := Evolution.Id.NONE
	## 進化したターン（進化していなければ 0）。
	var evolved_turn := 0
	var defeated := false

	func _init(unit_id_: int, kind_: UnitKind.Id, side_: Unit.Side, level_ := 1) -> void:
		unit_id = unit_id_
		kind = kind_
		side = side_
		level = level_


## 陣営（プレイヤー）1 つの戦績。駒の戦績の合計と、陣営で数えるもの。
class SideRecord:
	extends RefCounted
	var damage := 0
	var neutral_damage := 0
	var damage_taken := 0
	var kills := 0
	var neutral_kills := 0
	var boss_kills := 0
	var healing := 0
	var skill_uses := 0
	var level_ups := 0
	var evolutions := 0
	## 倒された駒（将を除く）。
	var losses := 0
	var ult_uses := 0
	## 最初に必殺技を使ったターン（使わなければ 0）。
	var first_ult_turn := 0
	## 受け取った聖遺物（Relics.Id。受け取った順）。
	var relics: Array[Relics.Id] = []


## 駒の番号 -> 戦績。プレイヤーの駒は数え始めに、中立の駒は湧いたとき（UnitSpawnedEvent）に入る。倒れても残る。
var units: Dictionary[int, UnitRecord] = {}
## プレイヤー番号ごと。
var sides: Array[SideRecord] = [SideRecord.new(), SideRecord.new()]
## 倒れた中ボス。[倒れたターン, 中ボスの番号, 倒した陣営（いなければ -1）] の列。
var mid_bosses: Array[Array] = []
var ending := Ending.NONE
## 勝った陣営。決着していないか、引き分けなら -1。
var winner := -1
## 決着したターン。決着していなければ、いまのターン。
var turns := 1

var _battle: Battle
## 駒の番号 -> いちばん最近にその駒へダメージを与えた駒の番号（撃破を誰のものにするかに使う）。
var _last_hit_by: Dictionary[int, int] = {}
## 爆発したばかりの樽を攻撃した駒（続く爆発のダメージを、その駒のものにする）。
var _barrel_attacker := 0
## いちばん最近にスキルを使った駒（続いて置かれる聖域を、その駒のものにする）。
var _skill_user := 0
## 聖域の番号 -> 置いた駒の番号。
var _sanctuary_owners: Dictionary[int, int] = {}


## battle の数え始め（ふつうは始まる前）。盤上の駒を控える。
func _init(battle: Battle) -> void:
	_battle = battle
	turns = battle.turn
	for unit in battle.units:
		units[unit.id] = UnitRecord.new(unit.id, unit.kind, unit.side, unit.level)
		if unit.evolution != Evolution.Id.NONE:
			units[unit.id].evolution = unit.evolution


func is_over() -> bool:
	return ending != Ending.NONE


func feed_all(events: Array[BattleEvent]) -> void:
	for event in events:
		feed(event)


## 起きたことを 1 つ数える。battle.apply() が返した順に食わせる。
func feed(event: BattleEvent) -> void:
	if not is_over():
		turns = _battle.turn
	if event is UnitDamagedEvent:
		_count_damage(event as UnitDamagedEvent)
	elif event is BarrelExplodedEvent:
		_barrel_attacker = (event as BarrelExplodedEvent).attacker_id
	elif event is BurstEvent:
		_barrel_attacker = (event as BurstEvent).by_id
	elif event is UnitDefeatedEvent:
		_count_defeat(event as UnitDefeatedEvent)
	elif event is MidBossDefeatedEvent:
		var slain := event as MidBossDefeatedEvent
		mid_bosses.append([_battle.turn, slain.boss_index, slain.slayer_side])
		var slayer := _record(slain.slayer_id)
		if slayer != null and _is_player(slayer.side):
			slayer.boss_kills += 1
			sides[slayer.side].boss_kills += 1
	elif event is UnitHealedEvent:
		_count_heal(event as UnitHealedEvent)
	elif event is SkillUsedEvent:
		var used := event as SkillUsedEvent
		_skill_user = used.unit_id
		var user := _record(used.unit_id)
		if user != null:
			user.skill_uses += 1
			if _is_player(user.side):
				sides[user.side].skill_uses += 1
	elif event is FieldEffectPlacedEvent:
		var placed := event as FieldEffectPlacedEvent
		if placed.type == FieldEffect.Type.SANCTUARY:
			_sanctuary_owners[placed.effect_id] = _skill_user
	elif event is LevelUpEvent:
		var grown := event as LevelUpEvent
		var record := _record(grown.unit_id)
		if record != null:
			record.level = grown.level
			if _is_player(record.side):
				sides[record.side].level_ups += 1
	elif event is UnitEvolvedEvent:
		var evolved := event as UnitEvolvedEvent
		var record := _record(evolved.unit_id)
		if record != null:
			record.evolution = evolved.evolution
			record.evolved_turn = _battle.turn
			if _is_player(record.side):
				sides[record.side].evolutions += 1
	elif event is UltUsedEvent:
		var fired := event as UltUsedEvent
		sides[fired.side].ult_uses += 1
		if sides[fired.side].first_ult_turn == 0:
			sides[fired.side].first_ult_turn = _battle.turn
	elif event is RelicGainedEvent:
		var gained := event as RelicGainedEvent
		sides[gained.side].relics.append(gained.relic)
	elif event is UnitSpawnedEvent:
		var spawned := event as UnitSpawnedEvent
		units[spawned.unit_id] = UnitRecord.new(spawned.unit_id, spawned.kind, spawned.side)
	elif event is GameWonEvent:
		var won := event as GameWonEvent
		winner = won.winner
		ending = ENDING_OF[won.reason]
	elif event is GameDrawnEvent:
		ending = Ending.DRAW


## その陣営の MVP: 将を除く駒のうち、敵のプレイヤーの駒に与えたダメージがいちばん多い駒。
## 同じなら倒した数、中立の駒へのダメージと回復の和、倒した中ボス、倒した中立の駒の順に多いほう、
## それも同じなら番号の小さいほう。どれも 0 の駒しかいなければ null。
func mvp(side: Unit.Side) -> UnitRecord:
	var best: UnitRecord = null
	for record: UnitRecord in units.values():
		if record.side != side or record.kind == UnitKind.Id.KING:
			continue
		if record.damage == 0 and record.neutral_damage == 0 and record.healing == 0:
			continue
		if best == null or _beats(record, best):
			best = record
	return best


## その陣営の駒の戦績（番号の小さい順）。
func records_of(side: Unit.Side) -> Array[UnitRecord]:
	var found: Array[UnitRecord] = []
	for record: UnitRecord in units.values():
		if record.side == side:
			found.append(record)
	found.sort_custom(func(a: UnitRecord, b: UnitRecord) -> bool: return a.unit_id < b.unit_id)
	return found


func _count_damage(hit: UnitDamagedEvent) -> void:
	var source_id := 0
	if hit is AttackDamagedEvent:
		source_id = (hit as AttackDamagedEvent).attacker_id
	elif hit is SkillDamagedEvent:
		source_id = (hit as SkillDamagedEvent).user_id
	elif hit is ExplosionDamagedEvent:
		source_id = _barrel_attacker
	_last_hit_by[hit.unit_id] = source_id
	var source := _record(source_id)
	var target := _record(hit.unit_id)
	if source == null or target == null or not _is_player(source.side) or target.side == source.side:
		return
	if target.side == Unit.Side.NEUTRAL:
		source.neutral_damage += hit.amount
		sides[source.side].neutral_damage += hit.amount
	else:
		source.damage += hit.amount
		sides[source.side].damage += hit.amount
		target.damage_taken += hit.amount
		sides[target.side].damage_taken += hit.amount


func _count_defeat(defeated: UnitDefeatedEvent) -> void:
	var target := _record(defeated.unit_id)
	if target != null:
		target.defeated = true
	if _is_player(defeated.side) and defeated.kind != UnitKind.Id.KING:
		sides[defeated.side].losses += 1
	var killer := _record(_last_hit_by.get(defeated.unit_id, 0))
	_last_hit_by.erase(defeated.unit_id)
	if killer == null or not _is_player(killer.side) or killer.side == defeated.side:
		return
	if defeated.side == Unit.Side.NEUTRAL:
		killer.neutral_kills += 1
		sides[killer.side].neutral_kills += 1
	else:
		killer.kills += 1
		sides[killer.side].kills += 1


func _count_heal(healed: UnitHealedEvent) -> void:
	var healer_id := 0
	if healed is HealerHealedEvent:
		healer_id = (healed as HealerHealedEvent).healer_id
	elif healed is SanctuaryHealedEvent:
		healer_id = _sanctuary_owners.get((healed as SanctuaryHealedEvent).effect_id, 0)
	var healer := _record(healer_id)
	if healer == null or not _is_player(healer.side):
		return
	healer.healing += healed.amount
	sides[healer.side].healing += healed.amount


func _record(unit_id: int) -> UnitRecord:
	return units.get(unit_id)


static func _is_player(side: Unit.Side) -> bool:
	return side == Unit.Side.PLAYER1 or side == Unit.Side.PLAYER2


static func _beats(a: UnitRecord, b: UnitRecord) -> bool:
	if a.damage != b.damage:
		return a.damage > b.damage
	if a.kills != b.kills:
		return a.kills > b.kills
	if a.neutral_damage + a.healing != b.neutral_damage + b.healing:
		return a.neutral_damage + a.healing > b.neutral_damage + b.healing
	if a.boss_kills != b.boss_kills:
		return a.boss_kills > b.boss_kills
	if a.neutral_kills != b.neutral_kills:
		return a.neutral_kills > b.neutral_kills
	return a.unit_id < b.unit_id
