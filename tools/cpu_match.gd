extends RefCounted
## CPU どうしの対戦を 1 局、画面なしで最後まで進めて、起きたことを数える。
## 対戦は、ゲームの画面と同じ入口（MatchSetup.create_battle）で作ってから渡す。
##
## 集計の道具（tools/cpu_matches.gd）と、テスト（短い 1 局が最後まで終わること）が使う。
## ノードに依存しない。

const STAGES: Array[BoardGenerator.Stage] = [
	BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.LABYRINTH, BoardGenerator.Stage.TWIN_SPRINGS,
]


## 1 局の結果。添字のある値は、プレイヤー番号（0、1）ごと。
## 駒・陣営の戦績（ダメージ、撃破、レベル、進化、必殺技、中ボス）は、決着の画面と同じ集計（BattleStats）から写す。
class Outcome:
	extends RefCounted
	## 決着したか。偽なら、ターンの上限で打ち切った。
	var finished := false
	## 勝ったプレイヤー。引き分けと打ち切りでは -1。
	var winner := -1
	## "king"（将の撃破）、"hq"（本陣の占拠）、"draw"（引き分け）、"cutoff"（打ち切り）。
	var ending := "cutoff"
	## 終わったときのターン。
	var turns := 0
	## 受け付けられた行動の数と、断られた行動の数（0 のはず）。
	var actions := 0
	var rejected := 0
	## 考えるのにかかった時間（ミリ秒）の合計と、いちばん長かった 1 手。
	var think_msec := 0.0
	var slowest_msec := 0.0
	## 戦績（BattleStats）。下の値の多くは、ここから写したもの。
	var stats: BattleStats
	var level_ups: Array[int] = [0, 0]
	var evolutions: Array[int] = [0, 0]
	## 最初の進化が起きたターン（無ければ 0）。
	var first_evolution_turn := 0
	## 倒した中立の駒、倒されたプレイヤーの駒（将を除く）。
	var neutral_kills: Array[int] = [0, 0]
	var losses: Array[int] = [0, 0]
	## 倒れた中ボス。[倒れたターン, 倒した陣営（いなければ -1）, 中ボスの番号] の列（docs/neutral-mid-boss.md）。
	## 倒した陣営は、その中ボスの聖遺物（Relics.of_boss）を受け取っている。
	var mid_boss_kills: Array[Array] = []
	## 駒の番号 -> [当てた回数, プレイヤーの駒を倒した回数, 中立の駒を倒した回数, 回復した回数, 中ボスを倒した回数]（経験値が入ったものだけ）。
	var gains: Dictionary[int, Array] = {}
	## 雇った駒（将を除く）の数。
	var hired: Array[int] = [0, 0]
	## 駒の種類 -> [雇った数, 倒された数, 敵のプレイヤーの駒（将を含む）に与えたダメージ, 敵のプレイヤーの駒（将を含む）を倒した数, 進化した数]。
	## 将の行も入る（雇った数と倒された数は 0）。
	var by_kind: Dictionary[UnitKind.Id, Array] = {}
	## 同じ表を、プレイヤー番号ごとに分けたもの（別の版の CPU と対戦させたときに、どちらの駒かを分けて見る）。
	var by_side_kind: Array[Dictionary] = [{}, {}]
	## 次の撃破の経験値が、どの撃破のものか（gains の列: 1 = プレイヤーの駒、2 = 中立の駒、4 = 中ボス）。
	## 駒の攻撃では、いちばん最近に倒れた駒。スキルでは、その行動で倒れた駒のうち、経験値のいちばん多いもの（Skills.deal_damage と同じ）。
	var defeat_column := 1
	## スキル -> 使った回数。
	var skill_uses: Dictionary[Skill.Id, int] = {}
	## いまの行動でスキルのダメージを受けた駒（同じスキルで何体も同時に倒れる）。
	var skill_hits: Dictionary[int, bool] = {}
	## いまの行動のスキルで倒れた駒のうち、経験値のいちばん多いものの列（無ければ 0）。
	var skill_defeat_column := 0
	## 必殺技を使った回数（プレイヤー番号ごと）と、最初に使ったターン（使わなければ 0）。
	var ult_uses: Array[int] = [0, 0]
	var first_ult_turn: Array[int] = [0, 0]
	## 起きたイベントの種類（スクリプト）-> 回数。
	var events: Dictionary[Script, int] = {}
	## 倒されたプレイヤーの駒（将を除く）の倒され方。1 体につき 1 つ（Fall）。
	var falls: Array[Fall] = []
	## 駒の番号 -> ダメージを受けた回数（防がれたものは数えない）。
	var hits_taken: Dictionary[int, int] = {}
	## 駒の番号 -> いちばん最近にダメージを与えた駒の番号（樽の爆発は 0）。
	var last_hit_by: Dictionary[int, int] = {}
	## 駒の番号 -> その駒がいちばん最近にシャドウステップを使った [ターン, フェーズ]。
	var stepped_at: Dictionary[int, Array] = {}
	## 倒れた中ボスの倒れ方。1 体につき 1 つ（BossFall）。
	var boss_falls: Array[BossFall] = []
	## 中ボスの駒の番号 -> プレイヤーごとの、その中ボスから実際に減らした HP（駒の攻撃とスキル。止めの余りは数えない）。
	var boss_damage: Dictionary[int, Array] = {}
	## 中ボスの駒の番号 -> 最後に受けたダメージのあとの HP（止めの一撃で実際に減った HP を出すため）。
	var boss_hp: Dictionary[int, int] = {}
	## 中ボスの駒の番号 -> プレイヤーが初めて削った時点の [ターン, プレイヤーごとの戦力]（狩りが始まった時点。army_hp）。
	var boss_first_hit: Dictionary[int, Array] = {}


