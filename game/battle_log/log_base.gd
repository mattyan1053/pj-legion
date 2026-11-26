extends RefCounted
## 対戦のログ（game/battle_log.gd）の土台: 行（Entry）と控えた駒（Known）、状態の変数、駒と効果の呼び方、行の足し方。
## 継ぐ順: log_base.gd → log_moves.gd（動きと盤）→ log_fights.gd（戦い）→ game/battle_log.gd（読み方の表と、食わせる入口）。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")

const NO_CELL := Vector2i(-1, -1)
const WIN_TEXTS := {
	GameWonEvent.Reason.KING_DEFEATED: "battle.log.won.king_defeated",
	GameWonEvent.Reason.HQ_CAPTURED: "battle.log.won.hq_captured",
	GameWonEvent.Reason.TURNS_HELD: "battle.log.won.turns_held",
	GameWonEvent.Reason.ROUTED: "battle.log.won.routed",
	GameWonEvent.Reason.BOSS_SLAIN: "battle.log.won.boss_slain",
	GameWonEvent.Reason.STRONGHOLD_HELD: "battle.log.won.stronghold_held",
}
const DRAW_TEXTS := {
	GameDrawnEvent.Reason.BOTH_KINGS_DEFEATED: "battle.log.drawn.both_kings_defeated",
}


## ログの 1 行。header が真なら、フェーズの区切り（「ターン 3　プレイヤー1（青）の番」）。
## side は色を付ける陣営（行の主の陣営。決まらなければ -1）。details は、まとめた続きの行（スキルで当たった駒など）。
## cell はその出来事のあったマス（無ければ NO_CELL）、unit_ids は関わった駒。行を選んだとき、ここへカメラを寄せ、駒を示す。
class Entry:
	extends RefCounted
	var turn: int
	var phase: int
	var header := false
	var side := -1
	var text := ""
	var details: Array[String] = []
	var cell := NO_CELL
	var unit_ids: Array[int] = []

	func _init(turn_: int, phase_: int) -> void:
		turn = turn_
		phase = phase_

	## 画面に出す文（続きの行も含める）。
	func full_text() -> String:
		var lines: Array[String] = [text]
		for detail in details:
			lines.append(Text.t("battle.log.detail", {"text": detail}))
		return "\n".join(lines)


## 控えている駒 1 体（名前と、いまいるマス）。
class Known:
	extends RefCounted
	var kind: UnitKind.Id
	var side: Unit.Side
	var evolution := Evolution.Id.NONE
	var cell: Vector2i

	func _init(kind_: UnitKind.Id, side_: Unit.Side, cell_: Vector2i) -> void:
		kind = kind_
		side = side_
		cell = cell_


var entries: Array[Entry] = []
## 見出しに出す陣営の名前（プレイヤー番号ごと。中立は「中立」）。
var side_names: Array[String] = [
	Names.side(Unit.Side.PLAYER1), Names.side(Unit.Side.PLAYER2), Names.side(Unit.Side.NEUTRAL),
]

var _board: Board
var _turn := 1
var _phase := Unit.Side.PLAYER1
var _units: Dictionary[int, Known] = {}
## 前に take_changes() してから書き換えた、いちばん前の行の番号（画面は、そこから先を作り直す）。
var _changed_from := 0
## まとめ先の行（スキル・必殺技・樽の爆発）。続く効果（当たった駒、置いた効果、付いた状態）を、この行の続きに書く。
var _group: Entry = null
## まとめ先の行に書いた状態（Status.Type -> [続きの行の番号, 名前の列, ターン数]）。
var _group_statuses := {}
## まとめ先の行の主（スキルを使った駒。必殺技なら 0）。
var _group_user := 0
## 駒の番号 -> このフェーズの、いちばん最近の移動の行の控え（[行, 出発したマス, 巡航か, ポータルを通ったか]）。
var _moves := {}
## このフェーズに、移動のほかに何かした（攻撃・回復・スキル）駒。待機の行を出すかを決める。
var _did_something := {}
## 倒れたことを、もうダメージの行に書いた駒と、壊れたことを書いた盾。
var _noted_defeats := {}
var _noted_effects := {}
## 結び目から立ち直ったと書いた駒が、次の UnitSpawnedEvent で現れる（湧いた、と書かない）。
var _reforming := false
## 盤の上の効果の番号 -> [種類, 陣営, 中心のマス]（消えたときのイベントは陣営を持たない）。
var _effects := {}
## 直前の行が、湧いた駒の行なら、その種類（続けて湧いたぶんを 1 行にまとめる）。湧いたマスの控え。
var _spawn_kind := -1
var _spawn_cells: Array[Vector2i] = []
## 直前のイベントが移動の取り消しか（取り消しで戻った状態は、書かない）。
var _undoing := false


## 盤の上の効果の名前（「青の盾」。だれのものか分からなければ「盾」）。
func _effect_name(type: FieldEffect.Type, owner: int) -> String:
	if owner < 0:
		return Names.field_effect(type)
	return Text.t("battle.log.effect_owned", {"side": Names.side_word(owner as Unit.Side), "effect": Names.field_effect(type)})


