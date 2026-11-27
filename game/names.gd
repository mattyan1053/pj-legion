extends RefCounted
## ゲームの中のものの名前と説明（陣営、軍、役割、能力、特性、盤の上の効果、駒、進化先、持ち物、スキル、必殺技、状態、聖遺物、マップ）。
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


## ストーリーの呼び方にするか。真なら、陣営を遊ぶ人の側から「味方」「敵」と呼ぶ（色と「プレイヤー1」で呼ばない。中立はそのまま）。
## ストーリーの間の画面（出撃準備・対戦）が、入るときに真にし、出るときに偽に戻す（docs/wording.md の「陣営の呼び方」）。
static var story_sides := false
## ストーリーの陣営の呼び名（[人の軍, 敵の軍]。話のファイルの [ally] / [enemy] の name か、軍の既定の呼び名。story_battle.gd の side_names）。
## 空なら「味方」「敵」。story_sides が真の間だけ使う。
static var story_names: Array[String] = ["", ""]
## 陣営の短い呼び名（[人の軍, 敵の軍]。上の帯の陣営の欄と、ログの駒の名前の前。話のファイルの short か、軍の既定の短い呼び名）。
static var story_shorts: Array[String] = ["", ""]
## 呼び名と短い呼び名の字数の上限（番の札・上の帯の陣営の欄に収まる長さ。話のファイルの検査が見る）。
const STORY_NAME_MAX := 9
const STORY_SHORT_MAX := 5


## 陣営の名前（見出し、番の知らせ、決着、本陣のマス）。
static func side(of_side: Unit.Side) -> String:
	if story_sides and of_side != Unit.Side.NEUTRAL:
		return _story_name(of_side)
	return Text.t("side." + word(Unit.Side, of_side))


## 陣営の短い名前（ログの駒の名前の前、上の帯の陣営ごとの欄）。
static func side_word(of_side: Unit.Side) -> String:
	if story_sides and of_side != Unit.Side.NEUTRAL:
		var short: String = story_shorts[of_side] if int(of_side) < story_shorts.size() else ""
		return short if short != "" else _story_name(of_side)
	return Text.t("side.%s.short" % word(Unit.Side, of_side))


## ストーリーの陣営の、遊ぶ人から見た間柄（「味方」「敵」）。駒の情報の所属の札。
static func side_relation(of_side: Unit.Side) -> String:
	if of_side == Unit.Side.NEUTRAL:
		return Text.t("side.neutral")
	return Text.t("side.story." + word(Unit.Side, of_side))


## 軍 of_army の、ストーリーでの既定の呼び名（「ベルク連邦」「リュエル騎士領」。軍の無い群れは「亡者の群れ」）。
static func story_army_name(of_army: UnitKind.Army) -> String:
	return Text.t("side.story.army." + word(UnitKind.Army, of_army))


## 軍 of_army の、ストーリーでの既定の短い呼び名（「連邦」「騎士領」「亡者」）。
static func story_army_short(of_army: UnitKind.Army) -> String:
	return Text.t("side.story.army.%s.short" % word(UnitKind.Army, of_army))


static func _story_name(of_side: Unit.Side) -> String:
	var name: String = story_names[of_side] if int(of_side) < story_names.size() else ""
	return name if name != "" else side_relation(of_side)


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
	return Text.t("trait." + word(Evolution.Trait, of_trait), _trait_args())


## 特性の短い名前（持ち物の効果の 1 行に並べる。「森歩き」「毎ターン 5 回復」）。
static func trait_short(of_trait: Evolution.Trait) -> String:
	return Text.t("trait." + word(Evolution.Trait, of_trait) + ".short", _trait_args())


## 特性の文に差し込む値。
static func _trait_args() -> Dictionary:
	return {
		"heal": Evolution.REGENERATION_HEAL, "radius": Monsters.RALLY_RADIUS, "power": Monsters.RESOLVE_POWER,
		"turns": Monsters.KNOT_TURNS, "damage": Monsters.BURST_DAMAGE, "spores": Monsters.SPORE_PENALTY,
	}


## 盤の上の効果の名前。
static func field_effect(type: FieldEffect.Type) -> String:
	return Text.t("field_effect." + word(FieldEffect.Type, type))