## 倒れた中ボス 1 体の倒れ方（互角のまま取り合っているかを見る。docs/cpu-ai.md の「集計の道具」）。
class BossFall:
	extends RefCounted
	var turn := 0
	var boss_index := 0
	## 倒した陣営（いなければ -1）。
	var slayer_side := -1
	## 倒れた時点の、戦える駒（前衛・後衛・奇襲）の数。倒した側と、その相手。
	var slayer_units := 0
	var rival_units := 0
	## 倒れた時点で、中ボスのマスから CONTEST_RADIUS マス以内にいた相手（倒した側でないプレイヤー）の戦える駒の数。
	var rivals_near := 0
	## その中ボスから実際に減らした HP（駒の攻撃とスキル。止めの余りは数えない）。倒した側と、その相手。
	var slayer_damage := 0
	var rival_damage := 0
	## 倒れた時点の戦力（将を除くプレイヤーの駒の HP の合計。CpuMatch.army_hp）。倒した側と、その相手。
	var slayer_hp := 0
	var rival_hp := 0
	## プレイヤーが初めてこの中ボスを削ったターンと、その時点の戦力（狩りが始まる前の形。倒した側と、その相手）。
	var first_hit_turn := 0
	var first_slayer_hp := 0
	var first_rival_hp := 0

	## 倒した側の、倒れた時点の戦力の分け前（0〜1。0.5 で互角）。
	func hp_share() -> float:
		return float(slayer_hp) / maxi(1, slayer_hp + rival_hp)

	## 同じく、狩りが始まった時点（初めて削られた時点）の分け前。
	func first_hp_share() -> float:
		return float(first_slayer_hp) / maxi(1, first_slayer_hp + first_rival_hp)

	## 決着が見える前か（戦える駒の数の差が 1 以内）。
	func is_even() -> bool:
		return absi(slayer_units - rival_units) <= 1

	## 相手もそばにいたか。
	func is_contested() -> bool:
		return rivals_near > 0

	## 相手が半分より多く削った中ボスの、止めだけを取ったか。
	func is_steal() -> bool:
		return rival_damage > slayer_damage


## 中ボスが倒れたとき、「そばにいた」と数える距離（マンハッタン）。中ボスの届く距離（縄張り 4 + 射程 2）と同じ。
const CONTEST_RADIUS := 6
## 戦力の分け前が 0.5 からこれ以内なら「戦力が互角」と数える（BossFall.hp_share）。
const EVEN_SHARE := 0.05


