class_name ManaEruptionUlt
extends Ult
## 魔力解放（FANTASY）。軍の全員のスキルのクールダウンを 0 にする。docs/tactical-ult.md。
##
## - クールダウンの残っている駒が、すぐにスキルを使えるようになる（SkillReadyEvent。駒の番号の順）
## - もう行動を終えた駒のクールダウンも 0 になる（次の自分の番に使える）
## - スキルを持たない駒（将）と、回数を使い切った駒には何も起きない

func id() -> Ult.Id:
	return Ult.Id.MANA_ERUPTION


func army() -> UnitKind.Army:
	return UnitKind.Army.FANTASY


## 説明の文（game/text/names.csv の ult.mana_eruption.summary）に差し込む値。
func summary_args() -> Dictionary:
	return {}


func apply(battle: Battle, side: Unit.Side) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for unit in battle.units:
		if unit.side != side or unit.skill_cooldown <= 0:
			continue
		unit.skill_cooldown = 0
		if Skills.of(unit) != null and Skills.uses_left(unit) != 0:
			events.append(SkillReadyEvent.new(unit.id, Skills.of(unit).id()))
	return events
