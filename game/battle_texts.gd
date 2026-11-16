extends RefCounted
## 対戦の画面の文: 下の帯の説明、駒のそばのメニューの項目と説明、マスの説明、駒の行動の状態、必殺技のボタン。
## ノードに依存しない（テストから呼べる）。対戦の場面（battle_screen.gd）が、いまの盤と操作の状態を渡して作らせ、画面に出す。

const BattleHud := preload("res://game/battle_hud.gd")
const BattleUiState := preload("res://game/battle_ui_state.gd")
const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")
const Mode := BattleUiState.Mode

## 駒のそばのメニューの項目の名前。
const MENU_ATTACK := &"attack"
const MENU_HEAL := &"heal"
const MENU_SKILL := &"skill"
const MENU_WAIT := &"wait"
const MENU_UNDO := &"undo"
const MENU_BACK := &"back"
const MENU_WARP := &"warp"

## マスに特別なものが無いときの説明。
static func nothing_special() -> String:
	return Text.t("battle.cell.nothing")


# ---- 下の帯 ----


## 下の帯の、いまできることの説明。クリックだけで進められる言い方で、短く書く。
## unit は選んでいる駒、inspected は見ている駒（どちらも無ければ null）。cpu_turn は CPU の番（を進めている途中）か。
## self_skill は、選べる対象が自分のマスだけのスキル（自分に使うスキル）を選んでいるか。
## confirming_unacted は、ターン終了を確かめている途中なら、まだ行動していない駒の数（確かめていなければ 0）。
static func hint(
	battle: Battle, unit: Unit, inspected: Unit, mode: Mode, cpu_turn: bool, confirming_ult: bool, self_skill: bool,
	confirming_unacted := 0, can_warp := false, pinned := 0
) -> String:
	if battle.is_over():
		return Text.t("battle.hint.over")
	if cpu_turn:
		return Text.t("battle.hint.cpu_turn")
	if battle.evolving_unit() != null:
		return Text.t("battle.hint.evolve")
	if confirming_ult:
		var ult := Ults.of(battle, battle.phase)  # 確かめるのは、人の番だけ
		if ult == null:
			return Text.t("battle.hint.confirm_ult_unnamed")
		return Text.t("battle.hint.confirm_ult", {"ult": Names.ult(ult)})
	if confirming_unacted > 0 and inspected == null:
		return Text.t("battle.hint.confirm_end_turn", {"count": confirming_unacted})
	if inspected != null:
		var ranges := Text.t("battle.hint.ranges.own") if inspected.side == battle.phase else Text.t("battle.hint.ranges.foe")
		if pinned > 0:
			ranges += Text.t("battle.hint.ranges.pinned")
		var key := "battle.hint.inspect_back" if unit != null else "battle.hint.inspect"
		return Text.t(key, {"unit": Names.unit(inspected), "ranges": ranges})
	if unit == null and pinned > 0:
		return Text.t("battle.hint.choose_pinned")
	if unit == null:
		return Text.t("battle.hint.choose")
	if mode == Mode.SKILL and self_skill:
		return Text.t("battle.hint.skill_self", {"skill": Names.skill(Skills.of(unit))})
	if mode == Mode.SKILL:
		var key := "battle.hint.skill_ends" if Skills.of(unit).ends_action() else "battle.hint.skill_then_attack"
		return Text.t(key, {"skill": Names.skill(Skills.of(unit))})
	if mode == Mode.ATTACK:
		return Text.t("battle.hint.attack")
	if mode == Mode.HEAL:
		return Text.t("battle.hint.heal")
	if not battle.can_act(unit):
		if unit.side != battle.phase:
			return Text.t("battle.hint.foe_unit")
		return Text.t("battle.hint.acted")
	if unit.move_locked:
		return Text.t("battle.hint.after_skill")
	if unit.has_moved and can_warp:
		return Text.t("battle.hint.on_portal")
	if unit.has_moved:
		if unit.cruised:
			return Text.t("battle.hint.after_cruise")
		return Text.t("battle.hint.after_move")
	if UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
		return Text.t("battle.hint.move_healer")
	return Text.t("battle.hint.move")


## 自分の番の「おまかせ」を確かめている間と、任せている間の下の帯。
static func auto_confirm_hint() -> String:
	return Text.t("battle.hint.auto_confirm")


static func auto_running_hint() -> String:
	return Text.t("battle.hint.auto_running")


# ---- 駒のそばのメニュー ----


