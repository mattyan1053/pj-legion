class_name Card
extends RefCounted
## 手札の札の種類と、種類ごとの決まり（docs/hand-cards.md）。試しの決まり（OptionalRules.HAND）。
##
## 札は 1 回きりの効果。どの札が誰の手にあるかは対戦が持つ（Battle.hands）。配る・引く・使うのは Hand。
## ここは種類ごとの定義だけで、状態を持たない。名前と説明の文は game/text/names.csv（鍵は key の名前。game/names.gd）。

enum Id {
	MARCH,  ## 進軍。味方 1 体の移動力を、この番のあいだ上げる（Status.Type.HASTE）
	MIGHT,  ## 強打。味方 1 体の攻撃力を、この番のあいだ上げる（Status.Type.MIGHT）
	MEND,  ## 手当て。味方 1 体の HP を戻す
	SHOVE,  ## 押し出し。味方と隣り合う敵 1 体を、隣の空いたマスへ 1 マス動かす
	ENCORE,  ## 号令。行動済みの味方 1 体を、行動前に戻す（反動が付く。アドレナリン注射と同じ）。連邦だけ
	RESUPPLY,  ## 補給。味方の全員の HP を少し戻す。連邦だけ
	WARD,  ## 加護。味方 1 体にバリアを付ける。騎士領だけ
	BLINK,  ## 転移。味方 1 体を、近くの空いたマスへ移す。騎士領だけ
}

## 札の相手の選び方。
enum Aim {
	NONE,  ## 相手を選ばない（使うと、すぐ効く）
	UNIT,  ## 駒 1 体を選ぶ
	UNIT_THEN_CELL,  ## 駒 1 体を選び、続けて、その駒を動かす先のマスを選ぶ
}

# ---- 調整値 ----

## 進軍で上がる移動力と、強打で上がる攻撃力（回復役は回復量）。どちらも、次の自分の番の始めに外れる。
const MARCH_MOVE := 2
const MIGHT_POWER := 3
const BOOST_TURNS := 1
## 手当てで戻る HP と、補給で全員に戻る HP。
const MEND_HEAL := 8
const RESUPPLY_HEAL := 3
## 転移で移せる歩数。
const BLINK_RANGE := 3

## 軍ごとの札の山（種類 -> 枚数）。合わせて PILE_SIZE 枚。
const PILES: Dictionary = {
	UnitKind.Army.MILITARY: {
		Id.MARCH: 4, Id.MIGHT: 4, Id.MEND: 3, Id.SHOVE: 3, Id.ENCORE: 3, Id.RESUPPLY: 3,
	},
	UnitKind.Army.FANTASY: {
		Id.MARCH: 3, Id.MIGHT: 4, Id.MEND: 3, Id.SHOVE: 3, Id.WARD: 4, Id.BLINK: 3,
	},
}
const PILE_SIZE := 20


## 文の表の鍵（Id の名前の小文字）。
static func key(id: Id) -> StringName:
	return StringName(String(Id.find_key(id)).to_lower())


static func from_key(name: StringName) -> int:
	return Id.get(String(name).to_upper(), -1)


static func aim(id: Id) -> Aim:
	if id == Id.RESUPPLY:
		return Aim.NONE
	if id == Id.SHOVE or id == Id.BLINK:
		return Aim.UNIT_THEN_CELL
	return Aim.UNIT


## 相手の駒を選ぶ札か（味方ではなく）。
static func aims_at_foe(id: Id) -> bool:
	return id == Id.SHOVE


## 説明の文に差し込む値。
static func summary_args(id: Id) -> Dictionary:
	match id:
		Id.MARCH:
			return {"move": MARCH_MOVE}
		Id.MIGHT:
			return {"power": MIGHT_POWER}
		Id.MEND:
			return {"heal": MEND_HEAL}
		Id.RESUPPLY:
			return {"heal": RESUPPLY_HEAL}
		Id.ENCORE:
			return {"penalty": AdrenalineShotSkill.POWER_PENALTY}
		Id.BLINK:
			return {"range": BLINK_RANGE}
	return {}


## army の札の山の中身（種類の番号の順に、枚数ぶん並べたもの。混ぜる前）。山を持たない軍では空。
static func pile_of(army: UnitKind.Army) -> Array[int]:
	var pile: Array[int] = []
	var counts: Dictionary = PILES.get(army, {})
	for id: int in Id.values():
		for i: int in int(counts.get(id, 0)):
			pile.append(id)
	return pile
