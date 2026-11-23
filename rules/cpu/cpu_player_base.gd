extends RefCounted
## CPU の思考（rules/cpu_player.gd。docs/cpu-ai.md）の土台: 調整値と、覚えておくもの・1 回の判断の間だけ使うもの、歩数の表。
## 評価の種類ごとのファイル（cpu_*_value.gd など）は、これを継いで順に積み重なる（cpu_player.gd が最後）。
## 小さな道具（いちばん近い敵までの距離、もやを除いた射程）もここに置く。


# ---- 調整値（docs/cpu-ai.md の「調整値」） ----


## 駒を動かす順（役割）。後衛 → 前衛 → 奇襲 → 回復 → 将。
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
## 1.0 より小さい: 互角なら狩る（相手より少し弱くても、止めを取り合える）。はっきり負けているときは狩らない。
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
## 相手が狩っている中ボスの HP が、最大 HP のこの割合（%）まで減ったら、DENY_RADIUS マス以内の後衛と奇襲は、止めを横取りしに向かう。
const STEAL_HP_PERCENT := 50
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
## 砲台に立つ価値と、砲台から 1 歩離れるごとに引く量、引かれる歩数、砲台の射程の先に相手を数える広さ。
const BATTERY_VALUE := 25.0
const BATTERY_STEP_COST := 1.5
const BATTERY_STEPS := 16
const BATTERY_WATCH := 6
## 回復役が、減っている味方を探す範囲（歩数）。
## 拠点（docs/map-objects.md の「拠点」。docs/cpu-ai.md の「拠点」）。
## 戦う駒が拠点に立って行動を終える価値と、もう乗っている駒が居座る価値（確保 1 つあたり）。
const STRONGHOLD_VALUE := 60.0
const STRONGHOLD_HOLD_VALUE := 100.0
## 拠点に乗っている相手の駒。ダメージの価値を STRONGHOLD_RATE 倍にし、倒す価値に（相手の確保 1 つあたり）STRONGHOLD_KILL_BONUS を足す。
const STRONGHOLD_RATE := 1.5
const STRONGHOLD_KILL_BONUS := 40.0
## 相手の駒が拠点に乗っている間、拠点の周り（確保を止められる所。Stronghold.CONTEST_RADIUS 以内）に立って行動を終える価値。
const STRONGHOLD_BLOCK_VALUE := 60.0
const HEALER_SEARCH_STEPS := 12
## 組み方（docs/formation.md。docs/cpu-ai.md の「組み方」）。入の対戦だけ効く（切なら、どれも 0）。
## 分隊の駒が、同じ分隊の仲間の隣（肩並べ）に立って行動を終える価値（受けうるダメージの見積もりも、肩並べのぶんだけ減らして読む）。
const SQUAD_HUDDLE_VALUE := 2.0
## 分隊の駒が攻撃した相手（倒しきらない）に、このあとに動ける同じ分隊の仲間が届きそうなら、追い撃ちの見込みとして足す価値。
const SQUAD_FOCUS_SETUP_VALUE := 4.0
## 誓いの駒が、誓いの相手から Formation.OATH_RANGE マス以内に立って行動を終える価値（離れると仇討ちが効かない）。
const OATH_NEAR_VALUE := 6.0
## 相手の誓いの駒を倒す価値（誓いを切る。仇討ちが消える）。
const OATH_BREAK_VALUE := 15.0
## 相手の誓いの駒を、倒しきらずに攻撃する減点（誓いの相手が近くにいれば、仇討ちを受ける）。
const OATH_PROVOKE_PENALTY := 6.0


## スキルを使う手の、スキルごとの見積もり（対象に選ぶ価値のありそうなマスと、使った結果の価値）は、
## rules/cpu/ の 1 スキル 1 ファイル（CpuSkillEstimate.of）。


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
const ERUPTION_MIN_UNITS := 1


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
## 勝ちの条件の読み（rules/cpu/win_conditions_cpu.gd）。守る側か、攻める側で急ぐか。
var _holding := false
## 拠点の確保で勝てる（両方とも勝てる）か、拠点へ向かう駒の番号（0 = まだ決めていない、-1 = いない）。_begin が決める。
var _takes_stronghold := false
var _stronghold_taker := 0
var _rushing := false
var _lethal_penalty := 0.0
var _stand_off := false
## いま考えている駒（奇襲）が離れすぎないようにする味方（前衛・後衛）のマス。空なら、見ない。
var _support: Array[Vector2i] = []
## いま考えている駒が、ほかのマスへ動いたあとの射程（動くと外れる状態で伸びた射程は、動くと戻る）。
## 縫い目の様子の天裂の名残りで縮める前の値（砲台の伸びを付け替えてから縮める。_reach_from）。
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
## 決めた移動の続き（ポータルを通る移動は、移動・転移・移動の行動の列になる。Movement.route）。
## 1 手ずつ返す。[駒の番号, 次の行動の前にいるはずのマス, 行動] の列。ずれたら（受け付けられない、駒が違う）捨てる。
var _route: Array[Array] = []


## いちばん近い敵の駒（中立を除く）までの距離（マンハッタン距離。地形は見ない目安）。いなければ _FAR。
func _nearest_foe_distance(unit: Unit) -> int:
	var nearest := _FAR
	for other in _battle.units:
		if other.side == _foe:
			nearest = mini(nearest, Combat.distance(unit.cell, other.cell))
	return nearest


## unit の射程を measure で測る。天裂の名残り（Seam）で縮める前の値（縮み方は射程に比例しないので、砲台の伸びを付け替えてから縮める）。
static func _unhazed(unit: Unit, measure: Callable) -> int:
	var hazed := unit.hazed
	unit.hazed = false
	var value: int = measure.call()
	unit.hazed = hazed
	return value


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
