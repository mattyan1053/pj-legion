extends RefCounted
## フェーズの始めにカメラが寄る駒を決める。ノードに依存しない（テストから呼べる）。
##
## - 寄るのは、その陣営が**前回のフェーズで最後に行動を確定した駒**（UnitActedEvent。待機・攻撃・回復・スキル・動いたままのターン終了）。
## - その駒が倒れていたら、または対戦の始めでまだ誰も動いていなければ、その陣営の生きている駒のうち、
##   味方の真ん中（生きている駒の位置の平均）にいちばん近い駒。将かどうかには依らない。
## - 生きている駒がいなければ null（カメラは動かさない）。
##
## 対戦の画面（battle_screen.gd）は、行動のたびに起きたことを feed で食わせ、新しい対戦で clear する。

## 陣営 -> 最後に行動を確定した駒の番号。
var _last := {}


func clear() -> void:
	_last.clear()


## 行動で起きたこと（events）を食わせる。駒の陣営は battle（行動を適用したあとの状態）で引く。
func feed(battle: Battle, events: Array[BattleEvent]) -> void:
	for event in events:
		if event is UnitActedEvent:
			var unit := battle.unit_by_id(event.unit_id)
			if unit != null and (unit.side == Unit.Side.PLAYER1 or unit.side == Unit.Side.PLAYER2):
				_last[unit.side] = unit.id


## side のフェーズの始めに寄る駒（いなければ null）。
func unit_for(battle: Battle, side: Unit.Side) -> Unit:
	if _last.has(side):
		var last := battle.unit_by_id(_last[side])
		if last != null and last.hp > 0 and last.side == side:
			return last
	var own: Array[Unit] = []
	var center := Vector2.ZERO
	for unit in battle.units:
		if unit.side == side and unit.hp > 0:
			own.append(unit)
			center += Vector2(unit.cell)
	if own.is_empty():
		return null
	center /= own.size()
	var best: Unit = own[0]
	for unit in own:
		if Vector2(unit.cell).distance_squared_to(center) < Vector2(best.cell).distance_squared_to(center):
			best = unit
	return best
