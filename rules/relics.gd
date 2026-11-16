class_name Relics
extends RefCounted
## 聖遺物（docs/relic-buff.md）。中ボスを倒した陣営が受け取る、対戦の終わりまで続く見返り。
##
## - 聖遺物は中ボスごとに決まっている（of_boss。左 = 英知、右 = 勇気）。倒した陣営が、その 1 つを持つ
## - 持っている聖遺物は対戦が控える（Battle.relics）。効果は、その陣営の駒すべて（将も）の「聖遺物の層」
##   （Unit.relic_bonus。docs/player-loadout.md）に足す。種類の基本の値は書き換えない
## - 受け取ったとき、必殺技のゲージもたまる（ULT_GAIN）
##
## 状態を変えるのは grant（Battle.remove_unit が、中ボスが倒れたときに呼ぶ）と equip（Battle.add_unit が呼ぶ）だけ。

enum Id {
	WISDOM,  ## 英知の聖遺物（番号 0 の中ボス。左か上）。最大 HP が上がる
	COURAGE,  ## 勇気の聖遺物（番号 1 の中ボス。右か下）。攻撃力が上がる
}

# ---- 調整値（docs/relic-buff.md の「調整値」） ----

## 英知: 陣営の駒すべての最大 HP に足す量（いまの HP も同じだけ増える）。
const WISDOM_MAX_HP := 5
## 勇気: 陣営の駒すべての攻撃力（回復役は回復量）に足す量。
const COURAGE_POWER := 1
## 聖遺物を受け取ったときに、必殺技のゲージにたまる量（Ults.GAUGE_MAX を 100% として 30%）。どの聖遺物でも同じ。
const ULT_GAIN := 300

## 中ボスの番号（Board.mid_boss_cells の添字）-> その中ボスの聖遺物。
const OF_BOSS: Array[Id] = [Id.WISDOM, Id.COURAGE]

## [足す能力値, 足す量]。名前と 1 行の説明は、画面の文の表（game/text/names.csv の relic.<id>。説明の {amount} に足す量）。
const _TABLE := {
	Id.WISDOM: [Unit.Stat.MAX_HP, WISDOM_MAX_HP],
	Id.COURAGE: [Unit.Stat.POWER, COURAGE_POWER],
}


## 足す量（説明の文に差し込む）。
static func amount(id: Id) -> int:
	return _TABLE[id][1]


## その聖遺物 1 つが足す量（Unit.Stat -> int）。
static func bonus(id: Id) -> Dictionary:
	return {_TABLE[id][0]: _TABLE[id][1]}


## 中ボス boss_index の聖遺物。聖遺物を持たない番号なら -1。
static func of_boss(boss_index: int) -> int:
	return OF_BOSS[boss_index] if boss_index >= 0 and boss_index < OF_BOSS.size() else -1


## その聖遺物を落とす中ボスの番号。
static func boss_of(id: Id) -> int:
	return OF_BOSS.find(id)


## side が持っている聖遺物（受け取った順）。中立は持たない。
static func held(battle: Battle, side: Unit.Side) -> Array[Id]:
	var result: Array[Id] = []
	if side == Unit.Side.PLAYER1 or side == Unit.Side.PLAYER2:
		result.assign(battle.relics[side])
	return result


static func has(battle: Battle, side: Unit.Side, id: Id) -> bool:
	return held(battle, side).has(id)


## その聖遺物を持っている陣営（Unit.Side の値）。まだ誰も持っていなければ -1。
static func holder(battle: Battle, id: Id) -> int:
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if has(battle, side, id):
			return side
	return -1


## side の駒の聖遺物の層に入る量の合計（Unit.Stat -> int）。持っていなければ空。
static func total_bonus(battle: Battle, side: Unit.Side) -> Dictionary:
	var total := {}
	for id in held(battle, side):
		var each := bonus(id)
		for which: Unit.Stat in each:
			total[which] = total.get(which, 0) + each[which]
	return total


## side が聖遺物 id を受け取る（boss_index の中ボスを倒した）。RelicGainedEvent を返す。
## - 対戦に控え、陣営の駒すべて（将も）の聖遺物の層に足す。最大 HP が増えたぶんは、いまの HP も増える（Unit.follow_max_hp）
##   同じ行動で倒れた駒（HP が 0 で、取り除かれるのを待っている）には掛けない
## - 必殺技のゲージに ULT_GAIN をためる（いっぱいになったことは、Battle.apply が UltReadyEvent で知らせる）
static func grant(battle: Battle, side: Unit.Side, id: Id, boss_index: int) -> Array[BattleEvent]:
	battle.relics[side].append(id)
	var affected: Array[Unit] = []
	for unit in battle.units:
		# HP が 0 の駒は、同じ行動で倒れて、取り除かれるのを待っている（爆発やスキルは、全員のダメージを先に当てる）。
		# 効果を掛けると HP が増えて、倒れなくなってしまう。
		if unit.side == side and unit.hp > 0:
			_add(unit, bonus(id))
			affected.append(unit)
	var before := Ults.gauge(battle, side)
	Ults.charge(battle, side, ULT_GAIN)
	var gained := Ults.gauge(battle, side) - before
	return [RelicGainedEvent.new(side, id, boss_index, affected, gained, Ults.gauge(battle, side))]


## 盤に置かれたばかりの駒に、その陣営がもう持っている聖遺物の効果を掛ける（Battle.add_unit が呼ぶ）。
## 聖遺物を取ったあとに置かれた駒にも、同じ効果が掛かる。置かれた駒は、最大 HP の実効値と同じ HP になる。
static func equip(battle: Battle, unit: Unit) -> void:
	_add(unit, total_bonus(battle, unit.side))


static func _add(unit: Unit, amounts: Dictionary) -> void:
	var before := unit.max_hp()
	for which: Unit.Stat in amounts:
		unit.relic_bonus[which] = unit.relic_bonus.get(which, 0) + amounts[which]
	unit.follow_max_hp(before)