## 倒された駒 1 体の倒され方（スナイパーが「何もできずに落ちる」かを見る。docs/cpu-ai.md の「集計の道具」）。
class Fall:
	extends RefCounted
	var kind: UnitKind.Id
	var turn := 0
	## 倒されるまでに、敵のプレイヤーの駒に与えたダメージ。
	var damage := 0
	## 倒されるまでに、ダメージを受けた回数。1 なら、無傷か回復しきった状態から一撃で倒された。
	var hits_taken := 0
	## 止めを刺した駒の種類とレベル（樽の爆発など、駒でなければ -1 と 0）。
	var killer_kind := -1
	var killer_level := 0
	## 止めを刺した駒が、同じフェーズにシャドウステップで跳んでいたか。
	var after_step := false


## battle を、両方のプレイヤーを CPU にして、決着するか max_turns を超えるまで進める。battle は書き換わる。
## cpu がプレイヤー1 を、second がプレイヤー2 を動かす（渡さなければ、どちらも同じ CpuPlayer）。
## 別の版の CPU と対戦させるときに、片方へ渡す。next_action(対戦) を持つものなら何でもよい。
## no_reward なら、聖遺物の効果とゲージを受け取った直後に取り消す（倒した側の勝率のうち、聖遺物のぶんを切り分けるための比べ。
## CPU は、聖遺物がもらえるつもりのまま狩る）。
static func play(battle: Battle, max_turns: int, cpu: RefCounted = null, second: RefCounted = null, no_reward := false) -> Outcome:
	var outcome := Outcome.new()
	if cpu == null:
		cpu = CpuPlayer.new()
	if second == null:
		second = cpu
	var stats := BattleStats.new(battle)
	outcome.stats = stats
	while not battle.is_over() and battle.turn <= max_turns:
		var mover := battle.phase
		var started := Time.get_ticks_usec()
		var thinker := second if mover == Unit.Side.PLAYER2 else cpu
		var action: BattleAction = thinker.call(&"next_action", battle)
		var spent := (Time.get_ticks_usec() - started) / 1000.0
		outcome.think_msec += spent
		outcome.slowest_msec = maxf(outcome.slowest_msec, spent)
		var result := battle.apply(action) if action != null else ActionResult.rejected()
		if not result.accepted:
			outcome.rejected += 1
			break
		outcome.actions += 1
		for event in result.events:
			stats.feed(event)
			_count(outcome, event, battle, mover)
			if no_reward and event is RelicGainedEvent:
				_take_back(battle, event as RelicGainedEvent)
	outcome.turns = battle.turn
	outcome.finished = battle.is_over()
	outcome.winner = battle.winner
	match stats.ending:
		BattleStats.Ending.KING_DEFEATED:
			outcome.ending = "king"
		BattleStats.Ending.HQ_CAPTURED:
			outcome.ending = "hq"
		BattleStats.Ending.DRAW:
			outcome.ending = "draw"
	_copy_stats(outcome, stats)
	return outcome


## 戦績（BattleStats）から、集計に使う値を写す。
static func _copy_stats(outcome: Outcome, stats: BattleStats) -> void:
	for side in 2:
		var record := stats.sides[side]
		outcome.level_ups[side] = record.level_ups
		outcome.evolutions[side] = record.evolutions
		outcome.neutral_kills[side] = record.neutral_kills
		outcome.losses[side] = record.losses
		outcome.ult_uses[side] = record.ult_uses
		outcome.first_ult_turn[side] = record.first_ult_turn
	for boss: Array in stats.mid_bosses:
		outcome.mid_boss_kills.append([boss[0], boss[2], boss[1]])
	for record: BattleStats.UnitRecord in stats.units.values():
		if record.side == Unit.Side.NEUTRAL:
			continue
		var king := record.kind == UnitKind.Id.KING
		if not king:
			outcome.hired[record.side] += 1
		if record.evolved_turn > 0 and (outcome.first_evolution_turn == 0 or record.evolved_turn < outcome.first_evolution_turn):
			outcome.first_evolution_turn = record.evolved_turn
		var row: Array[int] = [
			0 if king else 1, 1 if record.defeated and not king else 0, record.damage, record.kills,
			1 if record.evolution != Evolution.Id.NONE else 0,
		]
		for table: Dictionary in [outcome.by_kind, outcome.by_side_kind[record.side]]:
			var sum: Array = table.get_or_add(record.kind, [0, 0, 0, 0, 0])
			for i in row.size():
				sum[i] += row[i]


