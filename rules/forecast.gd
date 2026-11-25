class_name Forecast
extends RefCounted
## 戦闘予測: ある行動をいま行ったら何が起きるか（docs/battle-forecast.md）。状態は変えない。
##
## 実際の解決と同じ処理を、複製（Battle.clone()）の上で走らせる。だから予測は、直後に同じ行動をしたときの結果と一致する。
## 確率で決まるルールも複製の乱数で引くので、元の Battle.rng は進まない。
## 攻撃、樽・盾への攻撃、回復、スキル、必殺技のどれにも、同じ読み方を使う（of）。
##
## 起きたことの列（events）のほかに、画面と CPU が読みやすいように、駒ごと（units）と盾ごと（barricades）にまとめる。

## 1 体の駒に起きること。
class UnitOutcome:
	extends RefCounted
	var unit_id: int
	## 行動の前と、あとの HP と最大 HP（倒れるなら hp_after は 0）。
	var hp_before := 0
	var hp_after := 0
	var max_hp_after := 0
	## 受けるダメージの合計（防がれたぶんは 0）と、当たる回数（防がれたものも数える）。
	var damage := 0
	var hits := 0
	## ダメージの内訳: 確定クリティカルか、森で減るか、胞子（糸茸）で減るか、駒の状態に防がれるか（Status.Type。無ければ -1）、煙幕に阻まれるか。
	var critical := false
	var forest := false
	var spores := false
	var blocked_by := -1
	var smoked := false
	## 軍略（Traits）で増える・減るダメージ（Traits.Id -> 量。隊列は減る量）。
	var traits: Dictionary[int, int] = {}
	## 倒れた骸骨旗手の周りにいて、奮起するか（Monsters。付く奮起は statuses_applied にも入る）。
	var rallied := false
	## 樽の爆発に巻き込まれるか。
	var exploded := false
	var defeated := false
	## 回復で増える HP。
	var healed := 0
	## 入る経験値、上がるレベルの数、進化先を選ぶことになるか。
	var experience := 0
	var levels_gained := 0
	var evolution_ready := false
	## 付く状態（Status.Type -> 残りのターン数）と、外れる状態（Status.Type）。
	var statuses_applied: Dictionary[int, int] = {}
	var statuses_removed: Array[int] = []
	## 移る先（スキルで跳ぶ、入れ替わる）。移らなければ Board.NO_CELL。
	var moved_to := Board.NO_CELL
	## もう一度行動できるようになるか（アドレナリン注射）。
	var reactivated := false


## 盾 1 つに起きること。
class BarricadeOutcome:
	extends RefCounted
	var cell: Vector2i
	var durability_before := 0
	var durability_after := 0
	var destroyed := false


## 受け付けられる行動か。偽なら、ほかは空。
var accepted := false
var events: Array[BattleEvent] = []
## 行動のあとの状態（複製）。断られたら null。
var after: Battle
## 起きることのあった駒（イベントに出てきた順）。
var units: Array[UnitOutcome] = []
var barricades: Array[BarricadeOutcome] = []
## プレイヤーごとの必殺技のゲージ（行動の前と、あと）。
var gauge_before: Array[int] = [0, 0]
var gauge_after: Array[int] = [0, 0]
## 盤に置かれる効果（盾、煙幕、聖域、倒れたほつれの残す結び目）。
var placed: Array[FieldEffectPlacedEvent] = []
## 受け取る聖遺物（中ボスを倒すとき）。
var relics: Array[RelicGainedEvent] = []
## 決着するか。勝つ陣営（決着しない・引き分けなら -1）と、引き分けか。
var winner := -1
var drawn := false

var _by_id: Dictionary[int, UnitOutcome] = {}


## battle で action を行ったら何が起きるか。
static func of(battle: Battle, action: BattleAction) -> Forecast:
	var forecast := Forecast.new()
	forecast.gauge_before = battle.ult_gauge.duplicate()
	forecast.gauge_after = battle.ult_gauge.duplicate()
	if not battle.can_apply(action):
		return forecast
	forecast.after = battle.clone()
	var result := forecast.after.apply(action)
	forecast.accepted = result.accepted
	forecast.events = result.events
	forecast._read(battle)
	return forecast


