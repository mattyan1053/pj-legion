extends "res://game/episode/episode_sides.gd"
## 話（game/episode.gd）の、話し手と台詞の節を読む: [cast]（話し手と姿）、[before]・[after]・[lost]（会話）、[cues]（途中の台詞）。


## 話し手（[cast] の「名前 = 陣営, 姿」。陣営は ally（人の軍）か enemy（敵の軍）。姿は無くてよく、無ければその陣営の将）。
## その陣営で最初に書いた人が、主な話し手（speakers の [0] が人の軍、[1] が敵の軍。[1] の姿は話の一覧のカードの顔にもなる）。
## 両方の陣営の節を読んだあとに読む（将の姿 king_figure が要る）。
func _read_cast(file: RefCounted) -> void:
	if not file.has("cast"):
		file.problem(1, "[cast] の節が無い（話し手を「名前 = ally」「名前 = enemy, 姿」と書く）")
		return
	var main_found := [false, false]
	var names := {}
	for row: Dictionary in file.rows("cast"):
		var text: String = row["text"]
		var at := text.find("=")
		var name := text.substr(0, maxi(at, 0)).strip_edges()
		var parts := text.substr(at + 1).split(",")
		if at < 0 or name == "" or parts.size() > 2:
			file.problem(row["line"], "話し手は「名前 = 陣営, 姿」（陣営は ally か enemy。姿は無くてよい）: %s" % text)
			continue
		var side_word := parts[0].strip_edges()
		if not SIDE_WORDS.has(side_word):
			file.problem(row["line"], "話し手「%s」の陣営は ally（人の軍）か enemy（敵の軍）: %s" % [name, side_word])
			continue
		var side: int = SIDE_WORDS[side_word]
		if names.has(name):
			file.problem(row["line"], "話し手「%s」が 2 度ある（%d 行目にもある）" % [name, names[name]])
			continue
		names[name] = row["line"]
		var figure := {"kind": UnitKind.Id.KING, "evolved": false, "look": &""}
		if parts.size() == 2:
			figure = read_figure(file, row["line"], parts[1].strip_edges())
			if figure.is_empty():
				continue
		if figure["kind"] == UnitKind.Id.KING and king_looks[side] != &"":
			if figure["look"] != &"":
				file.problem(row["line"], "将の姿（king_figure）のある陣営の将に、人物の形は書けない: %s" % text)
				continue
			figure["look"] = king_looks[side]
		if not main_found[side]:
			main_found[side] = true
			speakers[side] = name
			figures[side] = figure
		else:
			speakers.append(name)
			speaker_sides.append(side)
			figures.append(figure)
	for side: int in [0, 1]:
		if not main_found[side]:
			var word: String = SIDE_WORDS.find_key(side)
			file.problem(file.line_of("cast"), "[cast] に、%s の話し手が 1 人もいない（「名前 = %s」）" % ["人の軍" if side == 0 else "敵の軍", word])


## 話し手の姿「駒の種類」か「駒の種類 evolved」（king も書ける。中立の駒は書けない。進化後は進化する駒だけ）。読めなければ空。
## 最後に「crown」を付けると、将の印（頭の上の金の輪）を付ける（将の姿でない将。会話の姿だけに効く。"crown" の鍵は、付けたときだけ入る）。
## さらに最後に人物の名前（unit_looks.gd の PERSONS。「sniper noe」）を付けると、その人の形にする（"look" に入る）。
## 人物の形は、会話の姿と、盤でその人が乗る駒に効く（battle_source.gd の cast_looks）。駒の種類は、その人の種類と同じにする。
static func read_figure(file: RefCounted, line: int, value: String) -> Dictionary:
	var words := value.split(" ", false)
	var kind := StoryFile.enum_value(UnitKind.Id, words[0] if not words.is_empty() else "")
	if kind < 0 or UnitKind.is_neutral(kind as UnitKind.Id):
		var neutral := UnitKind.Id.values().filter(func(each: int) -> bool: return UnitKind.is_neutral(each as UnitKind.Id))
		file.problem(line, "知らない姿「%s」（書けるのは %s）" % [value, StoryFile.enum_words(UnitKind.Id, neutral)])
		return {}
	var marks := Array(words.slice(1))
	var person := &""
	if not marks.is_empty() and not ["evolved", "crown"].has(marks.back()):
		person = StringName(marks.pop_back())
		if not UnitLooks.PERSONS.has(person):
			file.problem(line, "知らない人物の形「%s」（書けるのは %s）" % [person, ", ".join(UnitLooks.PERSONS.keys())])
			return {}
		if UnitLooks.PERSONS[person] != kind:
			file.problem(line, "人物の形「%s」の駒の種類は %s: %s" % [person, String(UnitKind.Id.keys()[UnitLooks.PERSONS[person]]).to_lower(), value])
			return {}
	var evolved := marks.has("evolved")
	var crown := marks.has("crown")
	if marks != (["evolved"] if evolved else []) + (["crown"] if crown else []):
		file.problem(line, "姿は「駒の種類」のあとに、evolved、crown、人物の形をこの順で（どれも無くてよい）: %s" % value)
		return {}
	if evolved and not UnitIcons.evolves(kind as UnitKind.Id):
		file.problem(line, "%s に進化後の姿は無い" % words[0])
		return {}
	var figure := {"kind": kind, "evolved": evolved, "look": person}
	if crown:
		figure["crown"] = true
	return figure