## 戦績に無いもの（イベントの数、スキルごとの回数、経験値の入り方）を数える。
## battle は、その行動を適用したあとの対戦。mover は、その行動をしたフェーズ。
static func _count(outcome: Outcome, event: BattleEvent, battle: Battle, mover: Unit.Side) -> void:
	var kind: Script = event.get_script()
	outcome.events[kind] = outcome.events.get(kind, 0) + 1
	if event is UnitDamagedEvent:
		var hit := event as UnitDamagedEvent
		if hit.amount > 0:
			outcome.hits_taken[hit.unit_id] = outcome.hits_taken.get(hit.unit_id, 0) + 1
			var source_id := 0
			if hit is AttackDamagedEvent:
				source_id = (hit as AttackDamagedEvent).attacker_id
			elif hit is SkillDamagedEvent:
				source_id = (hit as SkillDamagedEvent).user_id
			outcome.last_hit_by[hit.unit_id] = source_id
			if outcome.stats != null and outcome.stats.units.has(hit.unit_id) and outcome.stats.units.has(source_id):
				var source_side := outcome.stats.units[source_id].side
				if outcome.stats.units[hit.unit_id].kind == UnitKind.Id.ELITE_MINION:
					# amount は残りの HP を超えても切らない量なので、倒した一撃は、その前の HP までにする。
					var before: int = outcome.boss_hp.get(hit.unit_id, UnitKind.max_hp(UnitKind.Id.ELITE_MINION))
					var lost := hit.amount if hit.hp > 0 else mini(hit.amount, before)
					outcome.boss_hp[hit.unit_id] = hit.hp
					# 止めの一撃が最初の一撃なら、ここでは控えない（聖遺物がもう掛かっている。倒れたときに、掛かる前の値で控える）。
					if source_side != Unit.Side.NEUTRAL and hit.hp > 0 and not outcome.boss_first_hit.has(hit.unit_id):
						outcome.boss_first_hit[hit.unit_id] = [battle.turn, army_hp(battle, 0), army_hp(battle, 1)]
					if source_side != Unit.Side.NEUTRAL:
						outcome.boss_damage.get_or_add(hit.unit_id, [0, 0])[source_side] += lost
	if event is SkillDamagedEvent:
		outcome.skill_hits[(event as SkillDamagedEvent).unit_id] = true
	elif event is UnitDefeatedEvent:
		var defeated := event as UnitDefeatedEvent
		if defeated.side != Unit.Side.NEUTRAL and defeated.kind != UnitKind.Id.KING:
			var fall := Fall.new()
			fall.kind = defeated.kind
			fall.turn = battle.turn
			if outcome.stats != null and outcome.stats.units.has(defeated.unit_id):
				fall.damage = outcome.stats.units[defeated.unit_id].damage
			fall.hits_taken = outcome.hits_taken.get(defeated.unit_id, 0)
			var killer_id: int = outcome.last_hit_by.get(defeated.unit_id, 0)
			var killer := battle.unit_by_id(killer_id)
			if killer != null:
				fall.killer_kind = killer.kind
				# 止めを刺した時点のレベル。この撃破の経験値でレベルが上がっていても、対戦の駒はもう上がったあとなので、
				# まだ LevelUpEvent を食べていない戦績（BattleStats）のほうを読む。
				fall.killer_level = killer.level
				if outcome.stats != null and outcome.stats.units.has(killer_id):
					fall.killer_level = outcome.stats.units[killer_id].level
				fall.after_step = outcome.stepped_at.get(killer_id, []) == [battle.turn, mover]
			outcome.falls.append(fall)
		var column := 1
		if defeated.kind == UnitKind.Id.ELITE_MINION:
			column = 4
		elif defeated.side == Unit.Side.NEUTRAL:
			column = 2
		if outcome.skill_hits.has(defeated.unit_id):
			if _defeat_experience(column) > _defeat_experience(outcome.skill_defeat_column):
				outcome.skill_defeat_column = column
			column = outcome.skill_defeat_column
		outcome.defeat_column = column
	elif event is MidBossDefeatedEvent:
		var slain := event as MidBossDefeatedEvent
		var fall := BossFall.new()
		fall.turn = battle.turn
		fall.boss_index = slain.boss_index
		fall.slayer_side = slain.slayer_side
		if slain.slayer_side >= 0:
			var dealt: Array = outcome.boss_damage.get(slain.unit_id, [0, 0])
			fall.slayer_damage = dealt[slain.slayer_side]
			fall.rival_damage = dealt[1 - slain.slayer_side]
			# 聖遺物は、このイベントより前（Battle.remove_unit の中）にもう掛かっている。英知で増えた HP は、倒す前の戦力から除く。
			var hp_now: Array[int] = [army_hp(battle, 0), army_hp(battle, 1)]
			var relic := Relics.of_boss(slain.boss_index)
			if relic != -1:
				var gained: int = Relics.bonus(relic as Relics.Id).get(Unit.Stat.MAX_HP, 0)
				hp_now[slain.slayer_side] -= gained * army_size(battle, slain.slayer_side)
			fall.slayer_hp = hp_now[slain.slayer_side]
			fall.rival_hp = hp_now[1 - slain.slayer_side]
			var first: Array = outcome.boss_first_hit.get(slain.unit_id, [battle.turn, hp_now[0], hp_now[1]])
			fall.first_hit_turn = first[0]
			fall.first_slayer_hp = first[1 + slain.slayer_side]
			fall.first_rival_hp = first[2 - slain.slayer_side]
			for unit in battle.units:
				var role := UnitKind.role(unit.kind)
				if unit.side == Unit.Side.NEUTRAL or role == UnitKind.Role.NONE or role == UnitKind.Role.HEALER:
					continue
				if unit.side == slain.slayer_side:
					fall.slayer_units += 1
				else:
					fall.rival_units += 1
					if Combat.distance(unit.cell, slain.cell) <= CONTEST_RADIUS:
						fall.rivals_near += 1
		outcome.boss_falls.append(fall)
	elif event is ExperienceGainedEvent:
		var gained := event as ExperienceGainedEvent
		var tally: Array = outcome.gains.get_or_add(gained.unit_id, [0, 0, 0, 0, 0])
		match gained.reason:
			ExperienceGainedEvent.Reason.HIT:
				tally[0] += 1
			ExperienceGainedEvent.Reason.DEFEAT:
				tally[outcome.defeat_column] += 1
			ExperienceGainedEvent.Reason.HEAL:
				tally[3] += 1
	elif event is UnitActedEvent:
		outcome.skill_hits.clear()
		outcome.skill_defeat_column = 0
	elif event is SkillUsedEvent:
		var used := event as SkillUsedEvent
		outcome.skill_uses[used.skill] = outcome.skill_uses.get(used.skill, 0) + 1
		if used.skill == Skill.Id.SHADOW_STEP:
			outcome.stepped_at[used.unit_id] = [battle.turn, mover]


