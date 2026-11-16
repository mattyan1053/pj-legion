extends RefCounted
## 対戦の画面の文: 下の帯の説明、駒のそばのメニューの項目と説明、マスの説明、駒の行動の状態、必殺技のボタン。
## ノードに依存しない（テストから呼べる）。対戦の場面（battle_screen.gd）が、いまの盤と操作の状態を渡して作らせ、画面に出す。

const BattleHud := preload("res://game/battle_hud.gd")
const BattleUiState := preload("res://game/battle_ui_state.gd")
const Names := preload("res://game/names.gd")
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
const NOTHING_SPECIAL := "特別なものは無い"


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
		return "決着"
	if cpu_turn:
		return "相手（CPU）の番"
	if battle.evolving_unit() != null:
		return "進化先を選ぶ（上のボタン）"
	if confirming_ult:
		var ult := Ults.of(battle, battle.phase)  # 確かめるのは、人の番だけ
		var named := "「%s」" % ult.display_name() if ult != null else ""
		return "もう一度押すと必殺技%sを使う（取り消せない）。右クリックか、盤面のクリックでやめる" % named
	if confirming_unacted > 0 and inspected == null:
		return "まだ行動していない駒が %d 体（足元が光っている）。もう一度押すとターン終了。右クリックでやめる" % confirming_unacted
	if inspected != null:
		var ranges := "白: 動ける範囲" if inspected.side == battle.phase else "白: 動ける　赤: 次の番に攻撃が届く"
		if pinned > 0:
			ranges += "　橙の枠: 表示したままの範囲"
		var back := "選んでいる駒へ戻る" if unit != null else "見るのをやめる"
		return "%s を見ている（%s）\n右クリックで%s" % [inspected.display_name(), ranges, back]
	if unit == null and pinned > 0:
		return "駒をクリックして選ぶ。橙の枠: 表示したままの相手の範囲（右クリックで全部消す）"
	if unit == null:
		return "駒をクリックして選ぶ。相手の駒をクリックすると、動ける範囲と攻撃の届く範囲が見える"
	if mode == Mode.SKILL and self_skill:
		return "%s: この駒（紫のマス）をクリックで使う。右クリックでやめる" % Skills.of(unit).display_name()
	if mode == Mode.SKILL:
		var after := "使うと行動を終える" if Skills.of(unit).ends_action() else "使ったあと、続けて攻撃できる"
		return "%s: 紫のマスをクリックで使う（%s）。右クリックでやめる" % [Skills.of(unit).display_name(), after]
	if mode == Mode.ATTACK:
		return "攻撃: 赤いマスの相手をクリック。右クリックでやめる"
	if mode == Mode.HEAL:
		return "回復: 緑のマスの味方をクリック。右クリックでやめる"
	if not battle.can_act(unit):
		if unit.side != battle.phase:
			return "相手の駒。白: 動ける範囲　赤: 次の番に攻撃が届く範囲"
		return "この駒は行動を終えている（白: 動ける範囲）"
	if unit.move_locked:
		return "スキルを使った。駒のそばのメニューから、攻撃か待機を選ぶ（取り消せない）"
	if unit.has_moved and can_warp:
		return "ポータルの上。駒のそばのメニューの「転移」で、同じ色に塗ったマスへ移れる。右クリックで移動を取り消す"
	if unit.has_moved:
		if unit.cruised:
			return "巡航で動いたので、攻撃はできない。駒のそばのメニューから、待機か取り消しを選ぶ"
		return "駒のそばのメニューから行動を選ぶ。右クリックで移動を取り消す"
	if UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
		return "青: 移動　黄: 巡航（回復できない）　緑: 回復できる味方\nマスをクリックで移動。行動は駒のそばのメニューから"
	return "青: 移動　黄: 巡航（攻撃できない）　赤: 攻撃できる相手\nマスをクリックで移動。行動は駒のそばのメニューから"


## 自分の番の「おまかせ」を確かめている間と、任せている間の下の帯。
const AUTO_CONFIRM_HINT := "おまかせ: もう一度押すと、残りの駒を CPU が動かしてターンを終える（取り消せない）。右クリックでやめる"
const AUTO_RUNNING_HINT := "おまかせ: このターンは CPU が動かしている"


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
		return [[MENU_BACK, "やめる", true]]
	if warp_to != Vector2i(-1, -1):
		items.append([MENU_WARP, "転移", true])
	if can_attack:
		items.append([MENU_ATTACK, "攻撃", true])
	if can_heal:
		items.append([MENU_HEAL, "回復", true])
	if Skills.of(unit) != null:
		items.append([MENU_SKILL, skill_button_text(unit, can_skill), can_skill])
	items.append([MENU_WAIT, "待機", true])
	if battle.options(unit.id).can_undo:
		items.append([MENU_UNDO, "移動を取り消す", true])
	return items


## メニューの項目の説明（押すと何が起きるか）。マウスを乗せている間、左下の枠に出す。
static func menu_note(id: StringName, unit: Unit) -> String:
	match id:
		MENU_ATTACK:
			return "攻撃: 赤いマスの相手（樽・盾も）を選んで攻撃する。攻撃すると、この駒の行動は終わる。相手にマウスを乗せると、見込みが出る"
		MENU_HEAL:
			return "回復: 緑のマスの味方を選んで回復する（回復量 %d）。回復すると、この駒の行動は終わる" % unit.power()
		MENU_SKILL:
			var skill := Skills.of(unit)
			var after := "使うと、この駒の行動は終わる" if skill.ends_action() else "使ったあと、続けて攻撃できる（移動は取り消せなくなる）"
			return "%s: %s\n%s。%s" % [skill.display_name(), skill.summary(), after, BattleHud.skill_state_text(unit)]
		MENU_WAIT:
			return "待機: 何もせずに、この駒の行動を終える"
		MENU_UNDO:
			return "移動を取り消す: 動く前のマスへ戻して、選び直す"
		MENU_BACK:
			return "やめる: 対象を選ぶのをやめて、メニューへ戻る"
		MENU_WARP:
			return "転移: 対のポータル（同じ色の塗り）へ移る。移動力は使わない。転移のあとも攻撃・待機を選べる"
	return ""


