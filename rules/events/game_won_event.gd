class_name GameWonEvent
extends BattleEvent
## 決着した。winner が勝った陣営。

enum Reason {
	KING_DEFEATED,  ## 敵の将を倒した
	HQ_CAPTURED,  ## 敵の本陣を占拠し続けた
	TURNS_HELD,  ## 決められたターンが終わるまで、守り切った
	ROUTED,  ## 敵の駒を（将も含めて）全部倒した
	BOSS_SLAIN,  ## 中ボスを倒した（どちらの中ボスでもよい）
	STRONGHOLD_HELD,  ## 拠点を確保し続けた（試しの決まりの拠点）
}

var winner: Unit.Side
var reason: Reason


func _init(winning_side: Unit.Side, why: Reason) -> void:
	winner = winning_side
	reason = why
