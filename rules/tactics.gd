class_name Tactics
extends RefCounted
## 作戦（試しの決まり TrialRules.TACTICS。docs/tactics.md）。対戦の前に選んだ札を、対戦中に 1 回ずつ使う。
##
## - 札は、プレイヤーごとの手札（Battle.tactics）。使った札は Battle.tactics_used に控える
## - 使うのは駒の行動ではなく、プレイヤーの行動（UseTacticAction）。対象は選ばない。駒の行動を使わない
## - 手札が空の対戦（試しの決まりが切）では、何も起きない
##
## ここの問い合わせは状態を変えない。状態を変えるのは use（UseTacticAction が呼ぶ）だけ。

enum Id {
	MARCH,  ## 強行軍。軍の全員の移動力が、このフェーズの間だけ上がる
	SUPPLY,  ## 補給。軍の全員が回復する
	RALLY,  ## 号令。必殺技のゲージがたまる
	WARD,  ## 加護。将にバリアが付く
}

# ---- 調整値 ----

## 手札の枚数。
const HAND_SIZE := 2
## 強行軍で上がる移動力と、強行軍の残りのターン数（1 なら、次の自分の番の始めに外れる）。
const MARCH_MOVE := 2
const MARCH_TURNS := 1
## 補給で回復する HP。
const SUPPLY_HEAL := 8
## 号令でたまる必殺技のゲージ（Ults.GAUGE_MAX を 100% として 25%）。
const RALLY_GAIN := 250
## 加護のバリアの残りのターン数。
const WARD_TURNS := 2

## すべての札（画面の並び）。
const ALL: Array[Id] = [Id.MARCH, Id.SUPPLY, Id.RALLY, Id.WARD]
## 選ばなかったプレイヤー（CPU の既定）の手札。
const DEFAULT_HAND: Array[Id] = [Id.MARCH, Id.SUPPLY]


## ids を、手札にできる形に直す（知っている札だけ、重ねず、HAND_SIZE 枚まで。足りなければ DEFAULT_HAND から足す）。
static func hand_from(ids: Array) -> Array[Id]:
	var wanted: Array = ids.duplicate()
	wanted.append_array(DEFAULT_HAND)
	wanted.append_array(ALL)
	var picked: Array[Id] = []
	for id: Variant in wanted:
		if picked.size() < HAND_SIZE and typeof(id) == TYPE_INT and ALL.has(id) and not picked.has(id):
			picked.append(id as Id)
	return picked


## 種 hand_seed で決まる手札（集計の道具が、札ごとの勝ち負けを見るのに使う）。
static func random_hand(hand_seed: int) -> Array[Id]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hand_seed
	var pool := ALL.duplicate()
	var picked: Array[Id] = []
	while picked.size() < HAND_SIZE:
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	picked.sort()
	return picked


## side の手札（選んだ順）。中立と、作戦の無い対戦では空。
static func hand(battle: Battle, side: Unit.Side) -> Array:
	return battle.tactics[side] if side < battle.tactics.size() else []


## side が、手札の id をまだ使っていないか。
static func is_unused(battle: Battle, side: Unit.Side, id: Id) -> bool:
	return hand(battle, side).has(id) and not battle.tactics_used[side].has(id)


## いまのフェーズのプレイヤーが、いま id を使えるか（UseTacticAction が受け付けるか）。
static func can_use(battle: Battle, id: Id) -> bool:
	return not battle.is_over() and is_unused(battle, battle.phase, id)


## いまのフェーズのプレイヤーが id を使う（使えるかどうかは呼ぶ側が確かめる）。起きたことを返す。
## TacticUsedEvent、効果のイベントの順。
static func use(battle: Battle, id: Id) -> Array[BattleEvent]:
	var side := battle.phase
	battle.tactics_used[side].append(id)
	var events: Array[BattleEvent] = [TacticUsedEvent.new(side, id)]
	match id:
		Id.MARCH:
			for unit in battle.units:
				if unit.side == side:
					events.append(Statuses.add(unit, Status.Type.MARCH, MARCH_TURNS))
		Id.SUPPLY:
			for unit in battle.units:
				var amount := supply_heal(unit) if unit.side == side else 0
				if amount > 0:
					unit.hp += amount
					events.append(TacticHealedEvent.new(unit.id, amount, unit.hp))
		Id.RALLY:
			Ults.charge(battle, side, RALLY_GAIN)  # いっぱいになったことは、Battle.apply が UltReadyEvent で知らせる
		Id.WARD:
			for unit in battle.units:
				if unit.side == side and unit.kind == UnitKind.Id.KING:
					events.append(Statuses.add(unit, Status.Type.BARRIER, WARD_TURNS))
	return events


## 補給で unit が実際に回復する HP。
static func supply_heal(unit: Unit) -> int:
	return clampi(unit.max_hp() - unit.hp, 0, SUPPLY_HEAL)


## 説明の文（game/text/names.csv の tactic.<id>.summary）に差し込む値。
static func summary_args() -> Dictionary:
	@warning_ignore("integer_division")
	return {"move": MARCH_MOVE, "heal": SUPPLY_HEAL, "gauge": RALLY_GAIN * 100 / Ults.GAUGE_MAX, "turns": WARD_TURNS}
