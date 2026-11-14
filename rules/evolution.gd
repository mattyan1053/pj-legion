class_name Evolution
extends RefCounted
## 進化（docs/branch-evolution.md）。レベルが上限に届いた駒が、2 つの進化先のどちらかを選んで別の型になる。
##
## - 進化先は、雇う 8 種のそれぞれに 2 つ（A・B）。将と中立の駒は進化しない
## - 進化先は、能力値の増減（層 1 に足す。Unit.base_stat）と、特性（Trait。いまあるルールの例外）を持つ
## - 選ぶのは駒の持ち主。上限に届いたその場で選ぶ（選ぶまで、ほかの行動は受け付けない。Battle.evolving_unit）
## - 選ぶ行動は EvolveAction。選べる進化先は Battle.options(駒).evolutions に載る
##
## 中身はすべてこのファイルの表（_TABLE）と REGENERATION_HEAL にある。

enum Id {
	NONE,  ## 進化していない
	BULWARK,  ## シールドトルーパー A
	JUGGERNAUT,  ## シールドトルーパー B
	MARKSMAN,  ## スナイパー A
	SCOUT,  ## スナイパー B
	ASSAULT,  ## コマンドー A
	INFILTRATOR,  ## コマンドー B
	SURGEON,  ## 衛生兵 A
	COMBAT_MEDIC,  ## 衛生兵 B
	SACRED,  ## パラディン A
	CRUSADER,  ## パラディン B
	ARCHMAGE,  ## ソーサラー A
	ENCHANTER,  ## ソーサラー B
	ARC_BLADE,  ## スペルブレード A
	FEY_WALKER,  ## スペルブレード B
	BISHOP,  ## プリースト A
	SAINT,  ## プリースト B
}

## 特性。どれも、いまあるルールの例外として表す。
enum Trait {
	EXERTS_ZOC,  ## 周り 8 マスに支配領域（ZOC）を作る（前衛でなくても）
	IGNORES_ZOC,  ## 敵の支配領域で止まらない
	FOREST_WALK,  ## 森に、平地と同じ移動力で入る
	REGENERATION,  ## 自分のフェーズの始めに、REGENERATION_HEAL だけ回復する
}

# ---- 調整値（docs/branch-evolution.md の「調整値」） ----

## 再生（Trait.REGENERATION）の駒が、自分のフェーズの始めに回復する量。
const REGENERATION_HEAL := 5

const _HP := Unit.Stat.MAX_HP
const _POWER := Unit.Stat.POWER
const _MOVE := Unit.Stat.MOVE_RANGE
const _RANGE := Unit.Stat.ATTACK_RANGE

## [名前, 元の種類, 能力値の増減（Unit.Stat -> int）, 特性]
## 種類ごとに A、B の順に並べる（options_for の並びになる）。
const _TABLE := {
	Id.BULWARK: ["ブルワーク", UnitKind.Id.SHIELD_TROOPER, {_HP: 18}, []],
	Id.JUGGERNAUT: ["ジャガーノート", UnitKind.Id.SHIELD_TROOPER, {_MOVE: 2, _POWER: 2}, []],
	Id.MARKSMAN: ["マークスマン", UnitKind.Id.SNIPER, {_RANGE: 2, _POWER: 2, _MOVE: -1}, []],
	Id.SCOUT: ["スカウト", UnitKind.Id.SNIPER, {_MOVE: 2, _HP: 8}, []],
	Id.ASSAULT: ["アサルト", UnitKind.Id.COMMANDO, {_POWER: 4, _HP: 6}, []],
	Id.INFILTRATOR: ["インフィルトレーター", UnitKind.Id.COMMANDO, {_MOVE: 1}, [Trait.IGNORES_ZOC]],
	Id.SURGEON: ["サージョン", UnitKind.Id.MEDIC, {_POWER: 8}, []],
	Id.COMBAT_MEDIC: ["コンバットメディック", UnitKind.Id.MEDIC, {_MOVE: 2, _HP: 10}, []],
	Id.SACRED: ["セイクリッド", UnitKind.Id.PALADIN, {_HP: 10}, [Trait.REGENERATION]],
	Id.CRUSADER: ["クルセイダー", UnitKind.Id.PALADIN, {_POWER: 4, _MOVE: 1}, []],
	Id.ARCHMAGE: ["アークメイジ", UnitKind.Id.SORCERER, {_POWER: 4, _RANGE: 1}, []],
	Id.ENCHANTER: ["エンチャンター", UnitKind.Id.SORCERER, {_HP: 8}, [Trait.EXERTS_ZOC]],
	Id.ARC_BLADE: ["アークブレード", UnitKind.Id.SPELLBLADE, {_RANGE: 1, _POWER: 1}, []],
	Id.FEY_WALKER: ["フェイウォーカー", UnitKind.Id.SPELLBLADE, {_MOVE: 2}, [Trait.FOREST_WALK]],
	Id.BISHOP: ["ビショップ", UnitKind.Id.PRIEST, {_RANGE: 2, _POWER: 2}, []],
	Id.SAINT: ["セイント", UnitKind.Id.PRIEST, {_HP: 12}, [Trait.REGENERATION]],
}


## 進化先の名前。進化していなければ空。
static func display_name(id: Id) -> String:
	return _TABLE[id][0] if _TABLE.has(id) else ""


## その進化先になれる種類。
static func origin(id: Id) -> UnitKind.Id:
	return _TABLE[id][1]


## その進化先が stat に足す量（負の値もある）。関係のない能力値と、進化していない駒では 0。
static func bonus(id: Id, stat: Unit.Stat) -> int:
	if not _TABLE.has(id):
		return 0
	var amounts: Dictionary = _TABLE[id][2]
	return amounts.get(stat, 0)


## その進化先の能力値の増減（Unit.Stat -> int）。
static func bonuses(id: Id) -> Dictionary:
	var result: Dictionary = _TABLE[id][2] if _TABLE.has(id) else {}
	return result.duplicate()


## その進化先の特性。
static func traits(id: Id) -> Array[Trait]:
	var result: Array[Trait] = []
	if _TABLE.has(id):
		result.assign(_TABLE[id][3])
	return result


static func has_trait(id: Id, which: Trait) -> bool:
	if not _TABLE.has(id):
		return false
	var list: Array = _TABLE[id][3]
	return list.has(which)


## その種類の進化先（A、B の順）。進化しない種類（将・中立）では空。
static func options_for(kind: UnitKind.Id) -> Array[Id]:
	var result: Array[Id] = []
	for id: Id in _TABLE:
		if _TABLE[id][1] == kind:
			result.append(id)
	return result


## その駒が、いまから進化できるか（まだ進化しておらず、進化先のある種類）。レベルは見ない。
static func can_evolve(unit: Unit) -> bool:
	return unit.evolution == Id.NONE and not options_for(unit.kind).is_empty()


## side のフェーズの始めに、再生で回復する駒（HP が減っている、再生の特性の駒）。
## 並びは盤面の上の行から、左の列から。状態は変えない。
static func regeneration_targets(battle: Battle, side: Unit.Side) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in battle.units:
		if unit.side == side and regeneration_heal(unit) > 0:
			result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	return result


## その駒が再生で回復する量（最大 HP を超えるぶんは切り捨てる）。再生の特性が無ければ 0。
static func regeneration_heal(unit: Unit) -> int:
	if not has_trait(unit.evolution, Trait.REGENERATION):
		return 0
	return clampi(unit.max_hp() - unit.hp, 0, REGENERATION_HEAL)
