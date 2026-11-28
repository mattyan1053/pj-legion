extends RefCounted
## 盤のカットシーンの台本を読む（docs/battle-view.md の「盤のカットシーン」）。ノードに依存しない。
## 対戦を作らずに、盤と置く兵の列から再生の盤（replay_board.gd の of_pieces）を組み、台本の行を出来事（BattleEvent）に直す。
## 台詞・地の文の行は出来事にせず、そこで出来事の列を切る（steps）。見せる側（cut_stage.gd と会話の場面）は、
## 出来事の塊を再生し、文を読ませ、また再生する、を交互に回す（同時に 2 つは進めない）。
##
## 台本の行（座標は「x,y」。左上が 0,0。名前は兵の名前で、空白を含まない。ほかは英小文字）:
##   unit 名前 陣営 種類 x,y [形] 始めの盤に置く兵（台本の頭にだけ書ける）。陣営は ally・enemy・neutral、種類は駒の種類（king、sniper、skeleton など）
##                              形は無くてよい。将の姿（king のとき。unit_looks.gd の KING_LOOKS。skeleton_mage など）か、
##                              人物の形（PERSONS。種類はその人の種類）。書かなければ、名前が [cast] の話し手と同じならその人の形、ほかは種類の形
##   camera x,y | camera 名前    カメラを寄せる（台本の頭、unit のすぐあとに書けば、始めからそこを映す）
##   move 名前 x,y [x,y …]       歩く。書いたマスを順に通る（間のマスは、歩けるマスで近い道を埋める）
##   attack 名前 相手 [量]       攻撃する（量を書かなければ、その兵の攻撃力）。HP が 0 になれば倒れる
##   fall 名前                   倒れる
##   appear 名前 陣営 種類 x,y [形]  光とともに現れる（形は unit と同じ）
##   put 名前 陣営 種類 x,y [形]     光を出さずに置く（盤の端から歩いて入ってくる兵など）
##   leave 名前 [x,y …]          歩いてから（書かなければ、その場で）、倒れずに去る
##   face 名前 x,y | face 名前 相手   向きを変える
##   status 名前 状態            状態が付く（状態は、画面の名前（バリア）か英語の名前（barrier））
##   pace slow | normal | fast   このあと歩く速さ
##   wait 秒                     間を置く
## 頭が「>」「＞」「(」の行と、「話し手: 文」の行は、文の行（steps に {"row": 行} で入れる）。ほかの行は、書き間違い。

const ReplayBoard := preload("res://game/replay_board.gd")
const StoryFile := preload("res://game/story_file.gd")
const Names := preload("res://game/names.gd")
const CutScript := preload("res://game/cut_script.gd")
const UnitLooks := preload("res://game/unit_looks.gd")

const COMMANDS := ["unit", "camera", "move", "attack", "fall", "appear", "put", "leave", "face", "status", "pace", "wait"]
const SIDES := {"ally": Unit.Side.PLAYER1, "enemy": Unit.Side.PLAYER2, "neutral": Unit.Side.NEUTRAL}
## 歩く速さ（1 マスの秒数）。normal は対戦と同じ（battle_playback の STEP_TIME）。
const PACES := {"slow": 0.3, "normal": 0.16, "fast": 0.1}
## 待つ秒数の上限。
const WAIT_MAX := 5.0
## 台本で置ける兵の数の上限（始めの盤と、現れる・置く兵を合わせて）。
const UNITS_MAX := 24

## 盤（台本の兵は、ここの歩けるマスに置き、歩かせる）。
var board: Board
## 始めの盤（再生の盤）。読んだ台本は話が持ち回るので、再生には fresh_start の新しい盤を使う（これに食わせない）。
var start: ReplayBoard
## 始めの盤の兵（台本の行で動かす前の写し）。
var start_units: Array[Unit] = []
## 兵の名前 -> 駒の番号（台本に出てきた全部の兵。倒れた・去った兵も）。
var names := {}
## 駒の番号 -> 台本の行に書いた形（unit_looks.gd の KING_LOOKS か PERSONS の名前。書いた兵だけ）。
var looks := {}
## 台本を出来事と文に直したもの。{"events": Array[BattleEvent]}（出来事の塊）か {"row": 文の行 {"line", "text"}} の列（書いた順）。
var steps: Array[Dictionary] = []
## 始めにカメラを寄せるマス（台本の頭の camera。書かなければ、始めの兵の真ん中）。
var camera_cell := Vector2i.ZERO
## 書き損じ: [行の番号, 文] の列。
var problems: Array[Array] = []

