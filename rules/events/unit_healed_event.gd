@abstract
class_name UnitHealedEvent
extends BattleEvent
## 駒が回復を受けた。amount は実際に増えた HP、hp は受けたあとの HP。
##
## 実際に出るのは、原因ごとの子のクラス。原因に固有の値（回復した駒など）は、子のクラスだけが持つ。
## HP の変化だけを追うなら、このクラスとして読めば足りる（`event as UnitHealedEvent`）。
##
## - HealerHealedEvent: 回復役の回復（healer_id）
## - SpringHealedEvent: 回復の泉（cell）
## - RegenerationHealedEvent: 進化先の特性の再生（固有の値は無い）
## - SanctuaryHealedEvent: 聖域（effect_id）

enum Cause {
	HEAL,  ## 回復役の回復
	SPRING,  ## 回復の泉
	REGENERATION,  ## 進化先の特性の再生
	SANCTUARY,  ## 聖域
}

var unit_id: int
var amount: int
var hp: int
var cause: Cause
