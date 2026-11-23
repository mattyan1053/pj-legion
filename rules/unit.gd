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
## 付いている状態（statuses）の補正の合計で、Statuses が状態を付ける・外すときに足し引きする。
var temporary_bonus := {}
## 付いている状態（docs/unit-statuses.md）。Status.Type -> 残りのターン数。自分のフェーズの始めに 1 減り、0 で外れる。
## 付ける・外すのは Statuses だけ（補正の足し引きがずれないように）。
var statuses := {}
## いまの行動で動く前の statuses（動くと外れる状態を、移動の取り消しで戻すため）。
var statuses_before_move := {}

## このフェーズの行動を終えたか。自分のフェーズの始めに戻る。
var acted := false
## いまの行動で、もう動いたか。動いたなら、動く前のマスと、巡航だったか。
var has_moved := false
var move_origin: Vector2i
var cruised := false
## いまの行動で歩いて使った移動力の合計（転移のあと、続けて動ける残りを出す。Movement.budget_left）。
var move_spent := 0
## 転移したあと、残りの移動力で続けて動けるか（WarpAction が立て、次の移動で倒れる）。
var can_keep_moving := false
## いまのマスへ転移して着いたばかりか（すぐにもう一度は転移できない）。
var just_warped := false
## いまの行動で、移動の取り消しがもうできないか（行動を終えないスキルを使ったあと。docs/active-skills.md）。
var move_locked := false
## スキルをまた使えるまでの残り（docs/active-skills.md）。0 なら使える。自分のフェーズの始めに 1 減る。
var skill_cooldown := 0
## この対戦でスキルを使った回数。回数に上限のあるスキル（Skill.max_uses）が見る。
var skill_uses := 0
## 誓い（部隊の特徴。Traits）の相手の番号。結んでいなければ 0。
var oath_partner := 0
## この駒が倒した駒の陣営（1 << 陣営 のビットの和。仇討ち。Traits）。倒していなければ 0。
var slew_sides := 0
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
## いま立っているマス（砲台）による射程の伸び。Battle が、駒を置いたときと行動のたびに付け直す（Battle.refresh_sites）。
var site_range := 0
## 縫い目の様子の札（Seam）が掛ける能力値の層（Unit.Stat -> 足す値）と、天裂の名残りで射程が縮むか。対戦が、駒を置くときに付ける（Seam.equip）。
var sign_bonus := {}
var hazed := false
## 縫い目の様子の札（縫い代の風）が巡航の移動力に足す値（Movement.budget）。
var cruise_bonus := 0


func copy() -> Unit:
	var result := Unit.new(id, kind, side, cell)
	StateCopy.copy_fields(self, result)
	return result


## フェーズの始めに、行動前の状態へ戻す。
func reset_action() -> void:
	acted = false
	has_moved = false
	cruised = false
	move_locked = false
	clear_move_steps()


## いまの行動の移動の途中の記録（使った移動力、転移のあと）を消す。
func clear_move_steps() -> void:
	move_spent = 0
	can_keep_moving = false
	just_warped = false


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


## 特性（Evolution.Trait）を持つか。進化先か、持っている装備のどれか、または種類そのもの（魔物。Monsters.kind_traits）が与えていれば持つ（重ねても 1 つ）。
func has_trait(which: Evolution.Trait) -> bool:
	return Evolution.has_trait(evolution, which) or Equipment.grants(equipment, which) or Monsters.kind_traits(kind).has(which)


## 周り 8 マスに支配領域（ZOC）を作るか。前衛と、その特性を持つ進化先・装備。
func exerts_zoc() -> bool:
	return UnitKind.exerts_zoc(kind) or has_trait(Evolution.Trait.EXERTS_ZOC)


## 敵の支配領域（ZOC）で止まらずに進めるか。
func ignores_zoc() -> bool:
	return has_trait(Evolution.Trait.IGNORES_ZOC)


## into に入るのに使う移動力。入れないマスなら負の値（Board.move_cost と同じ）。
## 森を歩く特性の駒は、森にも平地と同じ移動力で入る。
func move_cost(board: Board, into: Vector2i) -> int:
	var cost := board.move_cost(into)
	if cost > 1 and has_trait(Evolution.Trait.FOREST_WALK):
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


## 実効値。層 1 に、聖遺物、縫い目の様子の札、一時的な補正の順で足す（射程は、砲台の伸びも。天裂の名残りは、足したあとの射程を縮める）。最大 HP は 1、ほかは 0 を下回らない。
func stat(which: Stat) -> int:
	var value := base_stat(which)
	if which == Stat.ATTACK_RANGE:
		value += site_range
	value += relic_bonus.get(which, 0)
	value += sign_bonus.get(which, 0)
	value += temporary_bonus.get(which, 0)
	if which == Stat.ATTACK_RANGE and hazed:
		value = Seam.hazed_range(value)
	return maxi(value, 1 if which == Stat.MAX_HP else 0)


func max_hp() -> int:
	return stat(Stat.MAX_HP)


## 攻撃力（回復役は回復量）。
func power() -> int:
	return stat(Stat.POWER)


## 動けない特性（Evolution.Trait.ROOTED）の駒は、補正があっても 0。
func move_range() -> int:
	if has_trait(Evolution.Trait.ROOTED):
		return 0
	return stat(Stat.MOVE_RANGE)


func attack_range() -> int:
	return stat(Stat.ATTACK_RANGE)


func is_enemy_of(other: Unit) -> bool:
	return side != other.side
