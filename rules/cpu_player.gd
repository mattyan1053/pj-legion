class_name CpuPlayer
extends RefCounted
## CPU の思考（docs/cpu-ai.md）。いまの対戦を見て、次の行動を 1 つ返す。
##
##   var cpu := CpuPlayer.new()
##   battle.apply(cpu.next_action(battle))
##
## - 対戦の状態は変えない。返す行動は、いまのフェーズのプレイヤーのもの
## - 選べることは Battle.options() に聞き、行動の結果は Battle.clone() に apply() して、起きたこと（イベント）から読む。
##   ルールの計算（射程、ダメージ、移動範囲）をここに書き写さない。ルールが変われば、CPU の読みもそのまま変わる
## - ここが自分で持つのは「どの手が良いか」の見積もり（調整値）と、候補を絞るための目安だけ
## - 乱数は使わない。同じ状態からは、いつも同じ行動を返す（Battle.rng も進めない）
##
## 覚えているのは、盤面の歩けるマスと歩数の表だけ（速くするためで、判断には影響しない）。
## 1 つのインスタンスを、どの対戦・どちらのプレイヤーにも使い回せる。

# ---- 調整値（docs/cpu-ai.md の「調整値」） ----

## 駒を動かす順（役割）。奇襲 → 後衛 → 前衛 → 回復 → 将。
const ROLE_ORDER: Array[UnitKind.Role] = [
	UnitKind.Role.REARGUARD, UnitKind.Role.VANGUARD, UnitKind.Role.RAIDER, UnitKind.Role.HEALER, UnitKind.Role.NONE,
]
## 役割 -> [目標へ 1 マス近づく価値, 受けうるダメージ 1 の重さ（攻撃・回復する手）, 同（動くだけの手）, 倒されうるマスの減点]。
## 動くだけの手のほうが重い: 手を出さずに敵の届くマスへ入ると、先に殴られるだけになる。前衛は構わず前へ出て、盾になる。
const STYLES := {
	UnitKind.Role.NONE: [8.0, 1.0, 1.0, 5000.0],  # 将。倒されうるマスには立たない。それ以外は本陣を空けない
	UnitKind.Role.VANGUARD: [4.0, 0.15, 0.15, 10.0],
	UnitKind.Role.REARGUARD: [4.0, 0.5, 1.5, 25.0],
	UnitKind.Role.RAIDER: [4.0, 0.35, 1.0, 60.0],
	UnitKind.Role.HEALER: [3.0, 0.8, 1.5, 30.0],
}
## 戦える駒（前衛・後衛・奇襲）が 1 体も残っていないときの将。待っていても勝てないので、自分で敵へ向かう。
const LONE_KING_STYLE: Array[float] = [4.0, 0.3, 0.3, 5000.0]
## 長引いたら踏み込む: このターンから、動くだけの手の危険の重さを、攻撃する手の重さへ少しずつ近づける（BOLD_BY_TURN で同じになる）。
## 互いに相手の届くマスの外で待ち合って、いつまでも決着しないのを防ぐ。
const BOLD_FROM_TURN := 20
const BOLD_BY_TURN := 40
## 勝ちが決まる手、引き分けになる手の価値（負けが決まる手は、勝ちの逆）。
const WIN_VALUE := 1000000.0
const DRAW_VALUE := -100000.0
## ダメージ 1 の価値。プレイヤーの駒、将、中立の駒。
const DAMAGE_VALUE := 2.0
const KING_DAMAGE_VALUE := 6.0
const NEUTRAL_DAMAGE_VALUE := 0.5
## 倒す価値。プレイヤーの駒は KILL_VALUE + コスト × KILL_VALUE_PER_COST。回復役は HEALER_KILL_BONUS を足す。
const KILL_VALUE := 60.0
const KILL_VALUE_PER_COST := 10.0
const HEALER_KILL_BONUS := 10.0
const NEUTRAL_KILL_VALUE := 15.0
## 狩ると決めた中ボス（docs/relic-buff.md の「CPU」）へのダメージ 1 の価値。削っただけでは、止めを相手に取られることがある。
## 価値の大半を止めに置く。狩ると決めていない中ボスを削る手は、MID_BOSS_IDLE_PENALTY を引く（当たりの経験値の価値より大きい。選ばない）。
const HUNT_DAMAGE_VALUE := 1.0
const MID_BOSS_IDLE_PENALTY := 10.0
## 中ボスを倒す価値 = 聖遺物の価値（docs/relic-buff.md の「CPU」）。RELIC_BASE_VALUE（必殺技のゲージと、相手に渡さないぶん）に、
## 自分の駒 1 体につき RELIC_UNIT_VALUE（効果は駒の数だけ掛かる）を足す。
const RELIC_BASE_VALUE := 40.0
const RELIC_UNIT_VALUE := 12.0
## 中ボスを狩る条件（_build_hunts。docs/relic-buff.md の「CPU」）。HUNT_FROM_TURN ターンから。
## 中ボスから HUNT_RADIUS 歩以内の自分の戦う駒（狩りに加われる駒）が、着いた順に毎ターン殴るとして、
## - HUNT_TURNS ターンのうちに倒せる。倒すのに要るダメージは、残りの HP の HUNT_MARGIN 倍で見積もる
##   （殴り返されて下がる駒が出るので、全員が毎ターンは殴れない）
## - 倒しきるまでに着ける相手の戦う駒（そのターン数 × 移動力 + 射程の中）の攻撃力の合計の、HUNT_SUPERIORITY 倍以上の攻撃力がある
## 加われる駒の全部で満たせば、届いた駒が削る。手の空いている駒（HUNT_ENGAGE_DISTANCE マス以内に相手の駒がいない）だけで
## 満たせば、手の空いている駒が中ボスへ向かう。加われる駒の全部で HUNT_COMMIT_TURNS ターンのうちに倒せるところまで来たら、
## 手の空いていない駒も向かう。自分の本陣の近く（GUARD_RADIUS 以内）に相手がいる間は、狩らない。
const HUNT_RADIUS := 14
const HUNT_FROM_TURN := 4
const HUNT_ENGAGE_DISTANCE := 5
const HUNT_TURNS := 6
const HUNT_COMMIT_TURNS := 2
const HUNT_MARGIN := 1.25
const HUNT_SUPERIORITY := 0.8
## 相手が狩っているとみなす距離（中ボスからこの距離の中の相手の戦う駒が、削った中ボスを HUNT_TURNS ターンで倒せる）。
const HUNT_RIVAL_RADIUS := 10
## 止めを相手に渡す削り（削ったあとの HP が、次の相手の番に届く相手の攻撃力の合計以下で、
## このフェーズに自分の残りの駒では削り切れない）の減点。
const MID_BOSS_FEED_PENALTY := 60.0
## 相手が中ボスを狩っている（削っていて、そばの駒で HUNT_TURNS ターンのうちに倒せる）とき、中ボスから DENY_RADIUS マス以内の
## 前衛・後衛は、狩りの最中の相手の駒を DENY_PULL マスぶん近いものとして追う。
const DENY_RADIUS := 16
const DENY_PULL := 6
## 相手が狩っている中ボスの HP がここまで減ったら、DENY_RADIUS マス以内の後衛と奇襲は、止めを横取りしに向かう。
const STEAL_HP := 40
## 倒せなかった相手に残る HP 1 の減点（HP の少ない相手を先に狙う）。
const REMAINING_HP_PENALTY := 0.2
## 自分の本陣からこの距離までに入った敵は「侵入者」。与えるダメージの価値を INTRUDER_RATE 倍にする。
const DEFENSE_RADIUS := 5
const INTRUDER_RATE := 1.5
## 自分の本陣に乗っている敵。ダメージの価値を OCCUPIER_RATE 倍にし、倒す価値に OCCUPIER_KILL_BONUS を足す。
const OCCUPIER_RATE := 2.0
const OCCUPIER_KILL_BONUS := 100.0
## 相手の盾を削る価値（耐久力 1 あたり）と、壊す価値。駒を攻撃できないときに、道をふさぐ盾を壊しに行く程度。
const BARRICADE_DAMAGE_VALUE := 0.5
const BARRICADE_BREAK_VALUE := 10.0
## 味方を巻き込むダメージ（樽の爆発）は、同じ量の敵へのダメージの何倍の損とみるか。
const FRIENDLY_FIRE_RATE := 1.5
## 回復 1 の価値、回復すること自体の価値、将を回復する上乗せ、減っている割合（0〜1）に掛ける上乗せ。
const HEAL_VALUE := 2.0
const HEAL_BASE_VALUE := 5.0
const KING_HEAL_BONUS := 10.0
const WOUNDED_BONUS := 10.0
## 入る経験値 1 の価値と、レベルが 1 つ上がる価値。中立の駒を狩る得は、ほぼこれで決まる（もう育たない駒は狩りに行かない）。
const EXPERIENCE_VALUE := 0.5
const LEVEL_UP_VALUE := 15.0
## 敵の本陣のマスに立つ価値（奇襲、それ以外）と、占拠を続けている 1 回ぶんの上乗せ。
const HQ_VALUE_RAIDER := 150.0
const HQ_VALUE_OTHER := 60.0
const HQ_HOLD_VALUE := 400.0
## 将のいない自分の本陣のマスに立つ価値（敵が GUARD_RADIUS 以内にいるとき。乗っていれば、敵は占拠できない）。
const HQ_GUARD_VALUE := 80.0
const GUARD_RADIUS := 10
## 奇襲が、空いている敵の本陣へ乗りに行く距離（歩数）。これより遠ければ、敵の駒を狙う。
const RAID_STEPS := 12
## 奇襲は、敵の駒を狙う間、味方の前衛・後衛のいちばん近い駒から SUPPORT_DISTANCE マスより離れない。
## 離れた 1 マスにつき ISOLATION_WEIGHT を引く（目標へ 1 マス近づく価値より大きい。倒せる手なら、離れても踏み込む）。
const SUPPORT_ROLES: Array[UnitKind.Role] = [UnitKind.Role.VANGUARD, UnitKind.Role.REARGUARD]
const SUPPORT_DISTANCE := 4
const ISOLATION_WEIGHT := 5.0
## 巡航の減点（同じ良さなら、巡航しない）。
const CRUISE_PENALTY := 0.5
## 後衛が、狙う相手から 1 マス離れている価値（射程の中で、なるべく遠くに立つ）。
const STAND_OFF_VALUE := 0.5
## 回復役が、減っている味方を探す範囲（歩数）。
const HEALER_SEARCH_STEPS := 12
## スキル -> 使った結果の価値を見積もるメソッド（SkillUsedEvent と、使ったあとの複製を受け取る）。
## ダメージ・回復・経験値のイベントだけで価値が決まるスキルは、載せなくてよい（_outcome_value がそのまま読む）。
const SKILL_VALUES := {
	Skill.Id.TACTICAL_BARRICADE: &"_barricade_value",
	Skill.Id.SAINT_PLACE: &"_sanctuary_value",
	Skill.Id.SMOKE_GRENADE: &"_smoke_value",
	Skill.Id.DIVINE_SHIELD: &"_barrier_value",
	Skill.Id.PRECISION_AIM: &"_aim_value",
	Skill.Id.SHADOW_STEP: &"_shadow_step_value",
	Skill.Id.ADRENALINE_SHOT: &"_adrenaline_value",
}
## スキル -> 対象に選ぶ価値のありそうなマスを並べるメソッド（駒と、通常の移動で止まれるマスを受け取り、マスの集合を返す）。
## スキルを使う手は、ここに並んだ対象だけを、複製の上で使ってみて比べる（全部のマスを試すと、時間がかかりすぎる）。
## 載せていないスキルは、選べる対象をすべて試す。
const SKILL_TARGETS := {
	Skill.Id.TACTICAL_BARRICADE: &"_barricade_targets",
	Skill.Id.SAINT_PLACE: &"_sanctuary_targets",
	Skill.Id.SMOKE_GRENADE: &"_smoke_targets",
	Skill.Id.FIREBALL: &"_fireball_targets",
	Skill.Id.DIVINE_SHIELD: &"_barrier_targets",
	Skill.Id.PRECISION_AIM: &"_aim_targets",
	Skill.Id.SHADOW_STEP: &"_shadow_step_targets",
	Skill.Id.ADRENALINE_SHOT: &"_adrenaline_targets",
}
## 盾: 置いたあとの盤面で危険を数え直し、味方が受けうるダメージの減るぶんの価値の何倍を見込むか
## （敵は回り込める・盾を壊せるので、1 より小さい）。味方の離れた攻撃を遮るぶんは、同じ倍率で引く。
const BARRICADE_COVER_RATE := 0.75
## 盾: 1 回に試す置き場所の数の上限（危険を数え直すので、1 か所ごとに時間がかかる）。
const BARRICADE_TRIES := 6
## バリア: 張るために立つマスの候補の数（立つマスの価値の高い順）。
const BARRIER_TRIES := 3
## 聖域: 中に、減っている味方がこの数だけいれば置く。1 体が回復すると見込むのは、聖域の回復の何回ぶんまでか。
const SANCTUARY_MIN_UNITS := 2
const SANCTUARY_EXPECTED_HEALS := 2
## 煙幕: 中に、離れたところからしか届かない攻撃に狙われている味方がこの数だけいれば置く。
## 防げるダメージの価値の何倍を見込むか（敵は狙いを替えられるので、1 より小さい）。
const SMOKE_MIN_UNITS := 2
const SMOKE_MIN_VALUE := 20.0
const SMOKE_COVER_RATE := 0.75
## バリア: 次の相手の番に自分に届く攻撃のうち、いちばん弱い 1 回を防ぐと見込む（敵は弱い攻撃で先にはがす）。
## その価値は、その攻撃 1 回ぶんのダメージの価値の何倍か（攻撃されないまま期限で消えることもあるので、1 より小さい）。
const BARRIER_COVER_RATE := 0.75
## 照準: 次の自分の番に、強めた攻撃を当てられそうな敵 1 体への、その攻撃の価値の何倍を見込むか。
## いま伸びた射程の中にいる敵（AIM_RATE）と、1 回動けば入ってくる敵（AIM_WATCH_RATE）。
## いまの位置から攻撃できる敵は数えない（構えるより、いま撃つほうが早い）。
const AIM_RATE := 0.4
const AIM_WATCH_RATE := 0.2
## アドレナリン注射: 対象が、いまの位置からもう一度手を出したときの価値（いちばん良い攻撃・回復）が、この値以上なら使う
## （回数に限りがあるので、倒せる・将を殴れるくらいの手に取っておく）。見込む価値は、その手の価値の何倍か。
const ADRENALINE_MIN_VALUE := 30.0
const ADRENALINE_RATE := 0.75