## 受け取った聖遺物を、効果ごと取り消す（play の no_reward）。HP は増えたぶんだけ戻す（1 は残す）。
static func _take_back(battle: Battle, gained: RelicGainedEvent) -> void:
	battle.relics[gained.side].erase(gained.relic)
	for unit_id in gained.unit_ids:
		var unit := battle.unit_by_id(unit_id)
		if unit == null:
			continue
		var before := unit.max_hp()
		for which: Unit.Stat in gained.bonus:
			unit.relic_bonus[which] = unit.relic_bonus.get(which, 0) - gained.bonus[which]
		unit.hp = clampi(unit.hp - (before - unit.max_hp()), 1, unit.max_hp())
	battle.ult_gauge[gained.side] = maxi(0, battle.ult_gauge[gained.side] - gained.ult_gain)


## 戦力の目安: 将を除く、その陣営の駒の HP の合計。
static func army_hp(battle: Battle, side: int) -> int:
	var total := 0
	for unit in battle.units:
		if unit.side == side and unit.kind != UnitKind.Id.KING and unit.hp > 0:
			total += unit.hp
	return total


## 将を除く、その陣営の盤にいる駒の数（army_hp と同じ駒）。
static func army_size(battle: Battle, side: int) -> int:
	var count := 0
	for unit in battle.units:
		if unit.side == side and unit.kind != UnitKind.Id.KING and unit.hp > 0:
			count += 1
	return count


## gains の列（撃破の種類）の、撃破の経験値。0（倒れていない）は 0。
static func _defeat_experience(column: int) -> int:
	match column:
		1:
			return Growth.DEFEAT_EXPERIENCE
		2:
			return Growth.NEUTRAL_DEFEAT_EXPERIENCE
		4:
			return Growth.MID_BOSS_DEFEAT_EXPERIENCE
	return 0
