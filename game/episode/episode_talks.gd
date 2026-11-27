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
		if not main_found[side] and (side == 0 or _fights):  # 対戦の無い話は、敵の軍の話し手がいなくてよい
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
		if written_as_scenes and not optional:
			continue  # 場面の節で書く話の会話は、[talk 名前]（episode_scenes.gd）
		if optional:
			var rows: Array[TalkLine] = []
			for row: Dictionary in file.rows(section):
				var line := _speech(file, row["line"], row["text"])
				if line != null and line.is_narration():
					file.problem(row["line"], "[%s] に地の文は書けない（決着の画面に、話し手のひとことで出す）" % section)
				elif line != null:
					rows.append(line)
					if line.text.length() > LOST_MAX_CHARS:
						file.problem(row["line"], "[%s] の文は %d 字まで（いま %d 字）" % [section, LOST_MAX_CHARS, line.text.length()])
			if rows.is_empty() and file.has(section):
				file.problem(maxi(file.line_of(section), 1), "[%s] の会話が無い" % section)
			elif rows.size() > LOST_MAX_LINES:
				file.problem(file.line_of(section), "[%s] の会話は %d 行まで（いま %d 行）" % [section, LOST_MAX_LINES, rows.size()])
			set(section, rows)
		else:
			if not file.has(section):
				file.problem(1, "[%s] の会話が無い" % section)
			set(section, _talk_rows(file, section, file.rows(section)))


## 会話の節 section の行 source（{"line", "text"} の列）を、会話の行の列に読む（[before]・[after]・[talk 名前] が使う）。
## 「話し手: 文」「> 地の文」のほかに、括弧で始まる指示の行が書ける（docs/story.md の「選択肢」）:
##   (choice 名前)        ここで選ばせる（すぐ前の行が問い。名前で答えを覚える）
##   (answer 鍵) 画面の文  答え。次の (answer)・(end) までの行は、この答えを選んだときだけ出す
##   (end)                選択肢の終わり（ここから元の流れ）
##   (if 名前 = 鍵) 行     その選択肢でその答えを選んでいたときだけ出す行（「!=」なら、選んでいなかったとき）
## 行の数は、1 度に読む数で数える（選択肢は、いちばん長い答えの行の数）。
func _talk_rows(file: RefCounted, section: String, source: Array) -> Array[TalkLine]:
	var rows: Array[TalkLine] = []
	var word := RegEx.create_from_string(CHOICE_WORD)
	var asking: TalkLine = null  # いま読んでいる選択肢の、問いの行
	var answer := &""  # いま読んでいる答えの鍵
	var read := 0  # 1 度に読む行の数
	var branch := 0  # いまの答えの行の数
	var longest := 0  # いまの選択肢の、いちばん長い答えの行の数
	for row: Dictionary in source:
		var at: int = row["line"]
		var text: String = row["text"]
		var mark := _mark_of(text)
		if mark.is_empty():
			var line := _speech(file, at, text)
			if line == null:
				continue
			if line.text.length() > TALK_MAX_CHARS:
				file.problem(at, "[%s] の文は %d 字まで（いま %d 字）" % [section, TALK_MAX_CHARS, line.text.length()])
			if asking != null and answer == &"":
				file.problem(at, "(choice %s) のあとは (answer 鍵) の行から書く" % asking.choice)
			elif asking != null:
				line.when_choice = asking.choice
				line.when_answer = answer
				branch += 1
			else:
				read += 1
			rows.append(line)
			continue
		var words: PackedStringArray = mark["words"]
		match words[0] if not words.is_empty() else "":
			"choice":
				if asking != null:
					file.problem(at, "選択肢の中に選択肢は書けない（先に (end) で閉じる）")
				elif words.size() != 2 or word.search(words[1]) == null or mark["rest"] != "":
					file.problem(at, "選択肢は「(choice 名前)」（名前は英小文字・数字・_）: %s" % text)
				elif rows.is_empty() or rows.back().asks() or rows.back().when_choice != &"":
					file.problem(at, "(choice %s) の前に、問いになる行が要る（いつも出る行のすぐあとに書く）" % words[1])
				elif choices.has(StringName(words[1])):
					file.problem(at, "選択肢「%s」が 2 度ある（名前は、物語の中で重ねない）" % words[1])
				else:
					asking = rows.back()
					asking.choice = StringName(words[1])
					choices[asking.choice] = []
					answer = &""
					branch = 0
					longest = 0
			"answer":
				if asking == null:
					file.problem(at, "(answer 鍵) は (choice 名前) のあとに書く")
				elif words.size() != 2 or word.search(words[1]) == null:
					file.problem(at, "答えは「(answer 鍵) 画面の文」（鍵は英小文字・数字・_）: %s" % text)
				elif (choices[asking.choice] as Array).has(StringName(words[1])):
					file.problem(at, "答え「%s」が 2 度ある" % words[1])
				elif mark["rest"] == "" or (mark["rest"] as String).length() > OPTION_MAX_CHARS:
					file.problem(at, "答えの文は 1 から %d 字（いま %d 字）" % [OPTION_MAX_CHARS, (mark["rest"] as String).length()])
				else:
					longest = maxi(longest, branch)
					branch = 0
					answer = StringName(words[1])
					choices[asking.choice].append(answer)
					asking.options.append({"key": answer, "text": mark["rest"]})
			"end":
				if asking == null:
					file.problem(at, "(end) は (choice 名前) のあとに書く")
				else:
					if asking.options.size() < OPTIONS_MIN or asking.options.size() > OPTIONS_MAX:
						file.problem(at, "選択肢「%s」の答えは %d から %d つ（いま %d）" % [asking.choice, OPTIONS_MIN, OPTIONS_MAX, asking.options.size()])
					read += maxi(longest, branch)
					asking = null
			"if":
				# (if 名前 = 鍵) か (if 名前 != 鍵)
				var negate := words.size() == 4 and words[2] == "!="
				var line := _speech(file, at, mark["rest"]) if mark["rest"] != "" else null
				if words.size() != 4 or not (negate or words[2] == "=") or word.search(words[1]) == null or word.search(words[3]) == null:
					file.problem(at, "条件の行は「(if 名前 = 鍵) 話し手: 文」（「!=」なら、選んでいなかったとき）: %s" % text)
				elif asking != null:
					file.problem(at, "選択肢の答えの中に、(if …) の行は書けない")
				elif line == null:
					if mark["rest"] == "":
						file.problem(at, "条件のあとに、行が無い: %s" % text)
				else:
					if line.text.length() > TALK_MAX_CHARS:
						file.problem(at, "[%s] の文は %d 字まで（いま %d 字）" % [section, TALK_MAX_CHARS, line.text.length()])
					line.when_choice = StringName(words[1])
					line.when_answer = StringName(words[3])
					line.when_not = negate
					conditions.append({"line": at, "choice": line.when_choice, "answer": line.when_answer, "here": choices.has(line.when_choice)})
					read += 1
					rows.append(line)
			_:
				file.problem(at, "知らない指示「%s」（書けるのは (choice 名前)、(answer 鍵) 文、(end)、(if 名前 = 鍵) 行）" % text)
	if asking != null:
		file.problem(file.line_of(section), "選択肢「%s」を (end) で閉じていない" % asking.choice)
	if rows.is_empty() and file.has(section):
		file.problem(maxi(file.line_of(section), 1), "[%s] の会話が無い" % section)
	elif read > TALK_MAX_LINES:
		file.problem(file.line_of(section), "[%s] の会話は %d 行まで（いま %d 行。選択肢は、いちばん長い答えで数える）" % [section, TALK_MAX_LINES, read])
	return rows