## 読んでいる途中の、いま盤にいる兵（駒の番号 -> Unit）。
var _live: Dictionary[int, Unit] = {}
var _events: Array[BattleEvent] = []
var _next_id := 1
var _camera_written := false


## 盤 on_board の上の台本 rows（{"line": 行の番号, "text": 行}の列）を読む。
static func read(on_board: Board, rows: Array) -> CutScript:
	var result := CutScript.new()
	result.board = on_board
	result._read(rows)
	return result


## 行 text が文の行（台詞・地の文・括弧の指示）か。台本の行（先頭が COMMANDS の語）でなく、頭が「>」「＞」「(」か、「:」を含む行。
static func is_text_row(text: String) -> bool:
	var words := text.split(" ", false)
	if not words.is_empty() and COMMANDS.has(words[0]):
		return false
	return text.begins_with(">") or text.begins_with("＞") or text.begins_with("(") or text.contains(":") or text.contains("：")


## 始めの盤を、新しく組む（再生するたびに。再生は盤に出来事を食わせて書き換える）。
func fresh_start() -> ReplayBoard:
	return ReplayBoard.of_pieces(board, start_units)


## 出来事の数（全部の塊を合わせて）。
func event_count() -> int:
	var count := 0
	for step in steps:
		count += (step.get("events", []) as Array).size()
	return count


## 全部の出来事（書いた順）。
func all_events() -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for step in steps:
		result.append_array(step.get("events", []))
	return result


func _read(rows: Array) -> void:
	var units: Array[Unit] = []
	var heading := true  # 台本の頭（unit と、始めの camera を書ける所）
	for row: Dictionary in rows:
		var at: int = row["line"]
		var text: String = (row["text"] as String).strip_edges()
		if is_text_row(text):
			heading = false
			_flush()
			steps.append({"row": row})
			continue
		var words := text.split(" ", false)
		if words.is_empty():
			continue
		var command := words[0]
		var args := words.slice(1)
		if not COMMANDS.has(command):
			_problem(at, "知らない台本の行「%s」（書けるのは %s。台詞は「話し手: 文」、地の文は「> 文」）" % [text, ", ".join(COMMANDS)])
			continue
		if command == "unit":
			if not heading:
				_problem(at, "unit は台本の頭に書く（途中で出すなら appear か put）: %s" % text)
				continue
			var unit := _new_unit(at, args, text)
			if unit != null:
				units.append(unit.copy())  # 始めの盤は、台本の行で動かす前の写し
			continue
		if command == "camera" and heading and not _camera_written:
			var cell := _cell_or_unit(at, args, text, "camera x,y か camera 名前")
			if cell.x >= 0:
				camera_cell = cell
				_camera_written = true
			heading = false
			continue
		heading = false
		call("_read_" + command, at, args, text)
	_flush()
	start_units = units
	start = fresh_start()
	if not _camera_written:
		camera_cell = _middle(units)


func _flush() -> void:
	if not _events.is_empty():
		steps.append({"events": _events})
		_events = []


func _problem(at: int, text: String) -> void:
	problems.append([at, text])


## 兵の真ん中のマス（兵がいなければ、盤の真ん中）。
func _middle(units: Array[Unit]) -> Vector2i:
	if units.is_empty():
		return board.size / 2
	var sum := Vector2.ZERO
	for unit in units:
		sum += Vector2(unit.cell)
	return Vector2i((sum / units.size()).round())


## 「x,y」のマス。読めなければ (-1, -1)。
static func parse_cell(word: String) -> Vector2i:
	var parts := word.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


## 「名前 陣営 種類 x,y [形]」の兵を作って盤に入れる（unit・appear・put）。書き損じなら null。
func _new_unit(at: int, args: Array, text: String) -> Unit:
	if args.size() != 4 and args.size() != 5:
		_problem(at, "兵は「名前 陣営 種類 x,y [形]」: %s" % text)
		return null
	var name: String = args[0]
	if names.has(name) or SIDES.has(name) or COMMANDS.has(name):
		_problem(at, "兵の名前「%s」は、台本の中で 1 度だけ（陣営や行の名前とも重ねない）: %s" % [name, text])
		return null
	if not SIDES.has(args[1]):
		_problem(at, "陣営は %s: %s" % [", ".join(SIDES.keys()), text])
		return null
	var kind := StoryFile.enum_value(UnitKind.Id, args[2])
	if kind < 0:
		_problem(at, "知らない種類「%s」（書けるのは %s）" % [args[2], StoryFile.enum_words(UnitKind.Id)])
		return null
	var look := StringName(args[4]) if args.size() == 5 else &""
	if look != &"" and not _look_fits(look, kind as UnitKind.Id):
		_problem(at, "形「%s」は、この種類に付けられない（将（king）には %s、ほかは種類の合う人物の %s）: %s"
				% [look, ", ".join(UnitLooks.KING_LOOKS), ", ".join(UnitLooks.PERSONS.keys()), text])
		return null
	var cell := parse_cell(args[3])
	if not _free(cell, -1):
		_problem(at, "兵「%s」を %s に置けない（盤の外、歩けないマス、ほかの兵がいる）" % [name, args[3]])
		return null
	if _next_id > UNITS_MAX:
		_problem(at, "台本の兵は %d 体まで" % UNITS_MAX)
		return null
	var unit := Unit.new(_next_id, kind as UnitKind.Id, SIDES[args[1]], cell)
	_next_id += 1
	names[name] = unit.id
	_live[unit.id] = unit
	if look != &"":
		looks[unit.id] = look
	return unit


