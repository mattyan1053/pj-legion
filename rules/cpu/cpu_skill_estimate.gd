extends RefCounted
class_name CpuSkillEstimate
## CPU（cpu_player.gd）が、スキルを使う手を見積もるための、スキルごとの決まり。1 スキル 1 ファイル（rules/cpu/<スキル>_cpu.gd）。
##
## - targets: 対象に選ぶ価値のありそうなマス。スキルを使う手は、ここに並んだ対象だけを、複製の上で使ってみて比べる
##   （全部のマスを試すと、時間がかかりすぎる）。
## - value: 使った結果の価値（SkillUsedEvent と、使ったあとの複製を受け取る）。ダメージ・回復・経験値のイベントは
##   CpuPlayer がそのまま読むので、それだけで価値が決まるスキルは 0 のまま（ファイアボール）。
##
## スキルを足したら、ここの ESTIMATES に 1 行と、ファイルを 1 つ足す（載せ忘れは tests/rules/test_enum_tables.gd が見つける）。
## CpuPlayer の考えている途中の状態（危険の表、立つマスなど）を読むので、CpuPlayer の _ で始まる変数とメソッドに触る。
## 受け取る cpu は CpuPlayer と型を付けない（Variant）。別の版の CPU（docs/cpu-ai.md の「別の版と比べる」）も、
## 同じ見積もりを使うため。cpu から読んだ値は、受ける変数に型を書く。

const ESTIMATES := {
	Skill.Id.TACTICAL_BARRICADE: preload("res://rules/cpu/tactical_barricade_cpu.gd"),
	Skill.Id.SAINT_PLACE: preload("res://rules/cpu/saint_place_cpu.gd"),
	Skill.Id.SMOKE_GRENADE: preload("res://rules/cpu/smoke_grenade_cpu.gd"),
	Skill.Id.FIREBALL: preload("res://rules/cpu/fireball_cpu.gd"),
	Skill.Id.DIVINE_SHIELD: preload("res://rules/cpu/divine_shield_cpu.gd"),
	Skill.Id.PRECISION_AIM: preload("res://rules/cpu/precision_aim_cpu.gd"),
	Skill.Id.SHADOW_STEP: preload("res://rules/cpu/shadow_step_cpu.gd"),
	Skill.Id.ADRENALINE_SHOT: preload("res://rules/cpu/adrenaline_shot_cpu.gd"),
	Skill.Id.BONE_RAISE: preload("res://rules/cpu/bone_raise_cpu.gd"),
	Skill.Id.WAR_DRUM: preload("res://rules/cpu/war_drum_cpu.gd"),
}

## スキル -> 見積もり（状態を持たないので、1 つずつ作って使い回す）。
static var _made: Dictionary = {}


## skill の見積もり。載っていなければ null（そのスキルは、選べる対象をすべて試し、イベントだけで価値を決める）。
static func of(skill: Skill.Id) -> CpuSkillEstimate:
	if not _made.has(skill):
		_made[skill] = ESTIMATES[skill].new() if ESTIMATES.has(skill) else null
	return _made[skill]


## 対象に選ぶ価値のありそうなマスの集合。cells は、駒が通常の移動で止まれるマス（-> 立つマスの価値）。
func targets(_cpu: Variant, _unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	return {}


## 使った結果の、イベントだけでは決まらない価値。sim は使ったあとの複製。
func value(_cpu: Variant, _used: SkillUsedEvent, _sim: Battle) -> float:
	return 0.0