## 敵のバリアをはがす価値: このあとに動ける味方が、その敵に当てられそうな攻撃 1 回ぶんのダメージの価値の何倍か。
## 続ける味方がいなければ BARRIER_STRIP_VALUE だけ（バリアは使わせたが、ダメージにはつながらない）。
const BARRIER_STRIP_RATE := 0.6
const BARRIER_STRIP_VALUE := 2.0

## 必殺技 -> いま使うかを決めるメソッド（docs/tactical-ult.md の「CPU」）。真を返したら、駒を動かす前に使う。
const ULT_USES := {
	Ult.Id.ALL_OUT_ASSAULT: &"_assault_pays",
	Ult.Id.MANA_ERUPTION: &"_eruption_pays",
}
## 総員突撃: まだ行動していない戦う駒のうち、伸びた移動力で敵の駒に攻撃が届きそうな駒が、この数だけいれば使う
## （戦う駒がこれより少なければ、その全員）。
const ASSAULT_MIN_UNITS := 3
## 魔力解放: まだ行動していない駒のうち、クールダウンがこのターン数以上残っていて、敵の駒がこの距離の中にいる駒が、
## ERUPTION_MIN_UNITS 体いれば使う（スキルを持つ駒がこれより少なければ、その全員）。
const ERUPTION_MIN_COOLDOWN := 2
const ERUPTION_RADIUS := 6
const ERUPTION_MIN_UNITS := 2

const _GOAL := 0
const _DANGER := 1
const _IDLE_DANGER := 2
const _LETHAL := 3
const _FAR := 9999

# ---- 覚えておくもの（盤面が同じ間だけ使い回す） ----

var _board: Board
var _walkable_revision := -1
## 駒が乗っているポータルのマス（その対は、いまは通れないものとして歩数を数える）。
var _blocked_portals: Array[Vector2i] = []
## 歩けるマスなら 1。添字は y * 幅 + x。
var _walkable := PackedByteArray()
## 目標のマス -> そこから各マスへの歩数（駒は無視する。届かないマスは _FAR）。
var _steps: Dictionary[Vector2i, PackedInt32Array] = {}

# ---- 1 回の判断の間だけ使うもの ----

var _battle: Battle
var _me: Unit.Side
var _foe: Unit.Side
## 自分と相手の本陣のマス。本陣の無い盤面（テスト用）では Board.NO_CELL。
var _my_hq := Board.NO_CELL
var _foe_hq := Board.NO_CELL
## マス -> そこを次の相手の番に攻撃できる敵（駒の番号 -> 受けうるダメージ）。
var _threats: Dictionary[Vector2i, Dictionary] = {}
## 同じ形で、煙幕に防がれない攻撃だけ（隣まで寄っての攻撃と、スキルのダメージ）。自分の煙幕の中のマスは、こちらで見る。
var _close_threats: Dictionary[Vector2i, Dictionary] = {}
## 自分の煙幕の中のマス。
var _smoked: Dictionary[Vector2i, bool] = {}
## 次の相手の番に、敵の駒（回復役を除く）が止まれるマス。
var _foe_stops: Dictionary[Vector2i, bool] = {}
## スキルを使う手を複製の上で試している間の、使う前に立っているマス（動いてから使う手では、いまのマスと違う）。
var _stand := Board.NO_CELL
var _threats_ready := false
## 立つマス -> いま考えている駒がそこへ動いただけの盤面の、危険の表 [threats, close]（盾の見積もりが使う）。
var _moved_threats: Dictionary[Vector2i, Array] = {}
## いま考えている駒の目標までの歩数の表、そこまで近づけば足りる歩数、役割ごとの重み、離れて立つか。
var _goal_steps := PackedInt32Array()
var _goal_reach := 0
var _goal_weight := 0.0
var _danger_weight := 0.0
var _idle_danger_weight := 0.0
## 敵が自分の本陣の近く（GUARD_RADIUS 以内）にいるか。
var _hq_in_danger := false
var _lethal_penalty := 0.0
var _stand_off := false
## いま考えている駒（奇襲）が離れすぎないようにする味方（前衛・後衛）のマス。空なら、見ない。
var _support: Array[Vector2i] = []
## いま考えている駒が、ほかのマスへ動いたあとの射程（動くと外れる状態で伸びた射程は、動くと戻る）。
var _moved_reach := 0
## いま考えている駒が、戦える駒のいなくなった軍の将か。
var _lone_king := false
## いま考えている駒の番号（止めを相手に渡す削りかを見るときに、このあとに動ける味方から除く）。
var _thinking_id := 0
## 中ボスの読み（_build_hunts）。狩ると決めた中ボス（駒の番号）、相手が狩っている中ボス、
## 中ボス -> 次の相手の番に届きそうな相手の攻撃力の合計。
var _hunts_ready := false
var _hunted: Dictionary[int, bool] = {}  # 値は、もう削り切れるところまで来ているか
## 削ってよい中ボス（狩りに加われる駒の全部でなら倒せる。届いた駒が、ほかに良い手が無ければ削る）。
var _chipped: Dictionary[int, bool] = {}
var _rival_hunts: Dictionary[int, bool] = {}
var _rival_strike: Dictionary[int, int] = {}


