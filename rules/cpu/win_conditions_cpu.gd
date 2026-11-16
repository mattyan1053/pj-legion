class_name CpuWinPlan
extends RefCounted
## CPU（cpu_player.gd）が、戦いの勝ちの条件（docs/win-conditions.md）を読んで、目標の決め方を変えるところ。
## 見方は docs/cpu-ai.md の「勝ちの条件」。対戦モード（両方とも将の撃破と本陣の占拠）では、どれも働かない。
##
## - 本陣の占拠で勝てないなら、敵の本陣を目指さない。相手が占拠で勝てないなら、自分の本陣を守りに戻らない
## - 守る側（守り切るで勝てる側）は、前に出すぎない: 自分の本陣の近くに入った敵だけを追い、ほかの駒は本陣のそばで待つ
## - 攻める側は、守り切られるまでの残りのターンが少なければ急ぐ: 危険を気にせず踏み込み、敵の将へ向かう

# ---- 調整値（docs/cpu-ai.md の「調整値」） ----

## 守る側が追う敵: 自分の本陣からこの距離（マンハッタン距離）以内に入った敵。
const HOLD_RADIUS := 10
## 守る側の、追う敵のいない駒が待つところ: 自分の本陣からこの歩数の中。
const HOLD_REACH := 5
## 攻める側が急ぐ: 守り切られるまでの残りのターン（いまのターンを含む）がこれ以下。
const RUSH_TURNS := 4


## side が、本陣の占拠で勝てるか（占拠がもう間に合わないときも偽）。
static func raids_hq(battle: Battle, side: Unit.Side) -> bool:
	if not battle.wins_by(side, GameWonEvent.Reason.HQ_CAPTURED):
		return false
	var left := battle.turns_left()
	if left == -1 or holds(battle, side):
		return true
	return battle.capture_turns[side] + left >= Battle.CAPTURE_TURNS_TO_WIN


## side の相手が、本陣の占拠で勝てるか（side の本陣を守る要があるか）。
static func guards_hq(battle: Battle, side: Unit.Side) -> bool:
	return raids_hq(battle, (1 - side) as Unit.Side)


## side が守る側か（守り切るで勝てる）。
static func holds(battle: Battle, side: Unit.Side) -> bool:
	return battle.turns_left() != -1 and battle.wins_by(side, GameWonEvent.Reason.TURNS_HELD)


## side が攻める側で、残りのターンが少ないか。
static func rushes(battle: Battle, side: Unit.Side) -> bool:
	return holds(battle, (1 - side) as Unit.Side) and battle.turns_left() <= RUSH_TURNS
