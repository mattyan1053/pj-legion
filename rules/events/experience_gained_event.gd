class_name ExperienceGainedEvent
extends BattleEvent
## 駒が経験値を得た。amount は入った量、experience は足したあとにためている量（レベルアップの前。
## EXPERIENCE_PER_LEVEL 以上なら、このすぐあとに LevelUpEvent が続く）。

enum Reason {
	HIT,  ## 攻撃が当たり、相手が生き残った
	DEFEAT,  ## 攻撃で倒した（プレイヤーの駒も中立の駒も）
	HEAL,  ## 味方を回復した
}

var unit_id: int
var amount: int
var reason: Reason
var experience: int


func _init(gained_unit_id: int, gained: int, why: Reason, experience_after: int) -> void:
	unit_id = gained_unit_id
	amount = gained
	reason = why
	experience = experience_after