## いまのフェーズのプレイヤーの、次の行動。決着のあとと中立のフェーズでは null。
## 返す行動は、必ず Battle.can_apply() が受け付ける。
func next_action(battle: Battle) -> BattleAction:
	if battle.is_over() or battle.phase == Unit.Side.NEUTRAL:
		return null
	_begin(battle)
	var action := _decide()
	_battle = null
	if action != null and battle.can_apply(action):
		return action
	return _fallback(battle)


## いまのフェーズのプレイヤーの駒 unit_id が cell に立っているとして、次の相手の番（と中立のフェーズ）に受けうるダメージの見積もり。
## CPU が立つマスを選ぶのに使っている値（docs/cpu-ai.md の「危険の見積もり」）。対戦の状態は変えない。
func danger(battle: Battle, unit_id: int, cell: Vector2i) -> int:
	var unit := battle.unit_by_id(unit_id)
	if unit == null or unit.side != battle.phase or battle.phase == Unit.Side.NEUTRAL or battle.is_over():
		return 0
	_begin(battle)
	_build_threats()
	var result := _threat_at(unit, cell, 0)
	_battle = null
	return result


func _decide() -> BattleAction:
	var evolving := _battle.evolving_unit()
	if evolving != null:
		return _choose_evolution(evolving)
	if Ults.can_use(_battle) and call(ULT_USES[Ults.of(_battle, _me).id()]):
		return UseUltAction.new()
	var acting := _battle.unit_by_id(_battle.acting_unit_id)
	if acting != null:
		return _follow_up(acting)
	var unit := _next_unit()
	if unit == null:
		return EndPhaseAction.new()
	return _plan(unit)


## 考えた行動が受け付けられなかったときの逃げ道（ふつうは通らない）。待機できる駒を待機させ、いなければフェーズを終える。
func _fallback(battle: Battle) -> BattleAction:
	var evolving := battle.evolving_unit()
	if evolving != null:
		return battle.options(evolving.id).actions()[0]
	for unit in battle.units:
		if battle.can_act(unit):
			return WaitAction.new(unit.id)
	return EndPhaseAction.new()


func _begin(battle: Battle) -> void:
	_battle = battle
	_me = battle.phase
	_foe = (1 - _me) as Unit.Side
	_threats = {}
	_close_threats = {}
	_smoked = {}
	_foe_stops = {}
	_moved_threats = {}
	_stand = Board.NO_CELL
	_threats_ready = false
	_hunts_ready = false
	_thinking_id = 0
	var board := battle.board
	var has_hqs := board.hq_cells.size() >= 2
	_my_hq = board.hq_cells[_me] if has_hqs else Board.NO_CELL
	_foe_hq = board.hq_cells[_foe] if has_hqs else Board.NO_CELL
	_hq_in_danger = false
	var keeper := battle.unit_at(_my_hq) if has_hqs else null
	if has_hqs and (keeper == null or keeper.kind != UnitKind.Id.KING):
		for unit in battle.units:
			if unit.side == _foe and Combat.distance(unit.cell, _my_hq) <= GUARD_RADIUS:
				_hq_in_danger = true
	# 駒が乗っているポータルは、いまは通れない（Battle.portal_exit）。通れる前提で道を見積もると、
	# ふさがったポータルの前で待ち続けてしまう。
	var blocked: Array[Vector2i] = []
	for cell in board.portal_exits:
		if battle.unit_at(cell) != null:
			blocked.append(cell)
	if board != _board or board.walkable_revision != _walkable_revision or blocked != _blocked_portals:
		# 盤面が替わったか、入れるマスが変わった（樽が消えた、盾が置かれた・消えた）か、ふさがったポータルが変わった。
		_board = board
		_walkable_revision = board.walkable_revision
		_blocked_portals = blocked
		_steps = {}
		_walkable.resize(board.size.x * board.size.y)
		for y in board.size.y:
			for x in board.size.x:
				_walkable[y * board.size.x + x] = 1 if board.move_cost(Vector2i(x, y)) >= 0 else 0


# ---- 進化先 ----


## 進化先を選ぶ。駒とターンで A・B を選び分ける（どちらの型も盤に出るように）。
func _choose_evolution(unit: Unit) -> BattleAction:
	var choices := _battle.options(unit.id).evolutions
	if choices.is_empty():
		return null
	return EvolveAction.new(unit.id, choices[(unit.id + _battle.turn) % choices.size()])


# ---- 必殺技 ----


## いちばん近い敵の駒（中立を除く）までの距離（マンハッタン距離。地形は見ない目安）。いなければ _FAR。
func _nearest_foe_distance(unit: Unit) -> int:
	var nearest := _FAR
	for other in _battle.units:
		if other.side == _foe:
			nearest = mini(nearest, Combat.distance(unit.cell, other.cell))
	return nearest


## 総員突撃を、いま使うか。まだ行動していない戦う駒（前衛・後衛・奇襲。1 体もいなければ将）のうち、
## 伸びた移動力 + 射程の中に敵の駒がいる駒を数える。
func _assault_pays() -> bool:
	var fighters := 0
	var ready := 0
	var lone := not _has_fighters()
	for unit in _battle.units:
		if unit.side != _me:
			continue
		var role := UnitKind.role(unit.kind)
		if role == UnitKind.Role.HEALER or (unit.kind == UnitKind.Id.KING and not lone):
			continue
		fighters += 1
		if unit.acted or unit.has_moved:
			continue
		var reach := unit.move_range() + AllOutAssaultUlt.MOVE_BONUS + Statuses.stat_after_move(unit, Unit.Stat.ATTACK_RANGE)
		if _nearest_foe_distance(unit) <= reach:
			ready += 1
	return ready > 0 and ready >= mini(ASSAULT_MIN_UNITS, fighters)


## 魔力解放を、いま使うか。まだ行動していない駒のうち、クールダウンが長く残っていて、敵の駒が近くにいる駒を数える。
func _eruption_pays() -> bool:
	var holders := 0
	var waiting := 0
	for unit in _battle.units:
		if unit.side != _me or Skills.of(unit) == null or Skills.uses_left(unit) == 0:
			continue
		holders += 1
		if unit.acted or unit.cruised or unit.skill_cooldown < ERUPTION_MIN_COOLDOWN:
			continue
		if _nearest_foe_distance(unit) <= ERUPTION_RADIUS:
			waiting += 1
	return waiting > 0 and waiting >= mini(ERUPTION_MIN_UNITS, holders)


# ---- 駒を選ぶ ----


## 次に動かす駒。役割の順（ROLE_ORDER）、同じ役割なら番号の順。いなければ null。
func _next_unit() -> Unit:
	var best: Unit = null
	var best_key := Vector2i(_FAR, 0)
	for unit in _battle.units:
		if not _battle.can_act(unit):
			continue
		var key := Vector2i(ROLE_ORDER.find(UnitKind.role(unit.kind)), unit.id)
		if key < best_key:
			best = unit
			best_key = key
	return best


# ---- 動いたあとの行動 ----


## 動いたあとの駒が、いまの位置からすること。得になる攻撃・回復・スキルがあれば、いちばん良いもの。無ければ待機。
func _follow_up(unit: Unit) -> BattleAction:
	var best: BattleAction = WaitAction.new(unit.id)
	var best_value := 0.0
	_thinking_id = unit.id
	_build_threats()
	_set_goal(unit)
	_moved_reach = unit.attack_range()
	var here: Dictionary[Vector2i, float] = {unit.cell: 0.0}
	var wanted := _wanted_skill_targets(unit, here)
	var skill := Skills.of(unit)
	var limited := skill != null and SKILL_TARGETS.has(skill.id())
	for action in _battle.options(unit.id).actions():
		if action is MoveAction or action is WaitAction or action is UndoMoveAction:
			continue
		var skill_use := action as UseSkillAction
		if skill_use != null and limited and not wanted.has(skill_use.target):
			continue
		var sim := _battle.clone()
		var value := _outcome_value(sim, sim.apply(action).events)
		if value > best_value:
			best = action
			best_value = value
	return best


# ---- まだ動いていない駒の行動 ----


## まだ動いていない駒の、次の行動。「どこへ動くか」と「そこで何をするか」の組をすべて比べて、最初の 1 手を返す。
## 動く先を決めたら、そこで何をするかは次の呼び出し（_follow_up）がもう一度決める（同じ見積もりを使うので、同じ結論になる）。
func _plan(unit: Unit) -> BattleAction:
	var options := _battle.options(unit.id)
	_thinking_id = unit.id
	_build_threats()
	_set_goal(unit)
	_moved_reach = Statuses.stat_after_move(unit, Unit.Stat.ATTACK_RANGE)

	# 動くだけ（待機）の手。
	var best_cell := unit.cell
	var best_cruise := false
	var best_action: BattleAction = null
	var best_value := _position_value(unit, unit.cell, 0, false)
	var positions: Dictionary[Vector2i, float] = {}
	for cell in options.move_cells:
		var value := _position_value(unit, cell, 0, false)
		positions[cell] = value
		if value > best_value:
			best_cell = cell
			best_value = value
	for cell in options.cruise_cells:
		var value := _position_value(unit, cell, 0, false) - CRUISE_PENALTY
		if value > best_value:
			best_cell = cell
			best_cruise = true
			best_value = value

	# 動いて（動かずに）攻撃・回復する手。
	for candidate in _candidates(unit, positions):
		var action: BattleAction = candidate[0]
		var at: Vector2i = candidate[1]
		var target_id: int = candidate[2]
		var from := _best_cell_in_reach(unit, positions, at, target_id, 0, action is AttackBarrelAction)
		if from == Board.NO_CELL:
			continue
		# その手を複製の上で実際にやってみて、起きたことから価値を読む。
		var sim := _battle.clone()
		if from != unit.cell and not sim.apply(MoveAction.new(unit.id, from)).accepted:
			continue
		var result := sim.apply(action)
		if not result.accepted:
			continue  # 目安では届くはずが、ルールでは届かなかった
		var value := _outcome_value(sim, result.events)
		if value <= 0.0:
			continue
		if target_id != 0 and sim.unit_by_id(target_id) == null:
			# 相手を倒せる。その相手からの反撃は無いものとして、立つマスを選び直す。
			from = _best_cell_in_reach(unit, positions, at, target_id, target_id, false)
			value += _position_value(unit, from, target_id, true)
		else:
			value += _position_value(unit, from, 0, true)
		if value > best_value:
			best_cell = from
			best_cruise = false
			best_action = action
			best_value = value

	# 動いて（動かずに）スキルを使う手。
	for candidate in _skill_candidates(unit, options, positions):
		var from: Vector2i = candidate[0]
		var action := UseSkillAction.new(unit.id, candidate[1])
		var sim := _battle.clone()
		if from != unit.cell and not sim.apply(MoveAction.new(unit.id, from)).accepted:
			continue
		var result := sim.apply(action)
		if not result.accepted:
			continue  # 目安では使えるはずが、ルールでは使えなかった
		_stand = from
		var value := _outcome_value(sim, result.events)
		_stand = Board.NO_CELL
		if value <= 0.0:
			continue
		value += _position_value(unit, from, 0, true)
		if value > best_value:
			best_cell = from
			best_cruise = false
			best_action = action
			best_value = value

	if best_cell != unit.cell:
		return MoveAction.new(unit.id, best_cell, best_cruise)
	if best_action != null:
		return best_action
	return WaitAction.new(unit.id)