## 駒 unit_id に起きること。何も起きなければ null。
func outcome(unit_id: int) -> UnitOutcome:
	return _by_id.get(unit_id)


## 倒れる駒の番号（イベントの順）。
func defeated_ids() -> Array[int]:
	var result: Array[int] = []
	for unit in units:
		if unit.defeated:
			result.append(unit.unit_id)
	return result


func _unit(battle: Battle, unit_id: int) -> UnitOutcome:
	if _by_id.has(unit_id):
		return _by_id[unit_id]
	var result := UnitOutcome.new()
	result.unit_id = unit_id
	var before := battle.unit_by_id(unit_id)
	var later := after.unit_by_id(unit_id)
	result.hp_before = before.hp if before != null else 0
	result.hp_after = later.hp if later != null else 0
	result.max_hp_after = later.max_hp() if later != null else (before.max_hp() if before != null else 0)
	_by_id[unit_id] = result
	units.append(result)
	return result


func _read(battle: Battle) -> void:
	gauge_after = after.ult_gauge.duplicate()
	winner = after.winner
	drawn = after.drawn
	for event in events:
		if event is UnitDamagedEvent:
			var damaged := event as UnitDamagedEvent
			var unit := _unit(battle, damaged.unit_id)
			unit.damage += damaged.amount
			unit.hits += 1
			unit.critical = unit.critical or damaged.critical
			unit.forest = unit.forest or damaged.forest
			unit.spores = unit.spores or damaged.spores
			unit.exploded = unit.exploded or damaged.cause == UnitDamagedEvent.Cause.EXPLOSION
			if damaged.is_blocked():
				unit.blocked_by = damaged.blocked_by
			for id: int in damaged.traits:
				unit.traits[id] = unit.traits.get(id, 0) + int(damaged.traits[id])
		elif event is SmokeBlockedEvent:
			var smoked := _unit(battle, (event as SmokeBlockedEvent).target_id)
			smoked.smoked = true
			smoked.hits += 1
		elif event is UnitHealedEvent:
			var healed := event as UnitHealedEvent
			_unit(battle, healed.unit_id).healed += healed.amount
		elif event is UnitDefeatedEvent:
			_unit(battle, (event as UnitDefeatedEvent).unit_id).defeated = true
		elif event is ExperienceGainedEvent:
			var gained := event as ExperienceGainedEvent
			_unit(battle, gained.unit_id).experience += gained.amount
		elif event is LevelUpEvent:
			_unit(battle, (event as LevelUpEvent).unit_id).levels_gained += 1
		elif event is EvolutionOfferedEvent:
			_unit(battle, (event as EvolutionOfferedEvent).unit_id).evolution_ready = true
		elif event is StatusAppliedEvent:
			var applied := event as StatusAppliedEvent
			_unit(battle, applied.unit_id).statuses_applied[applied.status] = applied.turns
		elif event is StatusRemovedEvent:
			var removed := event as StatusRemovedEvent
			_unit(battle, removed.unit_id).statuses_removed.append(removed.status)
		elif event is UnitTeleportedEvent:
			var teleported := event as UnitTeleportedEvent
			_unit(battle, teleported.unit_id).moved_to = teleported.to
		elif event is UnitsSwappedEvent:
			var swapped := event as UnitsSwappedEvent
			_unit(battle, swapped.unit_id).moved_to = swapped.other_from
			_unit(battle, swapped.other_id).moved_to = swapped.from
		elif event is RallyEvent:
			for rallied_id in (event as RallyEvent).rallied_ids:
				_unit(battle, rallied_id).rallied = true
		elif event is UnitReactivatedEvent:
			_unit(battle, (event as UnitReactivatedEvent).unit_id).reactivated = true
		elif event is BarricadeDamagedEvent:
			var chipped := event as BarricadeDamagedEvent
			var barricade := BarricadeOutcome.new()
			barricade.cell = chipped.cell
			barricade.durability_before = battle.board.barricade_at(chipped.cell).durability
			barricade.durability_after = chipped.durability
			barricade.destroyed = chipped.durability == 0
			barricades.append(barricade)
		elif event is FieldEffectPlacedEvent:
			placed.append(event as FieldEffectPlacedEvent)
		elif event is RelicGainedEvent:
			relics.append(event as RelicGainedEvent)