## 形 look を、種類 kind の兵に付けられるか（将の姿は将だけ、人物の形はその人の種類だけ）。
static func _look_fits(look: StringName, kind: UnitKind.Id) -> bool:
	if UnitLooks.KING_LOOKS.has(look):
		return kind == UnitKind.Id.KING
	return UnitLooks.PERSONS.has(look) and UnitLooks.PERSONS[look] == kind


## cell に兵を置けるか（盤の中の歩けるマスで、駒 except のほかに兵がいない）。
func _free(cell: Vector2i, except: int) -> bool:
	if not board.is_walkable(cell):
		return false
	for unit: Unit in _live.values():
		if unit.cell == cell and unit.id != except:
			return false
	return true


## いま盤にいる兵 name。いなければ書き損じにして null。
func _unit(at: int, name: String, text: String) -> Unit:
	if not names.has(name):
		_problem(at, "知らない兵「%s」（unit・appear・put で出してから使う）: %s" % [name, text])
		return null
	if not _live.has(names[name]):
		_problem(at, "兵「%s」は、もう盤にいない（倒れたか、去った）: %s" % [name, text])
		return null
	return _live[names[name]]


## 「x,y」か兵の名前のマス（args は 1 語）。書き損じなら (-1, -1)。
func _cell_or_unit(at: int, args: Array, text: String, form: String) -> Vector2i:
	if args.size() != 1:
		_problem(at, "「%s」と書く: %s" % [form, text])
		return Vector2i(-1, -1)
	var cell := parse_cell(args[0])
	if cell.x >= 0:
		if not board.in_bounds(cell):
			_problem(at, "%s は盤の外: %s" % [args[0], text])
			return Vector2i(-1, -1)
		return cell
	var unit := _unit(at, args[0], text)
	return unit.cell if unit != null else Vector2i(-1, -1)


## unit が、書いたマス waypoints を順に通って歩く道順（いまのマスから）。間は、歩けるマスで近い道を埋める
## （ほかの兵のいるマスは通らない）。行けなければ書き損じにして空。
func _path(at: int, unit: Unit, waypoints: Array, text: String) -> Array[Vector2i]:
	var path: Array[Vector2i] = [unit.cell]
	for word: String in waypoints:
		var goal := parse_cell(word)
		if goal.x < 0:
			_problem(at, "マスは「x,y」: %s" % word)
			return []
		if not _free(goal, unit.id):
			_problem(at, "%s へは行けない（盤の外、歩けないマス、ほかの兵がいる）: %s" % [word, text])
			return []
		var leg := _shortest(path.back(), goal, unit.id)
		if leg.is_empty():
			_problem(at, "%s から %s への道が無い: %s" % [path.back(), word, text])
			return []
		path.append_array(leg.slice(1))
	return path


## from から goal への、歩けるマスだけを通るいちばん近い道（from と goal を含む）。無ければ空。
func _shortest(from: Vector2i, goal: Vector2i, mover: int) -> Array[Vector2i]:
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			var path: Array[Vector2i] = [goal]
			while path[0] != from:
				path.push_front(came[path[0]])
			return path
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next := cell + step
			if not came.has(next) and _free(next, mover):
				came[next] = cell
				queue.append(next)
	return []


# ---- 台本の行ごと（_read_<行の名前>） ----


func _read_camera(at: int, args: Array, text: String) -> void:
	var cell := _cell_or_unit(at, args, text, "camera x,y か camera 名前")
	if cell.x >= 0:
		_events.append(CutCameraEvent.new(cell))