## スキルを使う手の候補。[立つマス, 対象のマス] の列。対象ごとに、そこを選べるマスのうち、立つマスの価値がいちばん高いもの。
## - 対象は、スキルごとの「選ぶ価値のありそうなマス」（SKILL_TARGETS）に絞る
## - いまのマスから選べる対象は Battle.options() の skill_cells。ほかのマスからは、そこへ動いた写しの駒でスキルの定義に聞く
##   （Skill.is_ready、Skill.target_cells）。広めに並べるだけで、使えるかどうかは _plan が複製の上で確かめる
func _skill_candidates(unit: Unit, options: UnitOptions, positions: Dictionary[Vector2i, float]) -> Array[Array]:
	var result: Array[Array] = []
	var skill := Skills.of(unit)
	if skill == null or not Skills.can_use(_battle, unit):
		return result
	var limited := SKILL_TARGETS.has(skill.id())
	var wanted := _wanted_skill_targets(unit, positions)
	if limited and wanted.is_empty():
		return result
	var best_from: Dictionary[Vector2i, Vector2i] = {}
	var best_value: Dictionary[Vector2i, float] = {}
	var probe := unit.copy()
	probe.has_moved = true
	probe.move_origin = unit.cell
	for cell in positions:
		var targets := options.skill_cells
		if cell != unit.cell:
			probe.cell = cell
			if not skill.is_ready(_battle, probe):
				continue
			targets = skill.target_cells(_battle, probe)
		var value := _position_value(unit, cell, 0, true)
		for target in targets:
			if limited and not wanted.has(target):
				continue
			if value > best_value.get(target, -INF):
				best_value[target] = value
				best_from[target] = cell
	for target in best_from:
		result.append([best_from[target], target])
	return result