func _read_talks(file: RefCounted) -> void:
	for section: String in ["before", "after", "lost"]:
		var optional := section == "lost"
		var max_lines := LOST_MAX_LINES if optional else TALK_MAX_LINES
		var max_chars := LOST_MAX_CHARS if optional else TALK_MAX_CHARS
		var rows: Array = []
		for row: Dictionary in file.rows(section):
			var line := _speech(file, row["line"], row["text"])
			if not line.is_empty() and optional and line[0] == NARRATION_SIDE:
				file.problem(row["line"], "[%s] に地の文は書けない（決着の画面に、話し手のひとことで出す）" % section)
			elif not line.is_empty():
				rows.append(line)
				if (line[1] as String).length() > max_chars:
					file.problem(row["line"], "[%s] の文は %d 字まで（いま %d 字）" % [section, max_chars, (line[1] as String).length()])
		if rows.is_empty() and (not optional or file.has(section)):
			file.problem(maxi(file.line_of(section), 1), "[%s] の会話が無い" % section)
		elif rows.size() > max_lines:
			file.problem(file.line_of(section), "[%s] の会話は %d 行まで（いま %d 行）" % [section, max_lines, rows.size()])
		set(section, rows)


## 会話の行「話し手: 文」（全角の「：」でもよい）を [陣営, 文, 話し手（speakers の番号）] に。
## 話し手は [cast] に書いた名前。頭が「>」（全角の「＞」でもよい）の行は地の文（[NARRATION_SIDE, 文, -1]）。読めなければ空。
func _speech(file: RefCounted, line: int, text: String) -> Array:
	if text.begins_with(NARRATION_MARK) or text.begins_with("＞"):
		var told := text.substr(1).strip_edges()
		if told == "":
			file.problem(line, "地の文が空（「> 文」）")
			return []
		return [NARRATION_SIDE, told, -1]
	var at := text.find(":")
	var wide := text.find("：")
	if at < 0 or (wide >= 0 and wide < at):
		at = wide
	if at < 0:
		file.problem(line, "会話の行は「話し手: 文」: %s" % text)
		return []
	var name := text.substr(0, at).strip_edges()
	var said := text.substr(at + 1).strip_edges()
	var who := speakers.find(name)
	if name == "" or who < 0:
		file.problem(line, "知らない話し手「%s」（[cast] に書いた名前: %s）" % [name, " / ".join(speakers)])
		return []
	if said == "":
		file.problem(line, "文が空")
		return []
	return [speaker_sides[who], said, who]


## 対戦の途中の会話の行「(きっかけ 値) 話し手: 文」。
func _read_cues(file: RefCounted) -> void:
	for row: Dictionary in file.rows("cues"):
		var text: String = row["text"]
		var close := text.find(")")
		if not text.begins_with("(") or close < 0:
			file.problem(row["line"], "途中の台詞の行は「(きっかけ 値) 話し手: 文」: %s" % text)
			continue
		var words := text.substr(1, close - 1).split(" ", false)
		var speech := _speech(file, row["line"], text.substr(close + 1).strip_edges())
		if speech.is_empty():
			continue
		if speech[0] == NARRATION_SIDE:
			file.problem(row["line"], "[cues] に地の文は書けない（対戦の途中の台詞は、話し手の札で出す）")
			continue
		if words.size() != 2 or not BattleCues.KINDS.has(StringName(words[0])):
			file.problem(row["line"], "知らないきっかけ「%s」（書けるのは %s。値と 2 語で書く）" % [" ".join(words), ", ".join(BattleCues.KINDS)])
			continue
		var kind := StringName(words[0])
		var value := -1
		if kind == BattleCues.TURN:
			value = words[1].to_int() if words[1].is_valid_int() else 0
			if value < 1:
				file.problem(row["line"], "ターンは 1 から: %s" % words[1])
				continue
			if hold_turns > 0 and value > hold_turns:
				file.problem(row["line"], "守り切るターン（%d）の外なので出ない: turn %d" % [hold_turns, value])
				continue
		else:
			value = SIDE_WORDS.get(words[1], -1)
			if value < 0:
				file.problem(row["line"], "陣営は ally か enemy: %s" % words[1])
				continue
		if (speech[1] as String).length() > CUE_MAX_CHARS:
			file.problem(row["line"], "途中の台詞は %d 字まで（いま %d 字）" % [CUE_MAX_CHARS, (speech[1] as String).length()])
		cues.append([kind, value, speech[0], speech[1], speech[2]])
	if cues.size() > CUES_MAX:
		file.problem(file.line_of("cues"), "途中の台詞は %d つまで（いま %d）" % [CUES_MAX, cues.size()])