func _read_move(at: int, args: Array, text: String) -> void:
	if args.size() < 2:
		_problem(at, "「move 名前 x,y [x,y …]」と書く: %s" % text)
		return
	var unit := _unit(at, args[0], text)
	if unit == null:
		return
	var path := _path(at, unit, args.slice(1), text)
	if path.size() < 2:
		return
	unit.cell = path.back()
	_events.append(UnitMovedEvent.new(unit.id, path))


func _read_attack(at: int, args: Array, text: String) -> void:
	if args.size() < 2 or args.size() > 3 or (args.size() == 3 and not (args[2] as String).is_valid_int()):
		_problem(at, "「attack 名前 相手 [量]」と書く: %s" % text)
		return
	var attacker := _unit(at, args[0], text)
	var target := _unit(at, args[1], text)
	if attacker == null or target == null:
		return
	if attacker == target:
		_problem(at, "自分は攻撃できない: %s" % text)
		return
	var amount: int = int(args[2]) if args.size() == 3 else attacker.power()
	var hit := Hit.resolve(attacker, target, maxi(amount, 0), UnitDamagedEvent.Cause.ATTACK)
	var after := hit.apply()
	_events.append(AttackDamagedEvent.new(hit))
	_events.append_array(after)
	if target.hp <= 0:
		_fall(target)


func _read_fall(at: int, args: Array, text: String) -> void:
	if args.size() != 1:
		_problem(at, "「fall 名前」と書く: %s" % text)
		return
	var unit := _unit(at, args[0], text)
	if unit != null:
		_fall(unit)


func _fall(unit: Unit) -> void:
	_live.erase(unit.id)
	_events.append(UnitDefeatedEvent.new(unit))


func _read_appear(at: int, args: Array, text: String) -> void:
	var unit := _new_unit(at, args, text)
	if unit != null:
		_events.append(UnitSpawnedEvent.new(unit))


func _read_put(at: int, args: Array, text: String) -> void:
	var unit := _new_unit(at, args, text)
	if unit != null:
		_events.append(CutPlacedEvent.new(unit))


func _read_leave(at: int, args: Array, text: String) -> void:
	if args.is_empty():
		_problem(at, "「leave 名前 [x,y …]」と書く: %s" % text)
		return
	var unit := _unit(at, args[0], text)
	if unit == null:
		return
	var path: Array[Vector2i] = [unit.cell]
	if args.size() > 1:
		path = _path(at, unit, args.slice(1), text)
		if path.is_empty():
			return
	_live.erase(unit.id)
	_events.append(CutLeftEvent.new(unit.id, path))


func _read_face(at: int, args: Array, text: String) -> void:
	if args.size() != 2:
		_problem(at, "「face 名前 x,y」か「face 名前 相手」と書く: %s" % text)
		return
	var unit := _unit(at, args[0], text)
	var cell := _cell_or_unit(at, args.slice(1), text, "face 名前 x,y か face 名前 相手")
	if unit != null and cell.x >= 0:
		_events.append(CutTurnedEvent.new(unit.id, cell))


func _read_status(at: int, args: Array, text: String) -> void:
	if args.size() != 2:
		_problem(at, "「status 名前 状態」と書く: %s" % text)
		return
	var unit := _unit(at, args[0], text)
	var type := _status(args[1])
	if type < 0:
		var shown: PackedStringArray = []
		for each: int in Status.Type.values():
			shown.append(Names.status(each as Status.Type))
		_problem(at, "知らない状態「%s」（書けるのは %s。英語の名前でも）" % [args[1], ", ".join(shown)])
		return
	if unit != null:
		_events.append(Statuses.add(unit, type as Status.Type, 1))


## 状態の名前（画面の名前か、英語の名前）-> Status.Type。読めなければ -1。
static func _status(word: String) -> int:
	var by_word := StoryFile.enum_value(Status.Type, word)
	if by_word >= 0:
		return by_word
	for each: int in Status.Type.values():
		if Names.status(each as Status.Type) == word:
			return each
	return -1


func _read_pace(at: int, args: Array, text: String) -> void:
	if args.size() != 1 or not PACES.has(args[0]):
		_problem(at, "「pace %s」と書く: %s" % [" | ".join(PACES.keys()), text])
		return
	_events.append(CutPaceEvent.new(PACES[args[0]]))


func _read_wait(at: int, args: Array, text: String) -> void:
	if args.size() != 1 or not (args[0] as String).is_valid_float() or float(args[0]) <= 0.0 or float(args[0]) > WAIT_MAX:
		_problem(at, "「wait 秒」と書く（0 より長く、%s 秒まで）: %s" % [WAIT_MAX, text])
		return
	_events.append(CutWaitEvent.new(float(args[0])))
