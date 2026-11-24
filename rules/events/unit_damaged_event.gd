@abstract
class_name UnitDamagedEvent
extends BattleEvent
## 駒がダメージを受けた。amount は減った HP、hp は受けたあとの HP。
##
## 中身は、解決したダメージ（Hit）から写す。
## 実際に出るのは、原因ごとの子のクラス。原因に固有の値（攻撃した駒など）は、子のクラスだけが持つ。
## HP の変化だけを追うなら、このクラスとして読めば足りる（`event as UnitDamagedEvent`）。
##
## - AttackDamagedEvent: 駒の攻撃（attacker_id）
## - ExplosionDamagedEvent: 起爆樽の爆発（barrel_cell）
## - SkillDamagedEvent: ダメージのあるスキル（user_id、skill）

enum Cause {
	ATTACK,  ## 駒の攻撃
	EXPLOSION,  ## 起爆樽の爆発（倒れた糸喰いが弾けたのも）
	SKILL,  ## ダメージのあるスキル
}

var unit_id: int
var amount: int
var hp: int
var cause: Cause
## 確定クリティカルの攻撃だったか（駒の攻撃だけ。amount は倍率を掛けたあとの量）。
var critical := false
## 森の軽減が掛かったか（駒の攻撃だけ。amount は軽減したあとの量）。
var forest := false
## 糸茸の胞子で弱まったか（駒の攻撃だけ。amount は引いたあとの量）。
var spores := false
## ダメージを 0 にした、受けた駒の状態（Status.Type。バリア）。防がれていなければ -1。
## 防がれたときは amount が 0 で、このあとに、その状態が外れる StatusRemovedEvent が続く。
var blocked_by := -1
## 部隊の特徴（Traits）で増えた・減った量（Traits.Id -> 量。駒の攻撃だけ）。無ければ空。
var traits := {}


## 解決したダメージ（適用したあとの Hit）の中身を写す。子のクラスの _init が呼ぶ。
func _fill(hit: Hit) -> void:
	unit_id = hit.target.id
	amount = hit.amount
	hp = hit.hp_after
	cause = hit.cause
	critical = hit.critical
	forest = hit.forest
	spores = hit.spores
	blocked_by = hit.blocked_by
	traits = hit.traits.duplicate()


## 受けた駒の状態に防がれて、ダメージが 0 になったか。
func is_blocked() -> bool:
	return blocked_by != -1