## unit のスキルの、対象に選ぶ価値のありそうなマス（SKILL_TARGETS のメソッドの答え）。
## スキルを持たない・いま使えない駒と、SKILL_TARGETS に載せていないスキルでは空（載せていないスキルは、呼ぶ側が絞らずに全部試す）。
## cells は、unit が立つかもしれないマス（_plan では通常の移動で止まれるマス、_follow_up ではいまのマスだけ）。
func _wanted_skill_targets(unit: Unit, cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var skill := Skills.of(unit)
	var wanted: Dictionary[Vector2i, bool] = {}
	if skill == null or not SKILL_TARGETS.has(skill.id()) or not Skills.can_use(_battle, unit):
		return wanted
	_build_threats()
	wanted = call(SKILL_TARGETS[skill.id()], unit, cells)
	return wanted


## 攻撃・回復の候補。[行動, 相手のマス, 相手の駒の番号（樽と盾は 0）] の列。
## cells（通常の移動で止まれるマス。ポータルの先も含む）のどれかから、射程の歩数の中にいる相手を並べる。
## 広めに並べるだけで、届くかどうかはルールに聞く（_plan が複製の上で確かめる）。
func _candidates(unit: Unit, cells: Dictionary[Vector2i, float]) -> Array[Array]:
	var result: Array[Array] = []
	var healer := UnitKind.role(unit.kind) == UnitKind.Role.HEALER
	for other in _battle.units:
		if other == unit or not _in_reach(unit, cells, other.cell):
			continue
		if healer:
			if other.side == _me and other.hp < other.max_hp():
				result.append([HealAction.new(unit.id, other.id), other.cell, other.id])
		elif other.side != _me:
			result.append([AttackAction.new(unit.id, other.id), other.cell, other.id])
	if not healer:
		for cell in _battle.board.barrel_cells:
			if _in_reach(unit, cells, cell):
				result.append([AttackBarrelAction.new(unit.id, cell), cell, 0])
		for effect in _battle.board.field_effects:
			if effect.type == FieldEffect.Type.BARRICADE and effect.side != _me and _in_reach(unit, cells, effect.center):
				result.append([AttackBarricadeAction.new(unit.id, effect.center), effect.center, 0])
	return result


## cells のどれかから、at が射程の歩数の中にあるか。
func _in_reach(unit: Unit, cells: Dictionary[Vector2i, float], at: Vector2i) -> bool:
	for cell in cells:
		if Combat.distance(cell, at) <= _reach_from(unit, cell):
			return true
	return false


## unit が cell から手を出すときの射程。いまのマスなら、いまの射程。ほかのマスなら、動いたあとの射程。
func _reach_from(unit: Unit, cell: Vector2i) -> int:
	return unit.attack_range() if cell == unit.cell else _moved_reach


## cells（通常の移動で止まれるマス）のうち、at に手が届き、そこで手を出すのにいちばん良いマス。無ければ Board.NO_CELL。
## 攻撃は、間に盾があるマスと、相手（target_id の駒。樽と盾なら 0）が煙幕に守られるマスを除く（ルールの問い合わせで見る）。
## ignored_id の敵からの危険は数えない。avoid_blast が真なら、at の周り 8 マス（樽の爆発が届く）をなるべく避ける。
func _best_cell_in_reach(
	unit: Unit, cells: Dictionary[Vector2i, float], at: Vector2i, target_id: int, ignored_id: int, avoid_blast: bool
) -> Vector2i:
	var healer := UnitKind.role(unit.kind) == UnitKind.Role.HEALER
	var target := _battle.unit_by_id(target_id)
	var best := Board.NO_CELL
	var best_value := -INF
	for cell in cells:
		var reach := _reach_from(unit, cell)
		if healer:
			if Combat.distance(cell, at) > reach:
				continue
		elif not Combat.reaches(_battle, cell, at, reach):
			continue
		elif target != null and FieldEffects.smoke_covering(_battle, cell, target) != null:
			continue
		var value := _position_value(unit, cell, ignored_id, true)
		if avoid_blast and maxi(absi(cell.x - at.x), absi(cell.y - at.y)) <= 1:
			value -= WIN_VALUE
		if value > best_value:
			best = cell
			best_value = value
	return best


# ---- 行動の結果の価値 ----


## 行動を複製（sim）に apply したあとの、その行動の価値。events はそのとき起きたこと。
## 駒が誰のものだったかは、行動の前の状態（_battle）で見る（倒れた駒は sim にもういない）。
func _outcome_value(sim: Battle, events: Array[BattleEvent]) -> float:
	if sim.is_over():
		if sim.is_draw():
			return DRAW_VALUE
		return WIN_VALUE if sim.winner == _me else -WIN_VALUE
	var value := 0.0
	for event in events:
		var damaged := event as UnitDamagedEvent
		if damaged != null:
			var victim := _battle.unit_by_id(damaged.unit_id)
			var worth := _damage_value(victim, damaged.hp)
			value += -FRIENDLY_FIRE_RATE * worth if victim.side == _me else worth
			continue
		var healed := event as UnitHealedEvent
		if healed != null:
			var target := _battle.unit_by_id(healed.unit_id)
			value += HEAL_VALUE * healed.amount + HEAL_BASE_VALUE
			value += WOUNDED_BONUS * (1.0 - float(target.hp) / target.max_hp())
			if target.kind == UnitKind.Id.KING:
				value += KING_HEAL_BONUS
			continue
		var used := event as SkillUsedEvent
		if used != null:
			if SKILL_VALUES.has(used.skill):
				value += call(SKILL_VALUES[used.skill], used, sim)
			continue
		var chipped := event as BarricadeDamagedEvent
		if chipped != null:
			value += BARRICADE_DAMAGE_VALUE * chipped.amount
			continue
		var stripped := event as StatusRemovedEvent
		if stripped != null:
			if stripped.reason == StatusRemovedEvent.Reason.CONSUMED and Status.blocks_damage(stripped.status):
				value += _barrier_strip_value(stripped.unit_id, sim)
			continue
		var removed := event as FieldEffectRemovedEvent
		if removed != null:
			if removed.reason == FieldEffectRemovedEvent.Reason.DESTROYED:
				value += BARRICADE_BREAK_VALUE
			continue
		var gained := event as ExperienceGainedEvent
		if gained != null:
			value += EXPERIENCE_VALUE * gained.amount
		elif event is LevelUpEvent:
			value += LEVEL_UP_VALUE
	return value


## victim の HP を hp_after まで減らす価値（victim は減らす前の状態）。
func _damage_value(victim: Unit, hp_after: int) -> float:
	var rate := DAMAGE_VALUE
	var kill := KILL_VALUE + KILL_VALUE_PER_COST * UnitKind.cost(victim.kind)
	if victim.kind == UnitKind.Id.ELITE_MINION:
		return _mid_boss_damage_value(victim, hp_after)
	elif victim.side == Unit.Side.NEUTRAL:
		rate = NEUTRAL_DAMAGE_VALUE
		kill = NEUTRAL_KILL_VALUE
	elif victim.kind == UnitKind.Id.KING:
		rate = KING_DAMAGE_VALUE
	elif UnitKind.role(victim.kind) == UnitKind.Role.HEALER:
		kill += HEALER_KILL_BONUS
	if victim.side == _foe and _my_hq != Board.NO_CELL:
		if victim.cell == _my_hq:
			rate *= OCCUPIER_RATE
			kill += OCCUPIER_KILL_BONUS
		elif Combat.distance(victim.cell, _my_hq) <= DEFENSE_RADIUS:
			rate *= INTRUDER_RATE
	var value := rate * (victim.hp - hp_after)
	if hp_after == 0:
		return value + kill
	return maxf(1.0, value - REMAINING_HP_PENALTY * hp_after)


## 中ボス boss の HP を hp_after まで減らす価値。倒す価値は、聖遺物の価値（_relic_value）。
## 削る価値は、狩ると決めた中ボスだけ（HUNT_DAMAGE_VALUE）。狩ると決めていない中ボスは、削らない（MID_BOSS_IDLE_PENALTY を引く。
## 倒しきれないのに削ると、殴り返されるうえに、止めを相手に渡す）。止めを相手に渡す削りは、MID_BOSS_FEED_PENALTY を引く。
func _mid_boss_damage_value(boss: Unit, hp_after: int) -> float:
	_build_hunts()
	if hp_after == 0:
		return HUNT_DAMAGE_VALUE * boss.hp + _relic_value()
	if not _chipped.has(boss.id):
		return -MID_BOSS_IDLE_PENALTY
	var value := HUNT_DAMAGE_VALUE * (boss.hp - hp_after)
	if hp_after <= _rival_strike.get(boss.id, 0) and _follow_up_strike(boss) < hp_after:
		value -= MID_BOSS_FEED_PENALTY
	return value


## 聖遺物を受け取る価値（どちらの聖遺物も同じに見る）。効果は自分の駒の数だけ掛かる。
func _relic_value() -> float:
	var count := 0
	for unit in _battle.units:
		if unit.side == _me:
			count += 1
	return RELIC_BASE_VALUE + RELIC_UNIT_VALUE * count


## このフェーズに、いま考えている駒のあとで boss に届きそうな味方（まだ行動していない戦う駒。移動力 + 射程の中。目安）の攻撃力の合計。
func _follow_up_strike(boss: Unit) -> int:
	var total := 0
	for friend in _battle.units:
		if friend.side != _me or friend.id == _thinking_id or friend.acted or _is_healer(friend):
			continue
		if Combat.distance(friend.cell, boss.cell) <= friend.move_range() + friend.attack_range():
			total += friend.power()
	return total


func _is_healer(unit: Unit) -> bool:
	return UnitKind.role(unit.kind) == UnitKind.Role.HEALER


## 中ボスごとに、狩るか（_hunted。値は、もう削り切れるところまで来ているか）、相手が狩っているか（_rival_hunts）、
## 次の相手の番に届きそうな相手の攻撃力（_rival_strike）を読む。条件は、調整値の HUNT_* のところ。
## 距離は目安（自分の駒は歩数、相手の駒はマンハッタン距離。地形は見ない）。
func _build_hunts() -> void:
	if _hunts_ready:
		return
	_hunts_ready = true
	_hunted = {}
	_chipped = {}
	_rival_hunts = {}
	_rival_strike = {}
	var home_threat := false
	if _my_hq != Board.NO_CELL:
		for foe in _battle.units:
			if foe.side == _foe and Combat.distance(foe.cell, _my_hq) <= GUARD_RADIUS:
				home_threat = true
	var width := _board.size.x
	for boss in _battle.units:
		if boss.kind != UnitKind.Id.ELITE_MINION:
			continue
		var steps := _steps_from(boss.cell)
		# 狩りに加われる自分の駒の [着くまでのターン数, 攻撃力]。全部と、手の空いている駒だけ。
		var squad: Array[Vector2i] = []
		var free_squad: Array[Vector2i] = []
		var foes: Array[Unit] = []
		var strike := 0
		var near_rivals := 0
		for other in _battle.units:
			if other.side == Unit.Side.NEUTRAL or _is_healer(other):
				continue
			if other.side == _foe:
				var apart := Combat.distance(other.cell, boss.cell)
				if apart <= other.move_range() + other.attack_range():
					strike += other.power()
				if other.kind != UnitKind.Id.KING:
					foes.append(other)
					if apart <= HUNT_RIVAL_RADIUS:
						near_rivals += other.power()
			elif other.kind != UnitKind.Id.KING:
				var away := steps[other.cell.y * width + other.cell.x]
				if away > HUNT_RADIUS:
					continue
				var member := Vector2i(ceili(float(maxi(0, away - other.attack_range())) / maxi(1, other.move_range())), other.power())
				squad.append(member)
				if _nearest_foe_distance(other) > HUNT_ENGAGE_DISTANCE:
					free_squad.append(member)
		_rival_strike[boss.id] = strike
		if near_rivals > 0 and boss.hp < boss.max_hp() and near_rivals * HUNT_TURNS >= boss.hp:
			_rival_hunts[boss.id] = true
		if home_threat or _battle.turn < HUNT_FROM_TURN:
			continue
		var need := ceili(boss.hp * HUNT_MARGIN)
		# 加われる駒の全部で倒せるなら、届いた駒は削ってよい。
		if _outguns_rivals(boss, squad, foes, _kill_turns(squad, need, HUNT_TURNS)):
			_chipped[boss.id] = true
		# 向かうのは、手の空いている駒だけで倒せるとき。もう削り切れるところまで来ていれば、全部の駒が向かう。
		if _outguns_rivals(boss, squad, foes, _kill_turns(squad, need, HUNT_COMMIT_TURNS)):
			_hunted[boss.id] = true
		elif _outguns_rivals(boss, free_squad, foes, _kill_turns(free_squad, need, HUNT_TURNS)):
			_hunted[boss.id] = false


## squad が turns ターンで boss を倒しきるまでに、ここへ着ける相手の戦う駒（foes のうち、turns × 移動力 + 射程の中）の
## 攻撃力の合計の HUNT_SUPERIORITY 倍以上の攻撃力が、squad にあるか。turns が 0（倒せない）なら偽。
func _outguns_rivals(boss: Unit, squad: Array[Vector2i], foes: Array[Unit], turns: int) -> bool:
	if turns == 0:
		return false
	var power := 0
	for member in squad:
		power += member.y
	var rivals := 0
	for foe in foes:
		if Combat.distance(foe.cell, boss.cell) <= turns * foe.move_range() + foe.attack_range():
			rivals += foe.power()
	return power >= HUNT_SUPERIORITY * rivals


## squad（[着くまでのターン数, 攻撃力] の列）が、着いた順に毎ターン殴って、合わせて need のダメージを与えるまでのターン数。
## limit ターンでは足りなければ 0。
func _kill_turns(squad: Array[Vector2i], need: int, limit: int) -> int:
	for turns in range(1, limit + 1):
		var dealt := 0
		for member in squad:
			dealt += member.y * maxi(0, turns - member.x)
		if dealt >= need:
			return turns
	return 0


## unit が狩りに向かう中ボス（いなければ null）。狩ると決めた中ボスのうち、HUNT_RADIUS 歩以内で、いちばん近いもの。
## 手の空いていない駒（HUNT_ENGAGE_DISTANCE マス以内に相手の駒がいる）は、もう削り切れるところまで来た中ボスにだけ向かう。
func _boss_to_hunt(unit: Unit) -> Unit:
	_build_hunts()
	if _hunted.is_empty():
		return null
	var engaged := _nearest_foe_distance(unit) <= HUNT_ENGAGE_DISTANCE
	var best: Unit = null
	var best_steps := HUNT_RADIUS + 1
	var from := _steps_from(unit.cell)
	for boss_id in _hunted:
		if engaged and not _hunted[boss_id]:
			continue
		var boss := _battle.unit_by_id(boss_id)
		var steps := from[boss.cell.y * _board.size.x + boss.cell.x]
		if steps < best_steps:
			best = boss
			best_steps = steps
	return best


## unit が止めを横取りしに向かう中ボス（いなければ null）。相手が狩っていて、HP が STEAL_HP まで減った中ボスのうち、
## DENY_RADIUS マス以内で、いちばん近いもの。向かうのは、後衛と奇襲だけ（離れて撃てるか、速い）。
func _boss_to_steal(unit: Unit) -> Unit:
	_build_hunts()
	var best: Unit = null
	var best_distance := DENY_RADIUS + 1
	for boss_id in _rival_hunts:
		var boss := _battle.unit_by_id(boss_id)
		var apart := Combat.distance(unit.cell, boss.cell)
		if boss.hp <= STEAL_HP and apart < best_distance:
			best = boss
			best_distance = apart
	return best


## 駒 victim_id のバリアが外れた価値（sim は、外れたあとの複製）。敵のバリアをはがしたなら、このあとに動ける味方のうち、
## その敵に届きそうな駒（移動力 + 射程の歩数の中。目安）のいちばん強い攻撃 1 回ぶんを見込む。味方のバリアなら、同じだけ引く。
func _barrier_strip_value(victim_id: int, sim: Battle) -> float:
	var victim := sim.unit_by_id(victim_id)
	if victim == null or victim.side == Unit.Side.NEUTRAL:
		return 0.0
	if victim.side == _me:
		return -BARRIER_STRIP_VALUE
	var strongest := 0
	for friend in sim.units:
		if friend.side != _me or not sim.can_act(friend) or friend.id == sim.acting_unit_id:
			continue
		if UnitKind.role(friend.kind) == UnitKind.Role.HEALER:
			continue
		if Combat.distance(friend.cell, victim.cell) <= friend.move_range() + friend.attack_range():
			strongest = maxi(strongest, Combat.attack_power(friend))
	var rate := KING_DAMAGE_VALUE if victim.kind == UnitKind.Id.KING else DAMAGE_VALUE
	return BARRIER_STRIP_VALUE + BARRIER_STRIP_RATE * rate * mini(strongest, victim.hp)


# ---- スキルの価値 ----


## 盾を置いた価値。置いたあとの盤面（sim）で危険を数え直して、味方が次の相手の番に受けうるダメージ（HP まで）の
## 減るぶんを見込む。通路をふさいで敵が寄れなくなるぶんも、離れた攻撃の射線を切るぶんも、ここに入る。
## 倒されうる味方（将を除く）が倒されなくなるなら、その駒の役割の「倒されうるマス」の重さを足す。
## いま届いている味方の離れた攻撃が、盾で届かなくなるぶんは引く（置く前と置いたあとのルールの答えを比べる）。
func _barricade_value(used: SkillUsedEvent, sim: Battle) -> float:
	_build_threats()
	var threats: Dictionary[Vector2i, Dictionary] = {}
	var close: Dictionary[Vector2i, Dictionary] = {}
	_fill_threats(sim, threats, close, {})
	# 比べる相手は「同じマスに立って、盾を置かなかったとき」。動いてから置く手では、動いただけの盤面で数え直す
	# （前衛は、立つだけでも道をふさぐ。そのぶんを盾の手柄にしない）。
	var threats_before := _threats
	var close_before := _close_threats
	var user := _battle.unit_by_id(used.unit_id)
	if _stand != Board.NO_CELL and _stand != user.cell:
		if not _moved_threats.has(_stand):
			var moved_state := _battle.clone()
			moved_state.apply(MoveAction.new(user.id, _stand))
			var moved_threats: Dictionary[Vector2i, Dictionary] = {}
			var moved_close: Dictionary[Vector2i, Dictionary] = {}
			_fill_threats(moved_state, moved_threats, moved_close, {})
			_moved_threats[_stand] = [moved_threats, moved_close]
		threats_before = _moved_threats[_stand][0]
		close_before = _moved_threats[_stand][1]
	var value := 0.0
	for friend in sim.units:
		if friend.side != _me:
			continue
		var before := mini(friend.hp, _danger_in(threats_before, close_before, friend, friend.cell, 0))
		var after := mini(friend.hp, _danger_in(threats, close, friend, friend.cell, 0))
		var rate := KING_DAMAGE_VALUE if friend.kind == UnitKind.Id.KING else DAMAGE_VALUE
		value += BARRICADE_COVER_RATE * rate * (before - after)
		if before >= friend.hp and after < friend.hp and friend.kind != UnitKind.Id.KING:
			# 倒されうる味方が、倒されなくなる（将は、自分で逃げる）。その駒の「倒されうるマス」の重さを足す。
			value += STYLES[UnitKind.role(friend.kind)][_LETHAL]
	for shooter in _battle.units:
		if shooter.side != _me or shooter.attack_range() < Combat.RANGED_DISTANCE:
			continue
		var moved := sim.unit_by_id(shooter.id)
		if moved.cell != shooter.cell:
			continue  # 盾を置いた駒自身（動いてから置いた）
		for target in _battle.units:
			if target.side != _foe or not Combat.can_attack(_battle, shooter, target):
				continue
			if not Combat.can_attack(sim, moved, sim.unit_by_id(target.id)):
				var rate := KING_DAMAGE_VALUE if target.kind == UnitKind.Id.KING else DAMAGE_VALUE
				value -= BARRICADE_COVER_RATE * rate * shooter.power()
	return value


## 盾を置く価値のありそうなマス。危険のある味方がいるときだけ、次の 2 通りを、unit に近い順に BARRICADE_TRIES か所まで。
## - 次の相手の番に敵が止まれるマスのうち、通路のようなマス（上下左右の入れるマスが 2 つ以下）。ふさげば、敵が寄れなくなる
## - 離れた敵（射程 2 以上）に狙われている味方の、その敵の側の隣のマス。射線が切れる
func _barricade_targets(unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var found: Dictionary[Vector2i, bool] = {}
	var width := _board.size.x
	var endangered := false
	for friend in _battle.units:
		if friend.side != _me or not _threats.has(friend.cell):
			continue
		endangered = true
		var by: Dictionary = _threats[friend.cell]
		for enemy_id: int in by:
			var enemy := _battle.unit_by_id(enemy_id)
			if enemy == null or enemy.attack_range() < Combat.RANGED_DISTANCE:
				continue
			var apart := Combat.distance(friend.cell, enemy.cell)
			for direction in Board.DIRECTIONS:
				var near := friend.cell + direction
				if Combat.distance(near, enemy.cell) < apart:
					found[near] = true
	if not endangered:
		return found
	var reach := unit.move_range() + TacticalBarricadeSkill.PLACE_DISTANCE * 2
	for cell in _foe_stops:
		if Combat.distance(cell, unit.cell) > reach:
			continue
		var open := 0
		for direction in Board.DIRECTIONS:
			var near := cell + direction
			if _board.in_bounds(near) and _walkable[near.y * width + near.x] == 1:
				open += 1
		if open <= 2:
			found[cell] = true
	var cells: Array[Vector2i] = []
	cells.assign(found.keys())
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Combat.distance(a, unit.cell)
		var db := Combat.distance(b, unit.cell)
		return da < db or (da == db and Board.in_reading_order(a, b)))
	var wanted: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		if wanted.size() >= BARRICADE_TRIES:
			break
		if FieldEffects.can_place_barricade(_battle, cell) or cell == unit.cell:
			wanted[cell] = true
	return wanted


## 聖域を置く価値のありそうな中心: 減っている味方（もう自分の聖域の中にいる駒は除く）を中に入れられるマス。
func _sanctuary_targets(unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	var skill := Skills.of(unit)
	for friend in _battle.units:
		if friend.side != _me or friend.hp >= friend.max_hp() or FieldEffects.sanctuary_of(_battle, friend) != null:
			continue
		# 3 x 3 は対称なので、「friend を中心にしたときに効果が及ぶマス」が「friend を中に入れられる中心」になる。
		for cell in skill.affected_cells(_battle, unit, friend.cell):
			wanted[cell] = true
	return wanted


## 煙幕を置く価値のありそうな中心: 煙幕が防ぐ攻撃に狙われている味方（もう自分の煙幕の中にいる駒は除く）を中に入れられるマス。
func _smoke_targets(unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	var skill := Skills.of(unit)
	for friend in _battle.units:
		if friend.side != _me or _smoked.has(friend.cell) or _smoke_saves(friend.cell) <= 0:
			continue
		for cell in skill.affected_cells(_battle, unit, friend.cell):
			wanted[cell] = true
	return wanted


## ファイアボールを撃つ価値のありそうな中心: 敵（中立の駒も）のどれかに当たるマス。
func _fireball_targets(unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	var skill := Skills.of(unit)
	for other in _battle.units:
		if other.side == _me:
			continue
		# 十字は対称なので、「other を中心にしたときに効果が及ぶマス」が「other に当たる中心」になる。
		for cell in skill.affected_cells(_battle, unit, other.cell):
			wanted[cell] = true
	return wanted


## バリアを張る価値のありそうなマス（自分のマスが対象）: 立てるマスのうち、次の相手の番に攻撃されうるマスを、
## 立つマスの価値の高い順に BARRIER_TRIES か所。いまのマスは、攻撃されうるなら必ず入れる。
func _barrier_targets(unit: Unit, cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	if Statuses.blocking(unit) != -1:
		return wanted
	var ranked: Array[Array] = []
	for cell in cells:
		if _threat_at(unit, cell, 0) > 0:
			ranked.append([_position_value(unit, cell, 0, true), cell])
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] or (a[0] == b[0] and Board.in_reading_order(a[1], b[1])))
	for entry: Array in ranked.slice(0, BARRIER_TRIES):
		wanted[entry[1]] = true
	if _threat_at(unit, unit.cell, 0) > 0:
		wanted[unit.cell] = true
	return wanted


## 照準は、動かずに構える（いまのマスだけ）。
func _aim_targets(unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	return {unit.cell: true}


## シャドウステップで跳ぶ価値のありそうなマス:
## - 歩いては攻撃が届かない敵（相手のプレイヤーの駒）を、攻撃できるマス（歩いて届く敵は、歩いて攻撃する手が比べている）。
##   中立の駒を殴るためには跳ばない（跳べるのは数ターンに 1 回。相手の駒のために取っておく）
## - 空いている敵の本陣
## - 自分の本陣に乗っている敵のマス（入れ替わって、占拠を切る）
func _shadow_step_targets(unit: Unit, cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	var reach := _moved_reach if cells.size() > 1 else unit.attack_range()
	for other in _battle.units:
		if other.side != _foe:
			continue
		if other.cell == _my_hq:
			wanted[other.cell] = true
		if cells.size() > 1 and _in_reach(unit, cells, other.cell):
			continue
		for dy in range(-reach, reach + 1):
			for dx in range(-reach + absi(dy), reach - absi(dy) + 1):
				wanted[other.cell + Vector2i(dx, dy)] = true
	if _foe_hq != Board.NO_CELL and _battle.unit_at(_foe_hq) == null:
		wanted[_foe_hq] = true
	return wanted


## アドレナリン注射の対象: 行動済みの味方（回復役と将も、ルールが選ばせるなら試す）。
func _adrenaline_targets(unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	for friend in _battle.units:
		if friend.side == _me and friend != unit and friend.acted:
			wanted[friend.cell] = true
	return wanted


## 聖域を置いた価値。中にいる、減っている味方（もう自分の聖域の中にいる駒は除く）の、見込める回復量。
## 減っている味方が SANCTUARY_MIN_UNITS 体に満たなければ 0（回復役は、ふつうの回復のほうが早い）。
func _sanctuary_value(used: SkillUsedEvent, sim: Battle) -> float:
	var cells := Skills.by_id(used.skill).affected_cells(sim, sim.unit_by_id(used.unit_id), used.target)
	var wounded := 0
	var total := 0
	for unit in sim.units:
		if unit.side != _me or not cells.has(unit.cell) or _in_own_sanctuary(unit.cell):
			continue
		var missing := unit.max_hp() - unit.hp
		if missing > 0:
			wounded += 1
			total += mini(missing, FieldEffects.SANCTUARY_HEAL * SANCTUARY_EXPECTED_HEALS)
	return HEAL_VALUE * total if wounded >= SANCTUARY_MIN_UNITS else 0.0


## cell が、置く前から自分の聖域の中か。
func _in_own_sanctuary(cell: Vector2i) -> bool:
	for effect in _board.field_effects:
		if effect.type == FieldEffect.Type.SANCTUARY and effect.side == _me and effect.cells.has(cell):
			return true
	return false


## cell に立つ味方について、煙幕が防げるダメージ（離れたところからしか届かない攻撃のぶん）。
func _smoke_saves(cell: Vector2i) -> int:
	var by: Dictionary = _threats.get(cell, {})
	var close: Dictionary = _close_threats.get(cell, {})
	var saved := 0
	for enemy_id: int in by:
		saved += by[enemy_id] - close.get(enemy_id, 0)
	return saved


## 煙幕を置いた価値。中にいる味方（もう自分の煙幕の中にいる駒は除く）のうち、次の相手の番に、煙幕が防ぐ攻撃
## （離れたところからしか届かない攻撃）に狙われうる駒を数え、防げるダメージを見込む。
## 隣まで寄れる敵の攻撃と、スキルのダメージは防げないので数えない（_close_threats）。
## 狙われている味方が SMOKE_MIN_UNITS 体に満たなければ 0。
func _smoke_value(used: SkillUsedEvent, sim: Battle) -> float:
	_build_threats()
	var cells := Skills.by_id(used.skill).affected_cells(sim, sim.unit_by_id(used.unit_id), used.target)
	var covered := 0
	var value := 0.0
	for unit in sim.units:
		if unit.side != _me or not cells.has(unit.cell) or _smoked.has(unit.cell):
			continue
		var saved := _smoke_saves(unit.cell)
		if saved > 0:
			var rate := KING_DAMAGE_VALUE if unit.kind == UnitKind.Id.KING else DAMAGE_VALUE
			covered += 1
			value += SMOKE_COVER_RATE * rate * mini(saved, unit.hp)
	return value if covered >= SMOKE_MIN_UNITS or value >= SMOKE_MIN_VALUE else 0.0


## バリアを付けた価値。次の相手の番に、いまのマスの自分を攻撃できる敵がいれば、防げる 1 回ぶんを見込む
## （相手は弱い攻撃で先にはがすので、届く攻撃のうち、いちばん弱いもの）。攻撃されそうになければ 0（バリアは期限で消える）。
func _barrier_value(used: SkillUsedEvent, sim: Battle) -> float:
	_build_threats()
	var unit := _battle.unit_by_id(used.unit_id)
	if Statuses.blocking(unit) != -1:
		return 0.0
	var shielded := sim.unit_by_id(used.unit_id)
	var saved := _threat_at(unit, shielded.cell, 0) - _threat_at(shielded, shielded.cell, 0)
	return BARRIER_COVER_RATE * DAMAGE_VALUE * mini(saved, unit.hp)


## 照準を付けた価値。次の自分の番に、構えたマスから強めた攻撃を当てられそうな敵のうち、いちばん価値の高い 1 体ぶん。
## 当てたときのダメージは、構えたあとの複製（sim）のルールの答え（Combat.damage。確定クリティカル、森、煙幕、バリアを通る）。
## - いまの位置から攻撃できる敵は数えない
## - 伸びた射程の中にいる敵は AIM_RATE、相手が 1 回動けば入ってくる距離の敵は AIM_WATCH_RATE（距離は目安。地形は見ない）
func _aim_value(used: SkillUsedEvent, sim: Battle) -> float:
	var unit := _battle.unit_by_id(used.unit_id)
	var aimed := sim.unit_by_id(used.unit_id)
	var best := 0.0
	if Statuses.has(unit, Status.Type.AIM):
		return best  # もう構えている
	for enemy in _battle.units:
		if enemy.side != _foe or Combat.can_attack(_battle, unit, enemy):
			continue
		var rate := AIM_WATCH_RATE
		if Combat.can_attack(sim, aimed, sim.unit_by_id(enemy.id)):
			rate = AIM_RATE
		elif Combat.distance(unit.cell, enemy.cell) > aimed.attack_range() + enemy.move_range():
			continue
		var amount := Combat.damage(sim, aimed, sim.unit_by_id(enemy.id))
		if amount > 0:
			best = maxf(best, rate * _damage_value(enemy, maxi(0, enemy.hp - amount)))
	return best


## シャドウステップで跳んだ価値。跳んだ先から続けてできる攻撃（駒・樽・盾）のうち、いちばん良いものの価値に、
## 立つマスの価値の差（跳んだ先 − いまのマス）を足す。続けてできる攻撃は、跳んだあとの複製（sim）のルールに聞く。
## 攻撃できる相手がいなければ 0（跳ぶだけの手は選ばない）。ただし、次の 2 つは攻撃できなくても数える。
## - 敵の本陣のマスに着く（立つマスの価値に入っている）
## - 自分の本陣に乗っている敵と入れ替わる（占拠が途切れる。OCCUPIER_KILL_BONUS を足す）
func _shadow_step_value(used: SkillUsedEvent, sim: Battle) -> float:
	var unit := _battle.unit_by_id(used.unit_id)
	_build_threats()
	_set_goal(unit)
	var best := 0.0
	var killed_id := 0
	for action in sim.options(used.unit_id).actions():
		if not (action is AttackAction or action is AttackBarrelAction or action is AttackBarricadeAction):
			continue
		var after := sim.clone()
		var value := _outcome_value(after, after.apply(action).events)
		if value > best:
			best = value
			var attack := action as AttackAction
			killed_id = attack.target_id if attack != null and after.unit_by_id(attack.target_id) == null else 0
	var swapped := _battle.unit_at(used.target)
	if swapped != null and swapped.side == _foe and used.target == _my_hq:
		best += OCCUPIER_KILL_BONUS
	if best <= 0.0 and used.target != _foe_hq:
		return 0.0
	var from := _stand if _stand != Board.NO_CELL else unit.cell
	return best + _position_value(unit, used.target, killed_id, true) - _position_value(unit, from, 0, true)


## アドレナリン注射を使った価値。対象が、いまの位置からもう一度手を出したとき（攻撃・樽・盾・回復。動く手とスキルは見ない）の、
## いちばん良い手の価値の ADRENALINE_RATE 倍。その手の価値が ADRENALINE_MIN_VALUE に満たなければ 0。
## できる手は、使ったあとの複製（sim）のルールに聞く。
func _adrenaline_value(used: SkillUsedEvent, sim: Battle) -> float:
	var friend := sim.unit_at(used.target)
	var best := 0.0
	for action in sim.options(friend.id).actions():
		if action is MoveAction or action is WaitAction or action is UndoMoveAction or action is UseSkillAction:
			continue
		var after := sim.clone()
		best = maxf(best, _outcome_value(after, after.apply(action).events))
	return ADRENALINE_RATE * best if best >= ADRENALINE_MIN_VALUE else 0.0


# ---- 位置の価値 ----


## unit が cell に立って行動を終える価値。目標への近さ、敵の本陣、次の相手の番に受けうるダメージで決まる。
## ignored_id の敵からの危険は数えない（この行動で倒す相手）。acting は、そこで攻撃・回復する手か。
## _set_goal と _build_threats のあとに呼ぶ。
func _position_value(unit: Unit, cell: Vector2i, ignored_id: int, acting: bool) -> float:
	var steps := _goal_steps[cell.y * _board.size.x + cell.x]
	var value := -_goal_weight * maxi(0, steps - _goal_reach)
	if _stand_off:
		value += STAND_OFF_VALUE * mini(steps, _goal_reach)
	if cell == _foe_hq and (unit.kind != UnitKind.Id.KING or _lone_king):
		if UnitKind.role(unit.kind) != UnitKind.Role.HEALER:
			value += HQ_VALUE_RAIDER if UnitKind.role(unit.kind) == UnitKind.Role.RAIDER else HQ_VALUE_OTHER
		if unit.cell == cell:
			value += HQ_HOLD_VALUE * _battle.capture_turns[_me]
	if cell == _my_hq and _hq_in_danger and UnitKind.role(unit.kind) != UnitKind.Role.RAIDER:
		value += HQ_GUARD_VALUE
	if not _support.is_empty():
		var apart := _FAR
		for friend_cell in _support:
			apart = mini(apart, Combat.distance(cell, friend_cell))
		value -= ISOLATION_WEIGHT * maxi(0, apart - SUPPORT_DISTANCE)
	var threat := _threat_at(unit, cell, ignored_id)
	value -= (_danger_weight if acting else _idle_danger_weight) * threat
	if threat >= unit.hp:
		value -= _lethal_penalty
	return value


## unit の目標（どこへ近づきたいか）を決めて、_goal_steps、_goal_reach、役割ごとの重み、_stand_off に置く。
## - 将: 自分の本陣。戦える駒が 1 体も残っていなければ、前衛と同じに敵へ向かう
## - 奇襲: 敵の本陣（敵が乗っていれば、そこを攻撃できるところまで）
## - 前衛・後衛: 自分の本陣の近くに入った敵（侵入者）がいれば、そのいちばん近いもの。いなければ、いちばん近い敵の駒
## - 回復: 近くの減っている味方（減っている割合がいちばん大きいもの）。いなければ、いちばん近い味方の戦う駒
func _set_goal(unit: Unit) -> void:
	var role := UnitKind.role(unit.kind)
	_lone_king = unit.kind == UnitKind.Id.KING and not _has_fighters()
	var style: Array = LONE_KING_STYLE if _lone_king else STYLES[role]
	_goal_weight = style[_GOAL]
	_danger_weight = style[_DANGER]
	var bold := clampf(float(_battle.turn - BOLD_FROM_TURN) / (BOLD_BY_TURN - BOLD_FROM_TURN), 0.0, 1.0)
	_idle_danger_weight = lerpf(style[_IDLE_DANGER], minf(style[_DANGER], style[_IDLE_DANGER]), bold)
	_lethal_penalty = style[_LETHAL]
	_stand_off = role == UnitKind.Role.REARGUARD
	_support = []
	var goal := _my_hq if _my_hq != Board.NO_CELL else unit.cell
	_goal_reach = 0
	if unit.kind == UnitKind.Id.KING and not _lone_king:
		pass
	elif role == UnitKind.Role.RAIDER:
		var prey := _prey(unit)
		var boss := _boss_to_hunt(unit)
		if boss == null:
			boss = _boss_to_steal(unit)
		if _can_raid_hq(unit):
			goal = _foe_hq
		elif boss != null:
			goal = boss.cell
			_goal_reach = unit.attack_range()
		elif prey != null:
			goal = prey.cell
			_goal_reach = unit.attack_range()
			for other in _battle.units:
				if other.side == _me and other != unit and UnitKind.role(other.kind) in SUPPORT_ROLES:
					_support.append(other.cell)
	elif role == UnitKind.Role.HEALER:
		var friend := _friend_to_follow(unit)
		if friend != null:
			goal = friend.cell
			_goal_reach = unit.attack_range()
	else:
		var enemy := _enemy_to_chase(unit)
		var boss: Unit = null if _lone_king else _boss_to_hunt(unit)
		if boss == null and role == UnitKind.Role.REARGUARD:
			boss = _boss_to_steal(unit)
		if boss != null:
			goal = boss.cell
			_goal_reach = unit.attack_range()
		elif enemy != null:
			goal = enemy.cell
			_goal_reach = unit.attack_range()
	_goal_steps = _steps_from(goal)


## 自分の軍に、戦える駒（前衛・後衛・奇襲）が残っているか。
func _has_fighters() -> bool:
	for other in _battle.units:
		if other.side == _me and other.kind != UnitKind.Id.KING and UnitKind.role(other.kind) != UnitKind.Role.HEALER:
			return true
	return false


## 奇襲が、敵の本陣へ乗りに行くか。もう乗っているか、本陣が空いていて、RAID_STEPS 歩以内で、
## いまそこに立っても倒されない（危険の見積もりが HP より小さい）とき。_build_threats のあとに呼ぶ。
func _can_raid_hq(unit: Unit) -> bool:
	if _foe_hq == Board.NO_CELL:
		return false
	if unit.cell == _foe_hq:
		return true
	if _battle.unit_at(_foe_hq) != null:
		return false
	if _steps_from(_foe_hq)[unit.cell.y * _board.size.x + unit.cell.x] > RAID_STEPS:
		return false
	return _threat_at(unit, _foe_hq, 0) < unit.hp


## 奇襲が狙う敵。やわらかい駒（後衛・回復）を先に、次に奇襲、最後に前衛と将。同じなら、歩数の近いもの。
func _prey(unit: Unit) -> Unit:
	var from := _steps_from(unit.cell)
	var width := _board.size.x
	var best: Unit = null
	var best_key := Vector2i(_FAR, _FAR)
	for other in _battle.units:
		if other.side != _foe:
			continue
		var rank := 2
		match UnitKind.role(other.kind):
			UnitKind.Role.REARGUARD, UnitKind.Role.HEALER:
				rank = 0
			UnitKind.Role.RAIDER:
				rank = 1
		# 駒のいるマスは歩数の表で通れるので、そのマスまでの歩数で測る。
		var key := Vector2i(rank, from[other.cell.y * width + other.cell.x])
		if key < best_key:
			best = other
			best_key = key
	return best


## 前衛・後衛（と、戦える駒のいなくなった軍の将）が向かう敵（プレイヤーの駒）。侵入者を先に、その中でいちばん近いもの（マンハッタン距離）。
func _enemy_to_chase(unit: Unit) -> Unit:
	var best: Unit = null
	var best_key := Vector2i(_FAR, _FAR)
	for other in _battle.units:
		if other.side != _foe:
			continue
		var intruder := _my_hq != Board.NO_CELL and Combat.distance(other.cell, _my_hq) <= DEFENSE_RADIUS
		var key := Vector2i(0 if intruder else 1, Combat.distance(unit.cell, other.cell) - _poacher_pull(unit, other))
		if key < best_key:
			best = other
			best_key = key
	return best


## 相手が狩っている中ボスのそばの相手の駒（狩りの最中）は、DENY_PULL マスぶん近いものとして追う（取らせない）。
func _poacher_pull(unit: Unit, foe: Unit) -> int:
	_build_hunts()
	for boss_id in _rival_hunts:
		var boss := _battle.unit_by_id(boss_id)
		if Combat.distance(foe.cell, boss.cell) <= HUNT_RIVAL_RADIUS and Combat.distance(unit.cell, boss.cell) <= DENY_RADIUS:
			return DENY_PULL
	return 0


## 回復役がついて行く味方。
func _friend_to_follow(unit: Unit) -> Unit:
	var from := _steps_from(unit.cell)
	var width := _board.size.x
	var wounded: Unit = null
	var wounded_rate := 1.0
	var nearest: Unit = null
	var nearest_steps := _FAR
	var king: Unit = null
	for other in _battle.units:
		if other.side != _me or other == unit:
			continue
		var steps := from[other.cell.y * width + other.cell.x]
		var rate := float(other.hp) / other.max_hp()
		if rate < wounded_rate and steps <= HEALER_SEARCH_STEPS:
			wounded = other
			wounded_rate = rate
		if other.kind == UnitKind.Id.KING:
			king = other
		elif UnitKind.role(other.kind) != UnitKind.Role.HEALER and steps < nearest_steps:
			nearest = other
			nearest_steps = steps
	if wounded != null:
		return wounded
	return nearest if nearest != null else king


# ---- 危険なマス ----


## unit が cell に立っているときに、次の相手の番（と中立のフェーズ）に受けうるダメージの合計。
## ignored_id の敵は数えない。_build_threats のあとに呼ぶ。
## - 自分の煙幕の中のマスでは、煙幕に防がれない攻撃だけを数える
## - unit にバリアが付いていれば、いちばん弱い 1 回ぶんを引く（相手は、弱い攻撃で先にはがす）
func _threat_at(unit: Unit, cell: Vector2i, ignored_id: int) -> int:
	return _danger_in(_threats, _close_threats, unit, cell, ignored_id)


## _threat_at の中身。危険の表（threats、close）を受け取る（盾を置いたあとの盤面で数え直した表でも読めるように）。
func _danger_in(
	threats: Dictionary[Vector2i, Dictionary], close: Dictionary[Vector2i, Dictionary],
	unit: Unit, cell: Vector2i, ignored_id: int
) -> int:
	var by: Dictionary = (close if _smoked.has(cell) else threats).get(cell, {})
	var total := 0
	var weakest := _FAR
	for enemy_id: int in by:
		if enemy_id != ignored_id:
			total += by[enemy_id]
			weakest = mini(weakest, by[enemy_id])
	if total > 0 and Statuses.blocking(unit) != -1:
		total -= weakest
	return total


## 次の相手の番（と中立のフェーズ）に、敵が攻撃できるマスを調べる（_threats、_close_threats）。
## 敵の脅威範囲（Threat.against。docs/threat-range.md）をそのまま使う。
func _build_threats() -> void:
	if _threats_ready:
		return
	_threats_ready = true
	for effect in _board.field_effects:
		if effect.type == FieldEffect.Type.SMOKE and effect.side == _me:
			for cell in effect.cells:
				_smoked[cell] = true
	_fill_threats(_battle, _threats, _close_threats, _foe_stops)


## state（いまの対戦か、その複製に手を進めたもの。自分の番）から、次の相手の番の危険の表を作って、threats と close に書く。
## stops には、敵の駒（回復役を除く）が止まれるマスを書く。state は変えない。
func _fill_threats(
	state: Battle, threats: Dictionary[Vector2i, Dictionary], close: Dictionary[Vector2i, Dictionary],
	stops: Dictionary[Vector2i, bool]
) -> void:
	var map := Threat.against(state, _me)
	threats.merge(map.hits)
	close.merge(map.close)
	stops.merge(map.stops)


# ---- 歩数の表 ----


## goal から各マスへの歩数（上下左右に 1 歩ずつ。ポータルの転移も 1 歩。駒の乗っているポータルは通れない）。ほかは駒を無視する。
## 遠くの目標へ「どちらが近いか」を比べるための目安で、移動のルール（Movement）の代わりではない。
func _steps_from(goal: Vector2i) -> PackedInt32Array:
	if _steps.has(goal):
		return _steps[goal]
	if _steps.size() >= 128:
		_steps = {}
	var width := _board.size.x
	var height := _board.size.y
	var steps := PackedInt32Array()
	steps.resize(width * height)
	steps.fill(_FAR)
	var queue := PackedInt32Array()
	queue.resize(width * height)
	var head := 0
	var tail := 1
	queue[0] = goal.y * width + goal.x
	steps[queue[0]] = 0
	var portals := not _board.portal_exits.is_empty()
	while head < tail:
		var index := queue[head]
		head += 1
		var next_steps := steps[index] + 1
		var x := index % width
		@warning_ignore("integer_division")
		var y := index / width
		var near: Array[int] = []
		if x > 0:
			near.append(index - 1)
		if x < width - 1:
			near.append(index + 1)
		if y > 0:
			near.append(index - width)
		if y < height - 1:
			near.append(index + width)
		if portals:
			var exit := _board.portal_exit(Vector2i(x, y))
			if exit != Board.NO_CELL and not _blocked_portals.has(exit) and not _blocked_portals.has(Vector2i(x, y)):
				near.append(exit.y * width + exit.x)
		for other in near:
			if _walkable[other] == 1 and steps[other] == _FAR:
				steps[other] = next_steps
				queue[tail] = other
				tail += 1
	_steps[goal] = steps
	return steps