## 駒のそばのメニューに出す項目（[名前, 文字, 押せるか] の列）。いま選べるものだけを並べる。
## スキルは、持っている駒なら、使えない間も理由を添えて出す（押せない）。行動できない駒では空。
## can_attack・can_heal・can_skill は、選んでいる駒がいまの位置から攻撃・回復・スキルの対象を選べるか。
## warp_to は、いまのポータルから転移できる行き先（できなければ NO_CELL）。転移は、出ていればいちばん上に置く
## （ポータルへ動いた直後に、いちばん選びそうなもの）。
static func menu_items(
	battle: Battle, unit: Unit, mode: Mode, can_attack: bool, can_heal: bool, can_skill: bool, warp_to := Vector2i(-1, -1)
) -> Array:
	var items: Array = []
	if unit == null or battle.is_over() or not battle.can_act(unit):
		return items
	if mode != Mode.NONE:
		return [[MENU_BACK, Text.t("battle.menu.back"), true]]
	if warp_to != Vector2i(-1, -1):
		items.append([MENU_WARP, Text.t("battle.menu.warp"), true])
	if can_attack:
		items.append([MENU_ATTACK, Text.t("battle.menu.attack"), true])
	if can_heal:
		items.append([MENU_HEAL, Text.t("battle.menu.heal"), true])
	if Skills.of(unit) != null:
		items.append([MENU_SKILL, skill_button_text(unit, can_skill), can_skill])
	items.append([MENU_WAIT, Text.t("battle.menu.wait"), true])
	if battle.options(unit.id).can_undo:
		items.append([MENU_UNDO, Text.t("battle.menu.undo"), true])
	return items


## メニューの項目の説明（押すと何が起きるか）。マウスを乗せている間、左下の枠に出す。
static func menu_note(id: StringName, unit: Unit) -> String:
	match id:
		MENU_ATTACK:
			return Text.t("battle.menu.attack.note")
		MENU_HEAL:
			return Text.t("battle.menu.heal.note", {"amount": unit.power()})
		MENU_SKILL:
			var skill := Skills.of(unit)
			var key := "battle.menu.skill.note_ends" if skill.ends_action() else "battle.menu.skill.note_then_attack"
			return Text.t(key, {"skill": Names.skill(skill), "summary": Names.skill_summary(skill), "state": BattleHud.skill_state_text(unit)})
		MENU_WAIT:
			return Text.t("battle.menu.wait.note")
		MENU_UNDO:
			return Text.t("battle.menu.undo.note")
		MENU_BACK:
			return Text.t("battle.menu.back.note")
		MENU_WARP:
			return Text.t("battle.menu.warp.note")
	return ""


## メニューのスキルの項目の文字。使えるならスキルの名前（回数に上限があれば残りも）、使えないなら理由。
## can_use は、いまスキルの対象を選べるか。
static func skill_button_text(unit: Unit, can_use: bool) -> String:
	var skill := Skills.of(unit)
	if skill == null:
		return ""
	if unit.skill_cooldown > 0:
		return Text.t("battle.menu.skill.cooldown", {"turns": unit.skill_cooldown})
	var uses := Skills.uses_left(unit)
	if uses == 0:
		return Text.t("battle.menu.skill.used_up")
	if not can_use:
		return Text.t("battle.menu.skill.unusable")
	if uses > 0:
		return Text.t("battle.menu.skill.uses_left", {"skill": Names.skill(skill), "uses": uses})
	return Names.skill(skill)


## 必殺技のボタンの文字（side のプレイヤーの必殺技）。confirming は、使うかを確かめている途中か。
static func ult_button_text(battle: Battle, side: Unit.Side, confirming: bool) -> String:
	var ult := Ults.of(battle, side)
	if ult == null:
		return Text.t("battle.ult_button.none")
	if confirming:
		return Text.t("battle.ult_button.confirm")  # 何の必殺技かと、取り消せないことは、ボタンの上の説明と下の帯に出す
	if Ults.is_ready(battle, side):
		return Text.t("battle.ult_button.ready", {"ult": Names.ult(ult)})
	return Text.t("battle.ult_button.charging", {"ult": Names.ult(ult), "percent": Ults.percent(battle, side)})


# ---- 駒とマス ----


## 駒の行動の状態（いまの番の陣営の駒だけ）と、いるマスの地形（平地でなければ）。左下の枠に出す。
static func unit_state(battle: Battle, unit: Unit) -> String:
	var state := ""
	if unit.side == battle.phase:
		state = Text.t("battle.unit.acted") if unit.acted else Text.t("battle.unit.unacted")
		if unit.has_moved:
			state = Text.t("battle.unit.moving_cruised") if unit.cruised else Text.t("battle.unit.moving")
		if unit.move_locked:
			state = Text.t("battle.unit.moving_skilled")
	# 森にいれば、受けるダメージが減る。
	var terrain := battle.board.terrain_at(unit.cell)
	if terrain != Terrain.Type.NORMAL:
		state += ("\n" if state != "" else "") + Text.t("battle.unit.on_cell", {"terrain": _with_note(_terrain_item(terrain))})
	return state


