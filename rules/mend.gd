class_name Mend
extends RefCounted
## 駒の HP を戻す 1 本の道（docs/battle.md の「回復を 1 つ足すとき」）。
##
## 駒の HP を増やすものは、原因が何でも（回復役、回復の泉、再生、聖域、補給線）、ここを通す。ダメージの Hit と対になる。
## 1. 戻す量を決める（amount。最大 HP の実効値で止める。状態を変えない）
## 2. HP を増やし、原因ごとの出来事（UnitHealedEvent の子）に、回復した駒・増えた量・あとの HP を書き込む（give）
## 誰が回復したか（回復役・衛生兵・聖域）は、出来事の子のクラスが持つ（作るときに渡す）。
## 「回復量を増やす・封じる」効果は、amount に段として足す（いまは無い）。


## unit が limit まで回復するとき、実際に増える HP。最大 HP を超えるぶんは切り捨てる。0 より小さくはならない。
static func amount(unit: Unit, limit: int) -> int:
	return clampi(unit.max_hp() - unit.hp, 0, limit)


## unit を limit まで回復し、event（原因ごとの子。回復した駒など原因の値だけ入れて作る）に結果を書き込んで返す。
## 増えた量が 0 でも出来事は返す（出すかどうかは呼ぶ側が決める）。
static func give(unit: Unit, limit: int, event: UnitHealedEvent) -> UnitHealedEvent:
	var healed := amount(unit, limit)
	unit.hp += healed
	event.unit_id = unit.id
	event.amount = healed
	event.hp = unit.hp
	return event
