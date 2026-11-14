class_name Hit
extends RefCounted
## 駒が受けるダメージ 1 回ぶんの解決（docs/combat.md の「ダメージの解決」）。
##
## 駒の HP を減らすものは、原因が何でも（駒の攻撃、起爆樽の爆発、スキルのダメージ）、ここを通す。
## 「計算」（resolve。状態を変えない）と「適用」（apply）に分かれていて、予測と CPU は計算だけを使うか、
## 複製（Battle.clone()）の上で適用まで走らせる。どちらでも、実際と同じ結果になる。
##
## 解決に割り込むもの（駒の状態など）は、ここに段として足す。いまある段は、
##   1. 受ける側の状態: ダメージを 0 にする状態（バリア）があれば 0 にし、その状態は適用で外れる
## 攻撃する側の割り込み（確定クリティカル）は、駒の攻撃だけのものなので Combat.hit が、ここへ渡す前の量に掛ける。
## 後で足すもの（隣の味方の身代わり、ノックバック）の置き場所は docs/combat.md に書いてある。

## 与えた駒（駒の攻撃なら攻撃した駒、スキルなら使った駒）。起爆樽の爆発では null。
var source: Unit
## 実際に受ける駒。
var target: Unit
var cause: UnitDamagedEvent.Cause
## 実際に減らす量（残りの HP より多くてもそのまま）。防がれたら 0。
var amount := 0
## 確定クリティカルの攻撃か。
var critical := false
## ダメージを 0 にした、受ける側の状態（Status.Type）。無ければ -1。
var blocked_by := -1
## 駒の攻撃を阻んだ煙幕（ダメージは 0。受ける側の状態までは届かないので、バリアは残る）。無ければ null。
var smoke: FieldEffect
## 適用したあとの、受けた駒の HP（apply が入れる）。
var hp_after := 0
## 適用で実際に減った HP（apply が入れる。amount が残りの HP より多ければ、残りの HP まで）。必殺技のゲージが数える。
var lost := 0


## source が target に、割り込む前の量 base_amount のダメージを与えたらどうなるか。状態は変えない。
static func resolve(source_unit: Unit, target_unit: Unit, base_amount: int, why: UnitDamagedEvent.Cause) -> Hit:
	var hit := Hit.new()
	hit.source = source_unit
	hit.target = target_unit
	hit.cause = why
	hit.amount = base_amount
	hit.hp_after = maxi(0, target_unit.hp - base_amount)
	hit.blocked_by = Statuses.blocking(target_unit)
	if hit.blocked_by != -1:
		hit.amount = 0
		hit.hp_after = target_unit.hp
	return hit


## 煙幕に阻まれた駒の攻撃。ダメージは 0 で、受ける側には何も起きない。
static func smoked(source_unit: Unit, target_unit: Unit, by: FieldEffect) -> Hit:
	var hit := Hit.new()
	hit.source = source_unit
	hit.target = target_unit
	hit.cause = UnitDamagedEvent.Cause.ATTACK
	hit.smoke = by
	hit.hp_after = target_unit.hp
	return hit


## 計算した結果を駒に適用する: HP を減らし、ダメージを防いだ状態を外す。
## 返すのは、ダメージのイベントのあとに続けるイベント（状態が外れた）。ダメージのイベントは、原因ごとに呼ぶ側が作る
## （この Hit を渡して作る。UnitDamagedEvent）。倒れた駒を取り除くのも呼ぶ側（同時に当たるダメージは、全員ぶんのあとで取り除く）。
func apply() -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if smoke != null:
		return events
	lost = mini(amount, target.hp)
	target.hp -= lost
	hp_after = target.hp
	if blocked_by != -1:
		events.append(Statuses.remove(target, blocked_by as Status.Type, StatusRemovedEvent.Reason.CONSUMED))
	return events
