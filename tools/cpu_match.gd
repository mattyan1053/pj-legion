extends RefCounted
## CPU どうしの対戦を 1 局、画面なしで最後まで進めて、起きたことを数える。
##
## 集計の道具（tools/cpu_matches.gd）と、テスト（短い 1 局が最後まで終わること）が使う。
## ノードに依存しない。

const STAGES: Array[BoardGenerator.Stage] = [
	BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.LABYRINTH, BoardGenerator.Stage.TWIN_SPRINGS,
]


## 1 局の結果。添字のある値は、プレイヤー番号（0、1）ごと。
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
	var level_ups: Array[int] = [0, 0]
	var evolutions: Array[int] = [0, 0]
	## 最初の進化が起きたターン（無ければ 0）。
	var first_evolution_turn := 0
	## 倒した中立の駒、倒されたプレイヤーの駒（将を除く）。
	var neutral_kills: Array[int] = [0, 0]
	var losses: Array[int] = [0, 0]
	## 駒の番号 -> [当てた回数, プレイヤーの駒を倒した回数, 中立の駒を倒した回数, 回復した回数]（経験値が入ったものだけ）。
	var gains: Dictionary[int, Array] = {}
	## 雇った駒（将を除く）の数。
	var hired: Array[int] = [0, 0]
	## 駒の種類 -> [雇った数, 倒された数, プレイヤーの駒（将を含む）に与えたダメージ, プレイヤーの駒（将を含む）を倒した数, 進化した数]。
	## 将の行も入る（雇った数は 0）。
	var by_kind: Dictionary[UnitKind.Id, Array] = {}
	## プレイヤーの駒の番号 -> 種類（倒れたあとも引けるように、始めに控える）。
	var kinds: Dictionary[int, UnitKind.Id] = {}
	## いちばん最近の攻撃のダメージ（攻撃した駒、受けた駒）。撃破を、攻撃した駒の種類に数えるのに使う。
	## 経験値のイベントは、育ちきった駒と将には出ないので、そこからは数えない。
	var last_attacker_id := 0
	var last_attacked_id := 0
	## いちばん最近に倒れた駒が中立だったか（撃破の経験値が、どちらの撃破のものかを見分ける）。
	var last_defeated_neutral := false
	## 起きたイベントの種類（スクリプト）-> 回数。
	var events: Dictionary[Script, int] = {}


## 決まった編成を両方のプレイヤーに置いた対戦を作る。盤面を作れなければ null。
static func create(
	stage: BoardGenerator.Stage, battle_seed: int, decks: Array[Deck], size := BoardGenerator.DEFAULT_SIZE
) -> Battle:
	var board := BoardGenerator.generate(stage, battle_seed, size)
	if board == null:
		return null
	var battle := Battle.new(board, battle_seed)
	Deployment.deploy(battle, Unit.Side.PLAYER1, decks[0])
	Deployment.deploy(battle, Unit.Side.PLAYER2, decks[1])
	return battle


## battle を、両方のプレイヤーを CPU にして、決着するか max_turns を超えるまで進める。battle は書き換わる。
static func play(battle: Battle, max_turns: int, cpu: CpuPlayer = null) -> Outcome:
	var outcome := Outcome.new()
	if cpu == null:
		cpu = CpuPlayer.new()
	for unit in battle.units:
		if unit.side == Unit.Side.NEUTRAL:
			continue
		outcome.kinds[unit.id] = unit.kind
		if unit.kind != UnitKind.Id.KING:
			outcome.hired[unit.side] += 1
			_kind_row(outcome, unit.kind)[0] += 1
	while not battle.is_over() and battle.turn <= max_turns:
		var mover := battle.phase
		var started := Time.get_ticks_usec()
		var action := cpu.next_action(battle)
		var spent := (Time.get_ticks_usec() - started) / 1000.0
		outcome.think_msec += spent
		outcome.slowest_msec = maxf(outcome.slowest_msec, spent)
		var result := battle.apply(action) if action != null else ActionResult.rejected()
		if not result.accepted:
			outcome.rejected += 1
			break
		outcome.actions += 1
		for event in result.events:
			_count(outcome, battle, mover, event)
	outcome.turns = battle.turn
	outcome.finished = battle.is_over()
	outcome.winner = battle.winner
	if battle.is_draw():
		outcome.ending = "draw"
	return outcome


static func _count(outcome: Outcome, battle: Battle, mover: Unit.Side, event: BattleEvent) -> void:
	var kind: Script = event.get_script()
	outcome.events[kind] = outcome.events.get(kind, 0) + 1
	if event is LevelUpEvent:
		outcome.level_ups[mover] += 1
	elif event is UnitEvolvedEvent:
		outcome.evolutions[mover] += 1
		if outcome.first_evolution_turn == 0:
			outcome.first_evolution_turn = battle.turn
		var evolved := event as UnitEvolvedEvent
		if outcome.kinds.has(evolved.unit_id):
			_kind_row(outcome, outcome.kinds[evolved.unit_id])[4] += 1
	elif event is AttackDamagedEvent:
		var hit := event as AttackDamagedEvent
		outcome.last_attacker_id = hit.attacker_id
		outcome.last_attacked_id = hit.unit_id
		if outcome.kinds.has(hit.attacker_id) and outcome.kinds.has(hit.unit_id):
			_kind_row(outcome, outcome.kinds[hit.attacker_id])[2] += hit.amount
	elif event is ExplosionDamagedEvent:
		outcome.last_attacked_id = 0  # 樽の爆発で倒れた駒は、誰の撃破にも数えない
	elif event is UnitDefeatedEvent:
		var defeated := event as UnitDefeatedEvent
		outcome.last_defeated_neutral = defeated.side == Unit.Side.NEUTRAL
		if (
			defeated.side != Unit.Side.NEUTRAL and outcome.last_attacked_id == defeated.unit_id
			and outcome.kinds.has(outcome.last_attacker_id)
		):
			_kind_row(outcome, outcome.kinds[outcome.last_attacker_id])[3] += 1
		outcome.last_attacked_id = 0
		if defeated.side == Unit.Side.NEUTRAL:
			outcome.neutral_kills[mover] += 1
		elif defeated.kind != UnitKind.Id.KING:
			outcome.losses[defeated.side] += 1
			_kind_row(outcome, defeated.kind)[1] += 1
	elif event is ExperienceGainedEvent:
		var gained := event as ExperienceGainedEvent
		var tally: Array = outcome.gains.get_or_add(gained.unit_id, [0, 0, 0, 0])
		match gained.reason:
			ExperienceGainedEvent.Reason.HIT:
				tally[0] += 1
			ExperienceGainedEvent.Reason.DEFEAT:
				tally[2 if outcome.last_defeated_neutral else 1] += 1
			ExperienceGainedEvent.Reason.HEAL:
				tally[3] += 1
	elif event is GameWonEvent:
		var won := event as GameWonEvent
		outcome.ending = "king" if won.reason == GameWonEvent.Reason.KING_DEFEATED else "hq"


static func _kind_row(outcome: Outcome, kind: UnitKind.Id) -> Array:
	return outcome.by_kind.get_or_add(kind, [0, 0, 0, 0, 0])
