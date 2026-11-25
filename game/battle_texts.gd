extends RefCounted
## 対戦の画面の文: 下の帯の案内（句と印の並び）、駒のそばのメニューの項目と説明、マスの説明、駒の行動の状態、必殺技のボタン。
## ノードに依存しない（テストから呼べる）。対戦の場面（battle_screen.gd）が、いまの盤と操作の状態を渡して作らせ、画面に出す。

const BattleHud := preload("res://game/battle_hud.gd")
const BattleUiState := preload("res://game/battle_ui_state.gd")
const KeyMarks := preload("res://game/key_marks.gd")
const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")
const WinText := preload("res://game/win_text.gd")
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


## 下の帯の案内: 短い句と、キーの印・色の印の並び（key_marks.gd の parts）。文で操作を教えない（docs/wording.md の決まり 1）。
## 分かりきった場面（駒を選ぶ前、相手の番、決着、台詞の途中、進化先を選ぶ間）は空。
## unit は選んでいる駒、inspected は見ている駒（どちらも無ければ null）。cpu_turn は CPU の番（を進めている途中）か。
## confirming は、必殺技かおまかせを確かめている途中か。confirming_unacted は、ターン終了を確かめている途中なら、
## まだ行動していない駒の数（確かめていなければ 0）。pinned は、範囲を表示したままにしている駒の数。
## 色の印の色は名前（&"move" など）で返す。画面の側が、盤に塗る色に直す。
static func guide(
	battle: Battle, unit: Unit, inspected: Unit, mode: Mode, cpu_turn: bool, confirming: bool,
	confirming_unacted := 0, pinned := 0
) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	if battle.is_over() or cpu_turn or battle.evolving_unit() != null:
		return parts
	if confirming:
		return [_right_click("battle.guide.cancel")]
	if confirming_unacted > 0 and inspected == null:
		return [KeyMarks.phrase(Text.t("battle.guide.unacted", {"count": confirming_unacted})), _right_click("battle.guide.cancel")]
	if inspected != null:
		parts = _seen_ranges(battle, inspected, pinned)
		parts.append(_right_click("battle.guide.back"))
		return parts
	if unit == null:
		if pinned > 0:
			return [_mark(&"pin", "battle.guide.pinned", true), _right_click("battle.guide.unpin")]
		return parts
	if mode != Mode.NONE:
		return [KeyMarks.phrase(Text.t("battle.guide.target")), _right_click("battle.guide.cancel")]
	if not battle.can_act(unit):
		return _seen_ranges(battle, unit, pinned)
	if unit.move_locked:
		return parts
	if unit.has_moved:
		if unit.can_keep_moving:
			if not unit.cruised:
				parts.append(_mark(&"move", "battle.guide.move"))
			parts.append(_mark(&"cruise", "battle.guide.cruise"))
		parts.append(_right_click("battle.guide.undo"))
		return parts
	parts = [_mark(&"move", "battle.guide.move"), _mark(&"cruise", "battle.guide.cruise")]
	if UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
		parts.append(_mark(&"heal", "battle.guide.heal"))
	parts.append(_mark(&"attack", "battle.guide.attack"))
	return parts


## 見ている駒の範囲の色の印: 動ける範囲と、相手の駒なら次の番に攻撃が届く範囲、留めた範囲があればその枠。
static func _seen_ranges(battle: Battle, seen: Unit, pinned: int) -> Array[Dictionary]:
	var parts: Array[Dictionary] = [_mark(&"reach", "battle.guide.move")]
	if seen.side != battle.phase:
		parts.append(_mark(&"threat", "battle.guide.attack"))
	if pinned > 0:
		parts.append(_mark(&"pin", "battle.guide.pinned", true))
	return parts


static func _right_click(word: String) -> Dictionary:
	return KeyMarks.key(Text.t("common.key.right_click"), Text.t(word))