## 行 text が括弧で始まる指示の行なら {"words": 括弧の中の語, "rest": 括弧のあとの文}。そうでなければ空。
static func _mark_of(text: String) -> Dictionary:
	if not text.begins_with("("):
		return {}
	var close := text.find(")")
	if close < 0:
		return {"words": PackedStringArray(), "rest": ""}
	return {"words": text.substr(1, close - 1).split(" ", false), "rest": text.substr(close + 1).strip_edges()}


## 会話の行「話し手: 文」（全角の「：」でもよい）を、会話の行（talk_line.gd の speech）に。
## 話し手は [cast] に書いた名前。頭が「>」（全角の「＞」でもよい）の行は地の文（talk_line.gd の narration）。読めなければ null。
func _speech(file: RefCounted, line: int, text: String) -> TalkLine:
	if text.begins_with(NARRATION_MARK) or text.begins_with("＞"):
		var told := text.substr(1).strip_edges()
		if told == "":
			file.problem(line, "地の文が空（「> 文」）")
			return null
		return TalkLine.narration(told)
	var at := text.find(":")
	var wide := text.find("：")
	if at < 0 or (wide >= 0 and wide < at):
		at = wide
	if at < 0:
		file.problem(line, "会話の行は「話し手: 文」: %s" % text)
		return null
	var name := text.substr(0, at).strip_edges()
	var said := text.substr(at + 1).strip_edges()
	var who := speakers.find(name)
	if name == "" or who < 0:
		file.problem(line, "知らない話し手「%s」（[cast] に書いた名前: %s）" % [name, " / ".join(speakers)])
		return null
	if said == "":
		file.problem(line, "文が空")
		return null
	return TalkLine.speech(speaker_sides[who], said, who)


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
		if speech == null:
			continue
		if speech.is_narration():
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
		if speech.text.length() > CUE_MAX_CHARS:
			file.problem(row["line"], "途中の台詞は %d 字まで（いま %d 字）" % [CUE_MAX_CHARS, speech.text.length()])
		cues.append(TalkCue.new(kind, value, speech))
	if cues.size() > CUES_MAX:
		file.problem(file.line_of("cues"), "途中の台詞は %d つまで（いま %d）" % [CUES_MAX, cues.size()])
