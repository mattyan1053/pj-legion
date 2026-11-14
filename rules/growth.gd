class_name Growth
extends RefCounted
## 経験値とレベルアップ（docs/experience-levelup.md）。
##
## - 経験値が入るのは、軍に属する駒（役割を持つ駒）だけ。将と中立の駒は育たない
## - 入るのは、駒が自分の行動で相手に何かをしたときだけ: 攻撃が当たった（相手が生き残った）、攻撃で倒した、味方を回復した
##   起爆樽の爆発、回復の泉など、駒の行動でない出来事では入らない
## - EXPERIENCE_PER_LEVEL たまるとレベルが上がり、余りは次のレベルへ繰り越す。MAX_LEVEL より上には上がらない
## - レベルアップで伸びる量は役割ごと（GAINS）。駒の成長の層（Unit.growth_bonus）に足し、種類の基本の値は書き換えない
##
## 計算（preview、attack_experience、heal_experience）は状態を変えない。戦闘予測は、これで
## 「この攻撃でいくつ入り、レベルが上がるか」を知る。適用（gain）も同じ計算を通す。
##
## レベルが MAX_LEVEL に届いた駒は、進化先を選べるようになる（Evolution。docs/branch-evolution.md）。

# ---- 調整値（docs/experience-levelup.md の「調整値」） ----

## 攻撃が当たり、相手が生き残ったとき。
const HIT_EXPERIENCE := 10
## 攻撃でプレイヤーの駒を倒したとき（当たったぶんの HIT_EXPERIENCE は足さない）。
const DEFEAT_EXPERIENCE := 50
## 攻撃で中立の駒を倒したとき（同上）。
const NEUTRAL_DEFEAT_EXPERIENCE := 30
## 味方を回復したとき（回復した量によらない）。
const HEAL_EXPERIENCE := 20
## 1 レベル上がるのに要る経験値（どのレベルでも同じ）。
const EXPERIENCE_PER_LEVEL := 120
## これより上には上がらない。
const MAX_LEVEL := 3
## 役割 -> 1 レベルごとに伸びる量（Unit.Stat -> int）。POWER は攻撃力、回復役では回復量。
const GAINS := {
	UnitKind.Role.VANGUARD: {Unit.Stat.MAX_HP: 6, Unit.Stat.POWER: 1},
	UnitKind.Role.REARGUARD: {Unit.Stat.MAX_HP: 3, Unit.Stat.POWER: 1},
	UnitKind.Role.RAIDER: {Unit.Stat.MAX_HP: 3, Unit.Stat.POWER: 1},
	UnitKind.Role.HEALER: {Unit.Stat.MAX_HP: 3, Unit.Stat.POWER: 2},
}


## 経験値を足したら、どうなるか（状態を変えない計算の結果）。
class Outcome:
	extends RefCounted
	## 実際に入る経験値（育たない駒や、最大のレベルの駒では 0）。
	var gained := 0
	## 足したあとのレベルと、そのレベルでためた経験値（繰り越したあと）。
	var level := 1
	var experience := 0
	## 上がるレベルの数。
	var levels_gained := 0
	## これで最大のレベルに届き、進化先を選ぶことになるか。
	var evolution_ready := false


## その駒が経験値を受け取り、育つか。軍に属する駒（役割を持つ駒）だけ。
static func can_grow(unit: Unit) -> bool:
	return GAINS.has(UnitKind.role(unit.kind))


## unit に amount の経験値を足したらどうなるか。状態は変えない。
## 最大のレベルの駒には入らない。最大のレベルに届いたら、余りは捨てる（ためる先が無い）。
static func preview(unit: Unit, amount: int) -> Outcome:
	var result := Outcome.new()
	result.level = unit.level
	result.experience = unit.experience
	if amount <= 0 or not can_grow(unit) or unit.level >= MAX_LEVEL:
		return result
	result.gained = amount
	result.experience += amount
	while result.experience >= EXPERIENCE_PER_LEVEL and result.level < MAX_LEVEL:
		result.experience -= EXPERIENCE_PER_LEVEL
		result.level += 1
		result.levels_gained += 1
	if result.level >= MAX_LEVEL:
		result.experience = 0
		result.evolution_ready = Evolution.can_evolve(unit)
	return result


## attacker が target を攻撃したときに入る経験値。状態は変えない（倒せるかは Combat.damage で見る）。
static func attack_experience(battle: Battle, attacker: Unit, target: Unit) -> int:
	if Combat.damage(battle, attacker, target) < target.hp:
		return HIT_EXPERIENCE
	return NEUTRAL_DEFEAT_EXPERIENCE if target.side == Unit.Side.NEUTRAL else DEFEAT_EXPERIENCE


## 回復したときに入る経験値。
static func heal_experience() -> int:
	return HEAL_EXPERIENCE


## 経験値を足し、レベルが上がればそのぶん能力値を伸ばす。起きたことを返す:
## ExperienceGainedEvent、上がったレベルごとの LevelUpEvent、最大のレベルに届いたら EvolutionOfferedEvent。入らなければ（preview の gained が 0）、何も返さない。
## 結果は preview と同じになる。
static func gain(unit: Unit, amount: int, reason: ExperienceGainedEvent.Reason) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var gained := preview(unit, amount).gained
	if gained == 0:
		return events
	unit.experience += gained
	events.append(ExperienceGainedEvent.new(unit.id, gained, reason, unit.experience))
	while unit.experience >= EXPERIENCE_PER_LEVEL and unit.level < MAX_LEVEL:
		events.append(level_up(unit))
	if unit.evolution_ready:
		events.append(EvolutionOfferedEvent.new(unit.id, Evolution.options_for(unit.kind)))
	if unit.level >= MAX_LEVEL:
		unit.experience = 0
	return events


## レベルを 1 つ上げ、たまった経験値から EXPERIENCE_PER_LEVEL を差し引き（余りは繰り越す）、役割ごとの量だけ能力値を伸ばす。
## 最大 HP が伸びたぶんは、いまの HP も増える。最大のレベルに届いたら、ためた経験値は 0 にする。
## 最大のレベルに届いた駒は、進化先を選ぶのを待つ（Unit.evolution_ready。知らせの EvolutionOfferedEvent は gain が足す）。
static func level_up(unit: Unit) -> LevelUpEvent:
	unit.experience = maxi(0, unit.experience - EXPERIENCE_PER_LEVEL)
	unit.level += 1
	if unit.level >= MAX_LEVEL:
		unit.experience = 0
		unit.evolution_ready = Evolution.can_evolve(unit)
	var gains: Dictionary = GAINS[UnitKind.role(unit.kind)]
	for which: Unit.Stat in gains:
		unit.add_growth(which, gains[which])
	return LevelUpEvent.new(unit, gains)