static func _mark(color: StringName, word: String, framed := false) -> Dictionary:
	return KeyMarks.swatch(color, Text.t(word), framed)


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
## 名前で分かる項目（待機、移動を取り消す、キャンセル）は空。
## battle があれば、スキルの状態は、いま使えるか（Skills.can_use）まで見る。
static func menu_note(id: StringName, unit: Unit, battle: Battle = null) -> String:
	match id:
		MENU_ATTACK:
			return Text.t("battle.menu.attack.note")
		MENU_HEAL:
			return Text.t("battle.menu.heal.note", {"amount": unit.power()})
		MENU_SKILL:
			var skill := Skills.of(unit)
			var key := "battle.menu.skill.note_ends" if skill.ends_action() else "battle.menu.skill.note_then_attack"
			return Text.t(key, {"skill": Names.skill(skill), "summary": Names.skill_summary(skill), "state": BattleHud.skill_state_text(unit, battle)})
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
		state += ("\n" if state != "" else "") + Text.t("battle.unit.on_cell", {"terrain": _with_note(_terrain_item(terrain, battle))})
	return state


## マスの見出し（位置と地形の名前）。
static func cell_title(battle: Battle, cell: Vector2i) -> String:
	return Text.t("battle.cell.title", {"x": cell.x, "y": cell.y, "terrain": _terrain_item(battle.board.terrain_at(cell), battle)[0]})


## マスの説明を、左下の枠に出す形にしたもの。項目の名前の行と、説明を「。」ごとに字下げした行に分ける。
static func cell_body(battle: Battle, cell: Vector2i) -> String:
	var lines: Array[String] = []
	for item: Array in cell_items(battle, cell):
		lines.append(item[0])
		for part in (item[1] as String).split(Text.t("common.sentence_end"), false):
			lines.append(Text.t("battle.cell.indent", {"text": part.strip_edges()}))
	return "\n".join(lines)


## 地形の [名前, 説明（無ければ空）, 下の帯などの 1 行に入れる短い説明（長い説明だけ）]。森の受けるダメージは、対戦の札（深い茂み）を含めた割合（Seam.forest_rate_percent）。
static func _terrain_item(terrain: Terrain.Type, battle: Battle) -> Array:
	match terrain:
		Terrain.Type.OBSTACLE:
			return [Text.t("battle.cell.obstacle"), Text.t("battle.cell.obstacle.note")]
		Terrain.Type.FOREST:
			return [Text.t("battle.cell.forest"), Text.t("battle.cell.forest.note", {"rate": "%.1f" % (Seam.forest_rate_percent(battle) / 100.0)})]
		Terrain.Type.FONT:
			# 中立の敵が湧く（縫い目の様子の「骨の眠り」の間は、湧き直さない）。
			var font_note := "battle.cell.font.hushed_note" if Seam.respawn_percent(battle) == 0 else "battle.cell.font.note"
			return [Text.t("battle.cell.font"), Text.t(font_note), Text.t("battle.cell.font.short")]
	return [Text.t("battle.cell.plain"), ""]


## 項目を 1 つの文にしたもの（「森（移動 2・受けるダメージ 0.8 倍）」）。下の帯の 1 行に入れるので、短い説明（3 つ目）があればそちらを使う。
static func _with_note(item: Array) -> String:
	var note: String = item[2] if item.size() > 2 else item[1]
	return item[0] if note == "" else item[0] + Text.paren(note)


## マスの説明の項目（[名前, 説明（無ければ空）, 下の帯の 1 行に入れる短い説明（長い説明だけ）] の列）: 地形の効果、本陣、盤の上の効果、環境オブジェクト。何も無ければ「特別なものは無い」。
static func cell_items(battle: Battle, cell: Vector2i) -> Array[Array]:
	var items: Array[Array] = []
	var terrain := _terrain_item(battle.board.terrain_at(cell), battle)
	if terrain[1] != "":
		items.append([terrain[1], ""])
	var hq_owner := battle.board.hq_owner(cell)
	if hq_owner >= 0:
		# 本陣の占拠が相手の勝ち方にあれば、何ターンで決まるかを添える。
		var hq_note := ""
		if battle.wins_by((1 - hq_owner) as Unit.Side, GameWonEvent.Reason.HQ_CAPTURED):
			hq_note = Text.t("battle.cell.hq.note", {"turns": Battle.CAPTURE_TURNS_TO_WIN})
		items.append([Text.t("battle.cell.hq", {"side": Names.side(hq_owner)}), hq_note])
	for effect in battle.board.field_effects_at(cell):
		items.append(field_effect_item(effect))
	match battle.board.object_at(cell):
		MapObject.Type.BARREL:
			items.append([Text.t("battle.cell.barrel"), Text.t("battle.cell.barrel.note", {"damage": MapObject.BLAST_DAMAGE})])
		MapObject.Type.BATTERY:
			items.append([Text.t("battle.cell.battery"), Text.t("battle.cell.battery.note", {"range": MapObject.BATTERY_RANGE})])
		MapObject.Type.STRONGHOLD:
			items.append([Text.t("battle.cell.stronghold"), Text.t("battle.cell.stronghold.note", {"needed": Stronghold.HOLDS_TO_WIN}),
				Text.t("battle.cell.stronghold.short")])
		MapObject.Type.SPRING:
			items.append([Text.t("battle.cell.spring"), Text.t("battle.cell.spring.note", {"heal": MapObject.SPRING_HEAL})])
		MapObject.Type.PORTAL:
			var exit := battle.board.portal_exit(cell)
			var key := "battle.cell.portal.blocked_note" if battle.portal_exit(cell) == Board.NO_CELL else "battle.cell.portal.note"
			items.append([Text.t("battle.cell.portal", {"x": exit.x, "y": exit.y}), Text.t(key)])
	if items.is_empty():
		items.append([nothing_special(), ""])
	return items