## メニューのスキルの項目の文字。使えるならスキルの名前（回数に上限があれば残りも）、使えないなら理由。
## can_use は、いまスキルの対象を選べるか。
static func skill_button_text(unit: Unit, can_use: bool) -> String:
	var skill := Skills.of(unit)
	if skill == null:
		return ""
	if unit.skill_cooldown > 0:
		return "スキル（あと %d ターン）" % unit.skill_cooldown
	var uses := Skills.uses_left(unit)
	if uses == 0:
		return "スキル（使い切った）"
	if not can_use:
		return "スキル（いまは使えない）"
	if uses > 0:
		return "%s（あと %d 回）" % [skill.display_name(), uses]
	return skill.display_name()


## 必殺技のボタンの文字（side のプレイヤーの必殺技）。confirming は、使うかを確かめている途中か。
static func ult_button_text(battle: Battle, side: Unit.Side, confirming: bool) -> String:
	var ult := Ults.of(battle, side)
	if ult == null:
		return "必殺技（なし）"
	if confirming:
		return "もう一度押して発動"  # 何の必殺技かと、取り消せないことは、ボタンの上の説明と下の帯に出す
	if Ults.is_ready(battle, side):
		return "必殺技: %s（使える）" % ult.display_name()
	return "必殺技: %s（%d%%）" % [ult.display_name(), Ults.percent(battle, side)]


# ---- 駒とマス ----


## 駒の行動の状態（いまの番の陣営の駒だけ）と、いるマスの地形（平地でなければ）。左下の枠に出す。
static func unit_state(battle: Battle, unit: Unit) -> String:
	var state := ""
	if unit.side == battle.phase:
		state = "行動済み" if unit.acted else "未行動"
		if unit.has_moved:
			state = "行動の途中（巡航で移動した）" if unit.cruised else "行動の途中（移動した）"
		if unit.move_locked:
			state = "行動の途中（スキルを使った）"
	# 森にいれば、受けるダメージが減る。
	var terrain := battle.board.terrain_at(unit.cell)
	if terrain != Terrain.Type.NORMAL:
		state += ("\n" if state != "" else "") + "いるマス: " + BattleHud.TERRAIN_NAMES[terrain]
	return state


## マスの見出し（位置と地形の名前）。
static func cell_title(battle: Battle, cell: Vector2i) -> String:
	var terrain: String = BattleHud.TERRAIN_NAMES[battle.board.terrain_at(cell)]
	return "マス (%d, %d)　%s" % [cell.x, cell.y, terrain.get_slice("（", 0)]


## マスの説明を、左下の枠に出す形にしたもの。「名前（説明。説明）」を、名前の行と、字下げした説明の行に分ける。
static func cell_body(battle: Battle, cell: Vector2i) -> String:
	var lines: Array[String] = []
	for note in cell_notes(battle, cell):
		if not note.ends_with("）") or not note.contains("（"):
			lines.append(note)
			continue
		lines.append(note.get_slice("（", 0))
		for part in note.substr(note.find("（") + 1).trim_suffix("）").split("。", false):
			lines.append("　" + part.strip_edges())
	return "\n".join(lines)


## ポータルのマスの説明。行き先の座標のあとに、括弧で添える（左下の枠では、括弧の中を「。」ごとの行にする）。
const PORTAL_NOTE := "止まると、駒のそばのメニューの「転移」で対のポータルへ移れる。移動力は使わない"
const PORTAL_BLOCKED := "行き先に駒がいて、いまは使えない"


## マスの説明（行ごと）: 地形の効果、本陣、盤の上の効果、環境オブジェクト。
static func cell_notes(battle: Battle, cell: Vector2i) -> Array[String]:
	var notes: Array[String] = []
	var terrain: String = BattleHud.TERRAIN_NAMES[battle.board.terrain_at(cell)]
	if terrain.contains("（"):
		notes.append(terrain.get_slice("（", 1).trim_suffix("）"))
	var hq_owner := battle.board.hq_owner(cell)
	if hq_owner >= 0:
		notes.append("%s の本陣" % Names.SIDE_NAMES[hq_owner])
	for effect in battle.board.field_effects_at(cell):
		notes.append(BattleHud.field_effect_text(effect))
	var type := battle.board.object_at(cell)
	if type != MapObject.Type.NONE:
		var text: String = BattleHud.OBJECT_NAMES[type]
		if type == MapObject.Type.PORTAL:
			var exit := battle.board.portal_exit(cell)
			text += " → (%d, %d)（%s" % [exit.x, exit.y, PORTAL_NOTE]
			if battle.portal_exit(cell) == Board.NO_CELL:
				text += "。" + PORTAL_BLOCKED
			text += "）"
		notes.append(text)
	if notes.is_empty():
		notes.append(NOTHING_SPECIAL)
	return notes


## マスの説明を 1 行にしたもの（下の帯。マウスの下のマス）。
static func cell_line(battle: Battle, cell: Vector2i) -> String:
	var notes := cell_notes(battle, cell)
	var title := cell_title(battle, cell)
	return title if notes[0] == NOTHING_SPECIAL else "%s　%s" % [title, "　".join(notes)]
