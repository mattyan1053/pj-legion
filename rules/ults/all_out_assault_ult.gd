class_name AllOutAssaultUlt
extends Ult
## 総員突撃（MILITARY）。軍の全員の移動力と攻撃力を、このフェーズの間だけ上げる。docs/tactical-ult.md。
##
## - 軍の駒すべて（将と回復役も含む）に、突撃（Status.Type.ASSAULT）が付く。回復役は回復量が上がる
## - 突撃は、次の自分の番の始めに外れる（相手の番の間も付いているが、攻撃力と移動力は守りには効かない）
## - もう行動を終えた駒にも付くが、その駒はこのフェーズにはもう動けないので、得をしない

# ---- 調整値 ----

## 突撃の間に上がる移動力と攻撃力（回復役は回復量）。
const MOVE_BONUS := 2
const POWER_BONUS := 5
## 突撃の残りのターン数（付けたときの値）。1 なら、次の自分の番の始めに外れる。
const ASSAULT_TURNS := 1


func id() -> Ult.Id:
	return Ult.Id.ALL_OUT_ASSAULT


func army() -> UnitKind.Army:
	return UnitKind.Army.MILITARY


func display_name() -> String:
	return "総員突撃"


func summary() -> String:
	return "このターンの間、軍の全員の移動力 +%d、攻撃力（回復量）+%d" % [MOVE_BONUS, POWER_BONUS]


func apply(battle: Battle, side: Unit.Side) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for unit in battle.units:
		if unit.side == side:
			events.append(Statuses.add(unit, Status.Type.ASSAULT, ASSAULT_TURNS))
	return events