## 対戦の始めの「対戦ルール」の札（docs/battle-view.md の「対戦ルール」）。side（人が動かす側）から見た、いま効いている勝利条件と、縫い目の様子。
## 札は [種類（&"goal" か &"sign"）, 印の値（GameWonEvent.Reason か Seam.Sign）, 名前, 1 行の説明] の列。勝利条件が先、縫い目の様子があとで、それぞれの並びの順。
## 相手が守り切る戦い（side が攻める側）は、勝利条件に「時間の限り」の札を足す（守り切るの印）。
static func rule_cards(battle: Battle, side: Unit.Side) -> Array[Array]:
	var cards := goal_cards(battle.win_conditions, battle.hold_turns, side)
	for sign in battle.signs:
		cards.append([&"sign", sign, Names.sign_name(sign), Names.sign_summary(sign)])
	return cards


## 勝利条件の札（[&"goal", 勝ち方, 短い名前, 1 行]）だけ。conditions はプレイヤーごとの勝ちの条件の列、hold_turns は守り切るのターン数。
## 「対戦ルール」と出撃準備の勝利条件の欄が使う（同じ札）。並びは WinText.ORDER。相手が守り切る戦いは「時間の限り」を足す。
static func goal_cards(conditions: Array, hold_turns: int, side: Unit.Side) -> Array[Array]:
	var cards: Array[Array] = []
	var args := {"turns": hold_turns, "capture": Battle.CAPTURE_TURNS_TO_WIN, "holds": Stronghold.HOLDS_TO_WIN}
	for reason: GameWonEvent.Reason in WinText.ORDER:
		if conditions[side].has(reason):
			var word := String(GameWonEvent.Reason.find_key(reason)).to_lower()
			cards.append([&"goal", reason, Text.t("battle.goal.name." + word), Text.t("battle.goal.win." + word, args)])
	var foe := (1 - side) as Unit.Side
	if conditions[foe].has(GameWonEvent.Reason.TURNS_HELD) and not conditions[side].has(GameWonEvent.Reason.TURNS_HELD):
		cards.append([&"goal", GameWonEvent.Reason.TURNS_HELD, Text.t("battle.goal.name.deadline"), Text.t("battle.goal.deadline", args)])
	return cards


## 盤の上の効果の [名前, 説明]。
static func field_effect_item(effect: FieldEffect) -> Array:
	var args := {"side": Names.side(effect.side), "durability": effect.durability, "turns": effect.turns_left, "heal": FieldEffects.SANCTUARY_HEAL}
	match effect.type:
		FieldEffect.Type.BARRICADE:
			return [Names.field_effect(effect.type), Text.t("battle.cell.barricade.note", args)]
		FieldEffect.Type.SMOKE:
			return [Names.field_effect(effect.type), Text.t("battle.cell.smoke.note", args)]
		FieldEffect.Type.KNOT:
			args["unit"] = Names.kind(UnitKind.Id.FRAY)
			return [Names.field_effect(effect.type), Text.t("battle.cell.knot.note", args)]
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
