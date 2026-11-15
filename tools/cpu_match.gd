extends RefCounted
## CPU どうしの対戦を 1 局、画面なしで最後まで進めて、起きたことを数える。
## 対戦は、試作と同じ入口（MatchSetup.create_battle）で作ってから渡す。
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


## battle を、両方のプレイヤーを CPU にして、決着するか max_turns を超えるまで進める。battle は書き換わる。
## cpu がプレイヤー1 を、second がプレイヤー2 を動かす（渡さなければ、どちらも同じ CpuPlayer）。
## 別の版の CPU と対戦させるときに、片方へ渡す。next_action(対戦) を持つものなら何でもよい。
static func play(battle: Battle, max_turns: int, cpu: RefCounted = null, second: RefCounted = null) -> Outcome:
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
			_count(outcome, event)
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
static func _count(outcome: Outcome, event: BattleEvent) -> void:
	var kind: Script = event.get_script()
	outcome.events[kind] = outcome.events.get(kind, 0) + 1
	if event is SkillDamagedEvent:
		outcome.skill_hits[(event as SkillDamagedEvent).unit_id] = true
	elif event is UnitDefeatedEvent:
		var defeated := event as UnitDefeatedEvent
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