## 駒の名前（「青のパラディン」。進化していれば進化先の名前。中立の駒には陣営を付けない）。知らない駒は「駒」。
func unit_name(unit_id: int) -> String:
	var known: Known = _units.get(unit_id)
	if known == null:
		return Text.t("battle.log.unknown_unit")
	var name := Names.kind(known.kind) if known.evolution == Evolution.Id.NONE else Names.evolution(known.evolution)
	return name if known.side == Unit.Side.NEUTRAL else Text.t("battle.log.unit", {"side": Names.side_word(known.side), "unit": name})


## 中ボスの呼び方（「左の中ボス」）。中ボスは左右（中央平原・迷宮回廊）か上下（双子結晶）に 1 体ずつ。番号 0 が左か上。
static func mid_boss_place(board: Board, boss_index: int) -> String:
	var cells := board.mid_boss_cells
	var stacked := cells.size() == 2 and absi(cells[0].y - cells[1].y) > absi(cells[0].x - cells[1].x)
	if boss_index == 0:
		return Text.t("battle.log.boss_place.top") if stacked else Text.t("battle.log.boss_place.left")
	return Text.t("battle.log.boss_place.bottom") if stacked else Text.t("battle.log.boss_place.right")


static func cell_text(cell: Vector2i) -> String:
	return Text.t("common.cell", {"x": cell.x, "y": cell.y})


## 対戦の途中の会話の台詞を 1 行に書く（battle_cues.gd。イベントではないので、画面が台詞を出すときに呼ぶ）。
func say(speaker: String, text: String, side: int) -> void:
	_group = null
	_line(Text.t("battle.log.say", {"speaker": speaker, "text": text}), side)


# ---- 行の足し方 ----


func _line(text: String, side: int, cell := NO_CELL, unit_ids: Array[int] = []) -> Entry:
	var entry := Entry.new(_turn, _phase)
	entry.text = text
	entry.side = side
	entry.cell = cell
	entry.unit_ids = unit_ids.duplicate()
	entries.append(entry)
	return entry


## まとめ先の行があれば、その続きに書く。無ければ 1 行にする。
func _detail(text: String, side: int, cell := NO_CELL, unit_ids: Array[int] = []) -> void:
	if _group == null:
		_line(text, side, cell, unit_ids)
		return
	_group.details.append(text)
	for unit_id in unit_ids:
		if not _group.unit_ids.has(unit_id):
			_group.unit_ids.append(unit_id)
	_touch(_group)


## 行を書き換えたことを覚える。
func _touch(entry: Entry) -> void:
	var index := entries.rfind(entry)
	if index >= 0:
		_changed_from = mini(_changed_from, index)


func _begin_group(entry: Entry, user_id := 0) -> void:
	_group = entry
	_group_user = user_id
	_group_statuses = {}


func _side_of(unit_id: int) -> int:
	var known: Known = _units.get(unit_id)
	return known.side if known != null else -1


func _cell_of(unit_id: int) -> Vector2i:
	var known: Known = _units.get(unit_id)
	return known.cell if known != null else NO_CELL


func _set_cell(unit_id: int, cell: Vector2i) -> void:
	var known: Known = _units.get(unit_id)
	if known != null:
		known.cell = cell


## 「12 ダメージ、残り HP 8」。倒れたら「12 ダメージ、倒した」（攻撃した側から。by_attack が偽なら「倒れた」）。防がれたら「バリアで防がれた」（「防いだ」）。
func _damage_text(hit: UnitDamagedEvent, by_attack: bool) -> String:
	if hit.is_blocked():
		var blocked := "battle.log.damage.attack.blocked" if by_attack else "battle.log.damage.effect.blocked"
		return Text.t(blocked, {"status": Names.status(hit.blocked_by as Status.Type)})
	var text := ""
	if hit.hp <= 0:
		text = Text.t("battle.log.damage.attack.defeated" if by_attack else "battle.log.damage.effect.defeated", {"amount": hit.amount})
		_noted_defeats[hit.unit_id] = true
	else:
		text = Text.t("battle.log.damage.left", {"amount": hit.amount, "hp": hit.hp})
	var notes: Array[String] = []
	if hit.critical:
		notes.append(Text.t("battle.log.note.critical"))
	if hit.forest:
		notes.append(Text.t("battle.log.note.forest"))
	if hit.spores:
		notes.append(Text.t("battle.log.note.spores"))
	return text + Text.notes(notes)


# ---- 読み方（どの読み方からも使うもの） ----


## 行にしないイベント（readers() の表に、省く理由とともに載せる）。
func _skip(_event: BattleEvent) -> void:
	pass


func _start_phase(turn: int, side: Unit.Side) -> void:
	# 何も起きなかった中立のフェーズの見出しは、残さない（ほとんどのフェーズがそうで、区切りが増えるだけ）。
	if not entries.is_empty() and entries[-1].header and entries[-1].phase == Unit.Side.NEUTRAL:
		entries.remove_at(entries.size() - 1)
		_changed_from = mini(_changed_from, entries.size())
	_turn = turn
	_phase = side
	_group = null
	_moves.clear()
	_did_something.clear()
	var entry := _line(Text.t("battle.log.phase", {"turn": turn, "side": side_names[side]}), side)
	entry.header = true


