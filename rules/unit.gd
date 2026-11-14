class_name Unit
extends RefCounted
## 盤上の駒 1 体。種類・陣営・位置と、いまの状態を持つ。
##
## 能力値（最大 HP・攻撃力・移動力・射程）は、次の層を順に重ねた実効値で使う。
##   1. 基礎 + 成長 + 進化 + 装備（種類の基本の値に、レベルアップで伸びたぶん、進化先の増減、持っている装備のぶんを足す）
##   2. 聖遺物（relic_bonus）
##   3. 一時的な補正（temporary_bonus）
## ルールは UnitKind の値を直に読まず、駒の max_hp() / power() / move_range() / attack_range() を使う。

## 陣営。PLAYER1 / PLAYER2 の値は Board.hq_cells の添字と同じ。
enum Side { PLAYER1 = 0, PLAYER2 = 1, NEUTRAL = 2 }

## 層を重ねて決まる能力値。POWER は攻撃力（回復役は回復量）。
enum Stat { MAX_HP, POWER, MOVE_RANGE, ATTACK_RANGE }

## 戦いの中で駒を指す番号。Battle が振る。
var id: int
var kind: UnitKind.Id
var side: Unit.Side
var cell: Vector2i
var hp: int

## レベル（1 から Growth.MAX_LEVEL まで）と、いまのレベルでためた経験値。docs/experience-levelup.md。
var level := 1
var experience := 0
## レベルアップで伸びた量（層 1）。Stat -> int。無い能力値は 0。種類の基本の値は書き換えない。
var growth_bonus := {}
## 進化先（層 1）。進化していなければ Evolution.Id.NONE。docs/branch-evolution.md。
var evolution := Evolution.Id.NONE
## レベルが上限に届き、進化先を選ぶのを待っているか（選ぶまで、対戦はほかの行動を受け付けない）。
var evolution_ready := false
## 持っている装備（層 1）。対戦の途中では変わらない。
var equipment: Array[Equipment.Id] = []
## 聖遺物で足す量（層 2）。Stat -> int。無い能力値は 0。
var relic_bonus := {}
## 一時的な補正で足す量（層 3）。Stat -> int。無い能力値は 0。負の値もある。
var temporary_bonus := {}

## このフェーズの行動を終えたか。自分のフェーズの始めに戻る。
var acted := false
## いまの行動で、もう動いたか。動いたなら、動く前のマスと、巡航だったか。
var has_moved := false
var move_origin: Vector2i
var cruised := false
## スキルをまた使えるまでの残り（docs/active-skills.md）。0 なら使える。自分のフェーズの始めに 1 減る。
var skill_cooldown := 0
## 中立の駒が守る場所（エナジー・コアなら、湧いた結晶泉）。プレイヤーの駒では Board.NO_CELL。
var home_cell := Board.NO_CELL


func _init(
	unit_id: int,
	unit_kind: UnitKind.Id,
	unit_side: Unit.Side,
	at: Vector2i,
	unit_equipment: Array[Equipment.Id] = [],
) -> void:
	id = unit_id
	kind = unit_kind
	side = unit_side
	cell = at
	equipment = unit_equipment.duplicate()
	hp = max_hp()


## 同じ状態の駒を作る（Battle.clone() が使う）。
func copy() -> Unit:
	var result := Unit.new(id, kind, side, cell)
	StateCopy.copy_fields(self, result)
	return result


## フェーズの始めに、行動前の状態へ戻す。
func reset_action() -> void:
	acted = false
	has_moved = false
	cruised = false


## 層 1（基礎 + 成長 + 進化 + 装備）の値。
func base_stat(which: Stat) -> int:
	var value := 0
	match which:
		Stat.MAX_HP:
			value = UnitKind.max_hp(kind)
		Stat.POWER:
			value = UnitKind.power(kind)
		Stat.MOVE_RANGE:
			value = UnitKind.move_range(kind)
		Stat.ATTACK_RANGE:
			value = UnitKind.attack_range(kind)
	value += growth_bonus.get(which, 0) + Evolution.bonus(evolution, which)
	return value + Equipment.total_bonus(equipment, which)


## 成長（層 1）を足す。最大 HP が増えたら、増えたぶんだけ HP も増える（follow_max_hp）。
func add_growth(which: Stat, amount: int) -> void:
	var before := max_hp()
	growth_bonus[which] = growth_bonus.get(which, 0) + amount
	follow_max_hp(before)


## 進化する（層 1）。進化先の能力値の増減と特性が、すぐに効く。最大 HP が増えたら、増えたぶんだけ HP も増える。
func evolve(to: Evolution.Id) -> void:
	var before := max_hp()
	evolution = to
	evolution_ready = false
	follow_max_hp(before)


## 駒の呼び名。進化していれば進化先の名前、していなければ種類の名前。
func display_name() -> String:
	return UnitKind.display_name(kind) if evolution == Evolution.Id.NONE else Evolution.display_name(evolution)


## 周り 8 マスに支配領域（ZOC）を作るか。前衛と、その特性を持つ進化先。
func exerts_zoc() -> bool:
	return UnitKind.exerts_zoc(kind) or Evolution.has_trait(evolution, Evolution.Trait.EXERTS_ZOC)


## 敵の支配領域（ZOC）で止まらずに進めるか。
func ignores_zoc() -> bool:
	return Evolution.has_trait(evolution, Evolution.Trait.IGNORES_ZOC)


## into に入るのに使う移動力。入れないマスなら負の値（Board.move_cost と同じ）。
## 森を歩く特性の駒は、森にも平地と同じ移動力で入る。
func move_cost(board: Board, into: Vector2i) -> int:
	var cost := board.move_cost(into)
	if cost > 1 and Evolution.has_trait(evolution, Evolution.Trait.FOREST_WALK):
		return 1
	return cost


## 最大 HP の実効値が before から変わったあとに、HP を合わせる。
## 増えたら、増えたぶんだけ HP も増やす（受けているダメージの量は変わらない）。
## 減ったら、HP は新しい最大 HP を超えないように切り詰める。
## どの層の変化でも（成長、聖遺物、一時的な補正）、最大 HP を変えたルールがこれを呼ぶ。
func follow_max_hp(before: int) -> void:
	var after := max_hp()
	if after > before:
		hp += after - before
	hp = mini(hp, after)


## 実効値。層 1 に、聖遺物、一時的な補正の順で足す。最大 HP は 1、ほかは 0 を下回らない。
func stat(which: Stat) -> int:
	var value := base_stat(which)
	value += relic_bonus.get(which, 0)
	value += temporary_bonus.get(which, 0)
	return maxi(value, 1 if which == Stat.MAX_HP else 0)


func max_hp() -> int:
	return stat(Stat.MAX_HP)


## 攻撃力（回復役は回復量）。
func power() -> int:
	return stat(Stat.POWER)


func move_range() -> int:
	return stat(Stat.MOVE_RANGE)


func attack_range() -> int:
	return stat(Stat.ATTACK_RANGE)


func is_enemy_of(other: Unit) -> bool:
	return side != other.side