## 中ボスの名前（話のファイル・マップのファイルの boss。docs/neutral-mid-boss.md の「名前」）。画面では「中ボス」と言わず、この名前で呼ぶ。
## 対戦の画面が、対戦を始めるたびに入れる（空なら既定の「番人」。画面の文の表の default.boss）。文の {boss} に差し込まれる（text.gd の shared）。
static func set_boss(name: String) -> void:
	Text.shared["boss"] = name if name != "" else Text.t("default.boss")


static func boss() -> String:
	var fallback := Text.t("default.boss")  # 表を読む（shared の既定も、ここで入る）
	return String(Text.shared.get("boss", fallback))


## 駒の種類の名前。中ボス（エリートミニオン）は、その対戦の中ボスの名前（boss）。
static func kind(of_kind: UnitKind.Id) -> String:
	if of_kind == UnitKind.Id.ELITE_MINION:
		return boss()
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
		"move": AllOutAssaultUlt.MOVE_BONUS, "power": AllOutAssaultUlt.POWER_BONUS, "resolve": Monsters.RESOLVE_POWER,
	}
	return Text.t("status.%s.summary" % word(Status.Type, type), args)


## 軍略（Traits.Id）の名前と、1 行の文（docs/troop-traits.md）。
static func troop_trait(id: int) -> String:
	return Text.t("troop_trait." + Traits.key(id)) if id != Traits.NONE else ""


## 軍略の文（1 文。条件 → 効果の順）: 「このターン味方が攻撃した敵にダメージ +2」。
## 表の troop_trait.<名前>.text に、効果（troop_trait.<名前>.effect）を {gain} で差し込む。画面は効果の所だけ色を変える（trait_sentence.gd）。
static func troop_trait_text(id: int) -> String:
	if id == Traits.NONE:
		return ""
	return Text.t("troop_trait.%s.text" % Traits.key(id), {"gain": troop_trait_effect(id), "medic": kind(_healer_of(Traits.army_of(Traits.Id.SUPPLY))), "paladin": kind(Traits.GUARDIAN)})


## 補給線の文の {medic}: その軍の、最初の回復役（ルールは回復役なら誰でも。Traits.supplier_at。いまは衛生兵）。
static func _healer_of(of_army: UnitKind.Army) -> UnitKind.Id:
	for each in Armies.roster(of_army):
		if UnitKind.role(each) == UnitKind.Role.HEALER:
			return each
	return UnitKind.Id.MEDIC


## 軍略の効果（数のある所。「ダメージ +2」）。文の中で色を変える所。
static func troop_trait_effect(id: int) -> String:
	return "" if id == Traits.NONE else Text.t("troop_trait.%s.effect" % Traits.key(id), {"amount": troop_trait_amount(id)})


## 軍略の数（増減するダメージ、回復する HP）。文と、盤の上の札に差し込む。
static func troop_trait_amount(id: int) -> int:
	var amounts := {
		Traits.Id.FOCUS: Traits.FOCUS_BONUS, Traits.Id.RANKS: Traits.RANKS_GUARD, Traits.Id.SUPPLY: Traits.SUPPLY_HEAL,
		Traits.Id.VENGEANCE: Traits.VENGEANCE_BONUS, Traits.Id.OATH: Traits.OATH_BONUS, Traits.Id.GUARD: Traits.GUARD_SHIELD,
	}
	return amounts.get(id, 0)


## 縫い目の様子の札（Seam.Sign）の名前と、効果の文（短く言い切る 1 行。比べる元の値は書かない。docs/seam-signs.md）。
static func sign_name(sign: int) -> String:
	return Text.t("sign." + Seam.key(sign))


static func sign_summary(sign: int) -> String:
	var args := {
		"haze_cut": Seam.HAZE_CUT, "brim_times": String.num(Seam.BRIM_PERCENT / 100.0),
		"loose": Seam.LOOSE_RESPAWN_PERCENT, "gale": Seam.GALE_CRUISE,
		"gleam": Seam.GLEAM_RANGE, "thicket_times": String.num(Seam.THICKET_RATE_PERCENT / 100.0), "taut": Seam.TAUT_CUT,
	}
	return Text.t("sign.%s.summary" % Seam.key(sign), args)


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


## 生成のマップの名前。
static func stage(of_stage: BoardGenerator.Stage) -> String:
	return Text.t("stage." + word(BoardGenerator.Stage, of_stage))
