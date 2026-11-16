extends RefCounted
## ゲームの中のものの名前と説明（陣営、軍、役割、能力、特性、盤の上の効果、駒、進化先、持ち物、スキル、必殺技、状態、聖遺物、ステージ）。
## ノードに依存しない。文は画面の文の表（game/text/names.csv。docs/text.md）にあり、ここは列挙から鍵を作って引くだけ。
## ルール（rules/）は名前の文を持たない（列挙と、説明に差し込む値だけ）。
##
## 鍵は「種類.列挙の名前の小文字」（unit.shield_trooper、skill.fireball）。説明は後ろに .summary。
## 列挙の値を足したら、表に行を足す（足し忘れは tests/game/test_names.gd が落ちる）。

const Text := preload("res://game/text.gd")

## 能力の並び（この順に並べて出す）。
const STATS: Array[Unit.Stat] = [Unit.Stat.MAX_HP, Unit.Stat.POWER, Unit.Stat.MOVE_RANGE, Unit.Stat.ATTACK_RANGE]


## 列挙 names の値 value の、鍵に使う名前（小文字）。
static func word(names: Dictionary, value: int) -> String:
	return String(names.find_key(value)).to_lower()


## 陣営の名前（見出し、番の知らせ、決着、本陣のマス）。
static func side(of_side: Unit.Side) -> String:
	return Text.t("side." + word(Unit.Side, of_side))


## 陣営の短い名前（ログの駒の名前の前、上の帯の陣営ごとの欄）。
static func side_word(of_side: Unit.Side) -> String:
	return Text.t("side.%s.short" % word(Unit.Side, of_side))


## 軍の名前。軍を持たない駒（将、中立）は「軍なし」。
static func army(of_army: UnitKind.Army) -> String:
	return Text.t("army." + word(UnitKind.Army, of_army))


## 役割の名前（役割を持たない駒（将、中立）は空）。
static func role(of_role: UnitKind.Role) -> String:
	return "" if of_role == UnitKind.Role.NONE else Text.t("role." + word(UnitKind.Role, of_role))


## 役割の、ひとことの説明（役割を持たない駒は空）。
static func role_summary(of_role: UnitKind.Role) -> String:
	return "" if of_role == UnitKind.Role.NONE else Text.t("role.%s.summary" % word(UnitKind.Role, of_role))


## 能力の名前。
static func stat(of_stat: Unit.Stat) -> String:
	return Text.t("stat." + word(Unit.Stat, of_stat))


## 進化先の特性の説明。
static func trait_text(of_trait: Evolution.Trait) -> String:
	return Text.t("trait." + word(Evolution.Trait, of_trait), {"heal": Evolution.REGENERATION_HEAL})


## 盤の上の効果の名前。
static func field_effect(type: FieldEffect.Type) -> String:
	return Text.t("field_effect." + word(FieldEffect.Type, type))


## 駒の種類の名前。
static func kind(of_kind: UnitKind.Id) -> String:
	return Text.t("unit." + word(UnitKind.Id, of_kind))


## 進化先の名前。進化していなければ空。
static func evolution(id: Evolution.Id) -> String:
	return "" if id == Evolution.Id.NONE else Text.t("evolution." + word(Evolution.Id, id))


## 駒の呼び名。進化していれば進化先の名前、していなければ種類の名前。
static func unit(of_unit: Unit) -> String:
	return kind(of_unit.kind) if of_unit.evolution == Evolution.Id.NONE else evolution(of_unit.evolution)


## 持ち物（装備）の名前。
static func item(id: Equipment.Id) -> String:
	return Text.t("item." + word(Equipment.Id, id))


## スキルの名前と、1 行の説明。
static func skill(of_skill: Skill) -> String:
	return Text.t("skill." + word(Skill.Id, of_skill.id()))


static func skill_summary(of_skill: Skill) -> String:
	return Text.t("skill.%s.summary" % word(Skill.Id, of_skill.id()), of_skill.summary_args())


## 必殺技の名前と、1 行の説明。
static func ult(of_ult: Ult) -> String:
	return Text.t("ult." + word(Ult.Id, of_ult.id()))


static func ult_summary(of_ult: Ult) -> String:
	return Text.t("ult.%s.summary" % word(Ult.Id, of_ult.id()), of_ult.summary_args())


## 状態の名前と、効果の短い説明（駒の情報の枠に、残りの期間と一緒に出す）。
static func status(type: Status.Type) -> String:
	return Text.t("status." + word(Status.Type, type))


static func status_summary(type: Status.Type) -> String:
	var args := {
		"range": PrecisionAimSkill.RANGE_BONUS, "penalty": AdrenalineShotSkill.POWER_PENALTY,
		"move": AllOutAssaultUlt.MOVE_BONUS, "power": AllOutAssaultUlt.POWER_BONUS,
	}
	return Text.t("status.%s.summary" % word(Status.Type, type), args)


## 聖遺物の名前と、1 行の説明。
static func relic(id: Relics.Id) -> String:
	return Text.t("relic." + word(Relics.Id, id))


static func relic_summary(id: Relics.Id) -> String:
	return Text.t("relic.%s.summary" % word(Relics.Id, id), {"amount": Relics.amount(id)})


## 聖遺物の短い名前（上の帯の欄）と、駒 1 体への効果（駒の上に出す）。
static func relic_short(id: Relics.Id) -> String:
	return Text.t("relic.%s.short" % word(Relics.Id, id))


static func relic_effect(id: Relics.Id) -> String:
	return Text.t("relic.%s.effect" % word(Relics.Id, id), {"amount": Relics.amount(id)})


## 生成のステージの名前。
static func stage(of_stage: BoardGenerator.Stage) -> String:
	return Text.t("stage." + word(BoardGenerator.Stage, of_stage))
