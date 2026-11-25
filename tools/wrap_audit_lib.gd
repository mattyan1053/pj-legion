extends RefCounted
## 折り返しの点検の中身（tools/wrap_audit.gd と tests/game/test_wrap_audit.gd が使う）。ノードを作らない。
##
## 幅は、それぞれの場面の定数から出す（名前の札の幅などは、話し手の名前を測って足す）。場面の組み立てを変えたら、ここも合わせる。
## - 会話の枠（talk_screen.gd の text_width。地の文は見出しの字）と、会話のログ（talk_log.gd の TEXT_WIDTH）。
## - 対戦の途中の台詞の帯（battle_talk.gd。話し手のアイコンと送りの印が出る、いちばん狭いとき）。
## - 負けの台詞の板（result_screen.gd の REMARK_WIDTH。話し手のアイコンが出るとき）。
## - 札の文（card_sites）: 物語の選択のカードの紹介、出撃準備の手ほどき、対戦ルールの札、縫い目の様子の札、兵の情報の札と詳しい窓のスキル・必殺技・状態。

const TextWrap := preload("res://game/text_wrap.gd")
const Story := preload("res://game/story.gd")
const TalkScreen := preload("res://game/talk_screen.gd")
const TalkLog := preload("res://game/talk_log.gd")
const BattleTalk := preload("res://game/battle_talk.gd")
const ResultScreen := preload("res://game/result_screen.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const CampaignList := preload("res://game/campaign_list_screen.gd")
const SortieScreen := preload("res://game/sortie_screen.gd")
const RuleCard := preload("res://game/rule_card.gd")
const SignCard := preload("res://game/sign_card.gd")
const InfoCard := preload("res://game/info_card.gd")
const HudBase := preload("res://game/battle_hud/hud_base.gd")
const UnitDetail := preload("res://game/unit_detail.gd")
const SheetParts := preload("res://game/sheet_parts.gd")
const Maps := preload("res://game/maps.gd")

## 対戦の途中の台詞の帯の行の数の上限（それより多いと、盤の上を覆いすぎる）。
const CUE_MAX_LINES := 2
## 負けの台詞の板の、1 つの台詞の行の数の上限（板は下へ伸びる。台詞が 2 つでも、戦績の列の高さに収まるくらい）。
const REMARK_MAX_LINES := 4
## 画面の文の表の文を折り返す幅（px）と字の大きさ: 駒の情報の窓（battle_hud.gd の INFO_WIDTH）、駒の詳しい窓の右の列（unit_detail.gd の RIGHT_WIDTH）など。
const TEXT_SITES: Array[Vector2] = [Vector2(320.0, 15.0), Vector2(320.0, 17.0), Vector2(600.0, 15.0)]


## 全部の話の台詞: [{"where": どこの何行目か, "site": 出る所, "text": 文, "name": 話し手, "narration": 地の文か}, …]。
static func story_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for episode in Story.all_episodes():
		var where := episode.path.get_file()
		for part: String in ["before", "after", "lost"]:
			var rows: Array = episode.get(part)
			for i in rows.size():
				var row: Array = rows[i]
				lines.append({"where": "%s [%s] %d" % [where, part, i + 1], "site": &"remark" if part == "lost" else &"talk",
					"text": row[1], "name": episode.speakers[row[2]] if row[2] >= 0 else "", "narration": int(row[0]) == TalkScreen.NARRATION_SIDE})
		for i in episode.cues.size():
			var cue: Array = episode.cues[i]
			lines.append({"where": "%s [cues] %d" % [where, i + 1], "site": &"cue", "text": cue[3],
				"name": episode.speakers[cue[4]] if cue[4] >= 0 else "", "narration": false})
	return lines


## 話の台詞の、切れ方の悪い所と行の数の超え（1 か所が 1 行の文）。
static func audit_story() -> Array[String]:
	var found: Array[String] = []
	for line in story_lines():
		for site in _sites_of(line):
			var width: float = site["width"]
			var measure: Callable = site["measure"]
			var folded := TextWrap.fold(line["text"], width, measure)
			for bad in TextWrap.bad_breaks(line["text"], width, measure):
				found.append("%s（%s）: %s" % [line["where"], site["name"], bad])
			var count := folded.count("\n") + 1
			if count > int(site["max_lines"]):
				found.append("%s（%s）: %d 行（%d 行まで）: %s" % [line["where"], site["name"], count, site["max_lines"], folded.replace("\n", " / ")])
	return found


## 画面の文の表の、長い文の切れ方の悪い所（使う所の幅は場面で変わるので、TEXT_SITES の幅で見る）。
static func audit_texts() -> Array[String]:
	var found: Array[String] = []
	for path in DirAccess.get_files_at("res://game/text"):
		if not path.ends_with(".csv"):
			continue
		var file := FileAccess.open("res://game/text/" + path, FileAccess.READ)
		file.get_csv_line()  # 見出しの行
		while not file.eof_reached():
			var row := file.get_csv_line()
			if row.size() < 2 or row[0].is_empty():
				continue
			var text := row[1].replace("\\n", "\n")
			if text.contains("{"):
				text = _fill_placeholders(text)
			for site in TEXT_SITES:
				var measure := _measure(UiTheme.FONT_BODY, int(site.y))
				for bad in TextWrap.bad_breaks(text, site.x, measure):
					found.append("%s %s（幅 %d・%d px）: %s" % [path, row[0], int(site.x), int(site.y), bad])
	return found


## 札の文の、切れ方の悪い所と行の数の超え（1 か所が 1 行の文）。どの札も、出す所の幅・字の大きさ・行の数の上限で見る。
static func audit_cards() -> Array[String]:
	var found: Array[String] = []
	for site in card_sites():
		var width: float = site["width"]
		for entry: Array in site["texts"]:
			# 字の大きさを文で変える札（対戦ルールの札）は、その札が選ぶ大きさで見る。
			var font_size: int = site["sizer"].call(entry[1]) if site.has("sizer") else int(site["size"])
			var measure := _measure(UiTheme.FONT_BODY, font_size)
			for bad in TextWrap.bad_breaks(entry[1], width, measure):
				found.append("%s %s（%s）: %s" % [site["name"], entry[0], "幅 %d・%d px" % [int(width), font_size], bad])
			var count := TextWrap.line_count(entry[1], width, measure)
			if count > int(site["max_lines"]):
				found.append("%s %s: %d 行（%d 行まで）: %s" % [site["name"], entry[0], count, site["max_lines"],
					TextWrap.fold(entry[1], width, measure).replace("\n", " / ")])
	return found


## 札ごとの {name, width, size（字の大きさ）, max_lines, texts: [[どれか, 文], …]}。幅は、それぞれの札の定数から出す。
static func card_sites() -> Array[Dictionary]:
	var intros: Array[Array] = []
	for campaign in Story.campaigns():
		if campaign.intro != "":
			intros.append([campaign.title, campaign.intro])
	var lessons: Array[Array] = []
	for episode in Story.all_episodes():
		if episode.lesson != "":
			lessons.append([episode.path.get_file(), episode.lesson])
	var goals: Array[Array] = []
	# 数は 2 桁、番人の名前はいちばん長い字数（Maps.BOSS_NAME_MAX）で埋める。
	var args := {"turns": 12, "capture": 12, "holds": 12, "boss": "縫".repeat(Maps.BOSS_NAME_MAX)}
	for key: String in GameWonEvent.Reason.keys():
		var reason := key.to_lower()
		goals.append([reason, Text.t("battle.goal.win." + reason, args)])
	goals.append(["deadline", Text.t("battle.goal.deadline", args)])
	var signs: Array[Array] = []
	for sign in Seam.KEYS.size():
		signs.append([String(Seam.KEYS[sign]), Names.sign_summary(sign)])
	var abilities: Array[Array] = []
	for skill in Skills.ALL:
		abilities.append([Names.skill(skill), Names.skill_summary(skill)])
	for ult in Ults.ALL:
		abilities.append([Names.ult(ult), Names.ult_summary(ult)])
	var statuses: Array[Array] = []
	for type: int in Status.Type.values():
		statuses.append([Names.status(type), Names.status_summary(type)])
	# 詳しい窓のスキルと必殺技の札は、右の列に 2 枚並ぶ。
	var detail_card := (UnitDetail.RIGHT_WIDTH - UnitDetail.GAP) / 2.0
	return [
		{"name": "物語の選択のカード", "width": CampaignList.INTRO_WIDTH, "size": CampaignList.INTRO_FONT, "max_lines": CampaignList.INTRO_MAX_LINES, "texts": intros},
		{"name": "出撃準備の手ほどき", "width": SortieScreen.WRAP_WIDTH, "size": SortieScreen.LESSON_FONT, "max_lines": 3, "texts": lessons},
		{"name": "対戦ルールの札", "width": RuleCard.TEXT_WIDTH, "max_lines": RuleCard.LINE_MAX_LINES, "texts": goals + signs,
			"sizer": func(text: String) -> int: return RuleCard.fold_line(text, UiTheme.FONT_BODY)[0]},
		{"name": "縫い目の様子の札", "width": SignCard.SUMMARY_WIDTH, "size": SignCard.SUMMARY_FONT, "max_lines": SignCard.SUMMARY_MAX_LINES, "texts": signs},
		{"name": "兵の情報の札", "width": HudBase.INFO_WIDTH - InfoCard.SUMMARY_INSET, "size": SheetParts.NOTE_SIZE, "max_lines": 99, "texts": abilities},
		{"name": "兵の情報の札の状態", "width": HudBase.INFO_WIDTH - 22.0, "size": SheetParts.NOTE_SIZE, "max_lines": 99, "texts": statuses},
		{"name": "兵の詳しい窓", "width": detail_card - SheetParts.SUMMARY_INSET, "size": SheetParts.NOTE_SIZE, "max_lines": 99, "texts": abilities},
	]


## 行 line が出る所ごとの {name, width, measure, max_lines}。
static func _sites_of(line: Dictionary) -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	var body := UiTheme.FONT_HEADING if line["narration"] else UiTheme.FONT_BODY
	match line["site"]:
		&"talk":
			var talk_line := {"text": line["text"], "side": TalkScreen.NARRATION_SIDE if line["narration"] else 0}
			sites.append({"name": "会話の枠", "width": TalkScreen.text_width(talk_line), "measure": _measure(body, TalkScreen.TEXT_FONT), "max_lines": talk_max_lines()})
			sites.append({"name": "会話のログ", "width": TalkLog.TEXT_WIDTH, "measure": _measure(body, TalkLog.TEXT_FONT), "max_lines": 99})
		&"cue":
			sites.append({"name": "途中の台詞の帯", "width": cue_width(line["name"]), "measure": _measure(body, 17), "max_lines": CUE_MAX_LINES})
		&"remark":
			sites.append({"name": "負けの台詞の板", "width": remark_width(), "measure": _measure(body, ResultScreen.REMARK_FONT), "max_lines": REMARK_MAX_LINES})
	return sites


## 会話の枠に収まる行の数: 枠の高さから、上下の余白と、下の行（何文目か・送りの案内）を引いて、行の高さで割る。
static func talk_max_lines() -> int:
	var room := TalkScreen.BOX_HEIGHT - 18.0 - 12.0 - UiTheme.FONT_BODY.get_height(15)
	return maxi(1, floori(room / UiTheme.FONT_BODY.get_height(TalkScreen.TEXT_FONT)))


## 途中の台詞の帯の文の幅（battle_talk.gd の _next と同じ引き算。話し手のアイコンと送りの印が出るとき）。
static func cue_width(speaker: String) -> float:
	var box := 4.0 + 12.0  # 帯の左右の余白
	# 名前の札は、決まった幅（名前が入らないほど長ければ、そのぶん広がる）。
	var plate := maxf(BattleTalk.PLATE_WIDTH, 20.0 + UiTheme.FONT_BOLD.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	var face := BattleTalk.FACE_SIZE
	var more := UiTheme.FONT_BODY.get_string_size("▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	return BattleTalk.WIDTH - box - plate - BattleTalk.ROW_GAP - face - BattleTalk.ROW_GAP - more - BattleTalk.ROW_GAP


## 負けの台詞の板の文の幅（result_screen/result_remark.gd の _remark_row と同じ引き算。話し手のアイコンが出るとき）。
static func remark_width() -> float:
	return ResultScreen.REMARK_WIDTH - 12.0 * 2.0 - ResultScreen.REMARK_FACE - 2.0 - 10.0


static func _measure(font: Font, font_size: int) -> Callable:
	var widths := {}
	return func(character: String) -> float:
		if not widths.has(character):
			widths[character] = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		return widths[character]


## 差し込みのうち、数が入るもの（2 桁の数で埋める）。
const NUMBER_KEYS: Array[String] = ["count", "amount", "turns", "turn", "hp", "max_hp", "max", "level", "cost", "range", "budget", "number",
	"move", "power", "needed", "damage", "heal", "total", "durability", "x", "y", "uses", "percent", "left", "kills", "experience",
	"capture", "radius", "penalty", "times", "cooldown", "gauge", "holds", "before", "after", "value", "over",
	"year", "month", "day", "hour", "minute", "hours", "minutes"]
## 差し込みのうち、マスの座標が入るもの（common.cell の形で埋める）。
const CELL_KEYS: Array[String] = ["from", "to", "cell"]


## 「{name}」のような差し込みを、それらしい長さの文字に置き換える（数は 2 桁、マスは「(12, 12)」、ほかは名前とみて 5 文字）。
static func _fill_placeholders(text: String) -> String:
	var regex := RegEx.create_from_string("\\{([^}]*)\\}")
	var out := text
	for found in regex.search_all(text):
		var key := found.get_string(1)
		var filled := "ソルジャー"
		if NUMBER_KEYS.has(key):
			filled = "12"
		elif CELL_KEYS.has(key):
			filled = "(12, 12)"
		out = out.replace(found.get_string(), filled)
	return out
