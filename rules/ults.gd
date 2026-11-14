class_name Ults
extends RefCounted
## 必殺技の共通の決まり（docs/tactical-ult.md）。ゲージをためる、誰が・いつ使えるか、使ったときの流れ。
##
## 必殺技ごとの中身は Ult の子のクラス（rules/ults/）。ここの問い合わせは状態を変えない。
## 状態を変えるのは use（UseUltAction が呼ぶ）と、ゲージをためる charge_*（ダメージ、撃破、フェーズの始めの処理が呼ぶ）。
##
## - 必殺技は軍で決まる（of_army）。どのプレイヤーがどの軍かは対戦が持つ（Battle.armies）
## - プレイヤーごとにゲージを持つ（Battle.ult_gauge。0 から GAUGE_MAX まで）。中立は持たない
## - ゲージがいっぱいのプレイヤーが、自分のフェーズに使える。使うとゲージは 0 に戻る
## - 使っても、駒の行動は使わない（駒は、そのあとも普通に行動できる）

# ---- 調整値 ----

## ゲージのいっぱいの値。画面には 100% として出す（percent）。
const GAUGE_MAX := 1000
## 自分のフェーズの始めにたまる量。
const PHASE_GAIN := 25
## 自分の駒が敵（相手の駒、中立の駒）に与えたダメージ 1 につき、たまる量。
const DEALT_GAIN := 1
## 自分の駒が敵（相手の駒、中立の駒）から受けたダメージ 1 につき、たまる量。与えたときより多い（押されている側が早くたまる）。
const TAKEN_GAIN := 5
## 自分の駒（将を除く）が倒れたときにたまる量。
const DEFEAT_GAIN := 80

## すべての必殺技。足すときは、ここに 1 つ並べる。
static var ALL: Array[Ult] = [
	AllOutAssaultUlt.new(),
	ManaEruptionUlt.new(),
]


## その軍の必殺技。持たない軍（NONE）なら null。
static func of_army(army: UnitKind.Army) -> Ult:
	for ult in ALL:
		if ult.army() == army:
			return ult
	return null


static func by_id(id: Ult.Id) -> Ult:
	for ult in ALL:
		if ult.id() == id:
			return ult
	return null


## side のプレイヤーの必殺技。中立と、軍の決まっていないプレイヤーでは null。
static func of(battle: Battle, side: Unit.Side) -> Ult:
	if side != Unit.Side.PLAYER1 and side != Unit.Side.PLAYER2:
		return null
	return of_army(battle.armies[side])


## side のゲージ（0 から GAUGE_MAX）。中立は 0。
static func gauge(battle: Battle, side: Unit.Side) -> int:
	return battle.ult_gauge[side] if side < battle.ult_gauge.size() else 0


## side のゲージを、100 をいっぱいとした値で（画面用。端数は切り捨て）。
static func percent(battle: Battle, side: Unit.Side) -> int:
	@warning_ignore("integer_division")
	return gauge(battle, side) * 100 / GAUGE_MAX


## side のゲージがいっぱいで、必殺技を持っているか（自分の番かどうかは見ない）。
static func is_ready(battle: Battle, side: Unit.Side) -> bool:
	return of(battle, side) != null and gauge(battle, side) >= GAUGE_MAX


## いまのフェーズのプレイヤーが、いま必殺技を使えるか（UseUltAction が受け付けるか）。
static func can_use(battle: Battle) -> bool:
	return not battle.is_over() and is_ready(battle, battle.phase)


## いまのフェーズのプレイヤーが必殺技を使う（使えるかどうかは呼ぶ側が確かめる）。起きたことを返す。
## UltUsedEvent、必殺技の効果のイベントの順。ゲージは 0 に戻る。
static func use(battle: Battle) -> Array[BattleEvent]:
	var side := battle.phase
	var ult := of(battle, side)
	battle.ult_gauge[side] = 0
	battle.ult_uses[side] += 1
	var events: Array[BattleEvent] = [UltUsedEvent.new(side, ult.id())]
	events.append_array(ult.apply(battle, side))
	return events


## いまのフェーズのプレイヤーが必殺技を使ったら起きること（予測）。状態は変えない。使えなければ空。
static func preview(battle: Battle) -> Array[BattleEvent]:
	return battle.clone().apply(UseUltAction.new()).events


# ---- ためる ----


## side のゲージに amount を足す（GAUGE_MAX を超えない）。中立と、必殺技を持たないプレイヤーには何もしない。
static func charge(battle: Battle, side: Unit.Side, amount: int) -> void:
	if of(battle, side) == null:
		return
	battle.ult_gauge[side] = clampi(battle.ult_gauge[side] + amount, 0, GAUGE_MAX)


## side のフェーズの始め（EndPhaseAction が呼ぶ）。
static func charge_phase(battle: Battle, side: Unit.Side) -> void:
	charge(battle, side, PHASE_GAIN)


## 適用したダメージ（Hit）のぶんをためる。駒の攻撃（Combat.strike）とスキルのダメージ（Skills.deal_damage）が呼ぶ。
## 数えるのは実際に減った HP（Hit.lost）。防がれたダメージと、残りの HP を超えたぶんは数えない。
## 与えた駒のいないダメージ（起爆樽の爆発）と、味方へのダメージは数えない。
static func charge_hit(battle: Battle, hit: Hit) -> void:
	if hit.source == null or hit.lost <= 0 or not hit.source.is_enemy_of(hit.target):
		return
	charge(battle, hit.source.side, hit.lost * DEALT_GAIN)
	charge(battle, hit.target.side, hit.lost * TAKEN_GAIN)


## 駒が倒れた（Battle.remove_unit が呼ぶ）。原因は問わない。将は数えない（倒れたら決着する）。
static func charge_defeat(battle: Battle, unit: Unit) -> void:
	if unit.kind != UnitKind.Id.KING:
		charge(battle, unit.side, DEFEAT_GAIN)