## マスの見出し（位置と地形の名前）。
static func cell_title(battle: Battle, cell: Vector2i) -> String:
	return Text.t("battle.cell.title", {"x": cell.x, "y": cell.y, "terrain": _terrain_item(battle.board.terrain_at(cell))[0]})


## マスの説明を、左下の枠に出す形にしたもの。項目の名前の行と、説明を「。」ごとに字下げした行に分ける。
static func cell_body(battle: Battle, cell: Vector2i) -> String:
	var lines: Array[String] = []
	for item: Array in cell_items(battle, cell):
		lines.append(item[0])
		for part in (item[1] as String).split(Text.t("common.sentence_end"), false):
			lines.append(Text.t("battle.cell.indent", {"text": part.strip_edges()}))
	return "\n".join(lines)


## 地形の [名前, 説明（無ければ空）]。
static func _terrain_item(terrain: Terrain.Type) -> Array:
	match terrain:
		Terrain.Type.OBSTACLE:
			return [Text.t("battle.cell.obstacle"), Text.t("battle.cell.obstacle.note")]
		Terrain.Type.FOREST:
			return [Text.t("battle.cell.forest"), Text.t("battle.cell.forest.note")]
		Terrain.Type.FONT:
			return [Text.t("battle.cell.font"), ""]
	return [Text.t("battle.cell.plain"), ""]


## 項目を 1 つの文にしたもの（「森（移動 2・受けるダメージ 0.8 倍）」）。
static func _with_note(item: Array) -> String:
	return item[0] if item[1] == "" else item[0] + Text.paren(item[1])


## マスの説明の項目（[名前, 説明（無ければ空）] の列）: 地形の効果、本陣、盤の上の効果、環境オブジェクト。何も無ければ「特別なものは無い」。
static func cell_items(battle: Battle, cell: Vector2i) -> Array[Array]:
	var items: Array[Array] = []
	var terrain := _terrain_item(battle.board.terrain_at(cell))
	if terrain[1] != "":
		items.append([terrain[1], ""])
	var hq_owner := battle.board.hq_owner(cell)
	if hq_owner >= 0:
		items.append([Text.t("battle.cell.hq", {"side": Names.side(hq_owner)}), ""])
	for effect in battle.board.field_effects_at(cell):
		items.append(field_effect_item(effect))
	match battle.board.object_at(cell):
		MapObject.Type.BARREL:
			items.append([Text.t("battle.cell.barrel"), Text.t("battle.cell.barrel.note", {"damage": MapObject.BLAST_DAMAGE})])
		MapObject.Type.SPRING:
			items.append([Text.t("battle.cell.spring"), Text.t("battle.cell.spring.note", {"heal": MapObject.SPRING_HEAL})])
		MapObject.Type.PORTAL:
			var exit := battle.board.portal_exit(cell)
			var key := "battle.cell.portal.blocked_note" if battle.portal_exit(cell) == Board.NO_CELL else "battle.cell.portal.note"
			items.append([Text.t("battle.cell.portal", {"x": exit.x, "y": exit.y}), Text.t(key)])
	if items.is_empty():
		items.append([nothing_special(), ""])
	return items


## 盤の上の効果の [名前, 説明]。
static func field_effect_item(effect: FieldEffect) -> Array:
	var args := {"side": Names.side(effect.side), "durability": effect.durability, "turns": effect.turns_left, "heal": FieldEffects.SANCTUARY_HEAL}
	match effect.type:
		FieldEffect.Type.BARRICADE:
			return [Names.field_effect(effect.type), Text.t("battle.cell.barricade.note", args)]
		FieldEffect.Type.SMOKE:
			return [Names.field_effect(effect.type), Text.t("battle.cell.smoke.note", args)]
	return [Names.field_effect(effect.type), Text.t("battle.cell.sanctuary.note", args)]


## マスの説明（行ごと）: 項目を 1 つの文にしたもの。
static func cell_notes(battle: Battle, cell: Vector2i) -> Array[String]:
	var notes: Array[String] = []
	for item: Array in cell_items(battle, cell):
		notes.append(_with_note(item))
	return notes


## マスの説明を 1 行にしたもの（下の帯。マウスの下のマス）。
static func cell_line(battle: Battle, cell: Vector2i) -> String:
	var notes := cell_notes(battle, cell)
	var title := cell_title(battle, cell)
	return title if notes[0] == nothing_special() else Text.t("battle.cell.line", {"title": title, "notes": Text.t("battle.cell.separator").join(notes)})
