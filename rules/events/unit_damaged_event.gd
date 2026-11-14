@abstract
class_name UnitDamagedEvent
extends BattleEvent
## 駒がダメージを受けた。amount は減った HP、hp は受けたあとの HP。
##
## 実際に出るのは、原因ごとの子のクラス。原因に固有の値（攻撃した駒など）は、子のクラスだけが持つ。
## HP の変化だけを追うなら、このクラスとして読めば足りる（`event as UnitDamagedEvent`）。
##
## - AttackDamagedEvent: 駒の攻撃（attacker_id）
## - ExplosionDamagedEvent: 起爆樽の爆発（barrel_cell）

enum Cause {
	ATTACK,  ## 駒の攻撃
	EXPLOSION,  ## 起爆樽の爆発
}

var unit_id: int
var amount: int
var hp: int
var cause: Cause
