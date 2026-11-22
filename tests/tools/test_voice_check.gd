extends "res://tests/base_test.gd"
## 台詞を、呼び方と一人称の表（game/story/voices.txt。docs/story.md の「口調の見本」）に掛ける（tools/voice_check.gd）。
## 人間の言葉「ウルが導師と呼ばれているんだと認識するまで時間差がある」「口調が立場に対して違和感がある」（Issue #49、11/22）から。

const VoiceCheck := preload("res://tools/voice_check.gd")
const Story := preload("res://game/story.gd")
const Campaign := preload("res://game/campaign.gd")
const Episode := preload("res://game/episode.gd")

## まだ口調の見本に合わせていない話（合わせたら消す。空になったら、この定数ごと消す）。
const PENDING := [
	"drill_skills", "drill_shrine", "drill_capture", "ridge_path", "ridge_ambush", "ridge_hold", "gorge_rout", "barrow_rout",
	"barrow_knight", "warden_twin", "drill_last", "quarry_blast",
	"trial_shadow_step", "trial_eruption", "trial_evolution", "gorge_crossing", "gorge_rejoin", "ridge_siege", "barrow_vigil",
	"crag_drums", "boulder_warden", "mist_forest", "ridge_bones", "vale_keeper",
]

const TABLE := """
[pronouns]
words = 俺, 私, わし, 我, おれ
[watch]
words = あんた, お前
[people]
names = ハーデン, ドーソン, ウル, イェルダ
[titles]
隊長 = ハーデン
曹長 = ドーソン
導師 = ウル
[ハーデン]
self = 俺
you = お前
ドーソン = ドーソン曹長, 曹長
[ドーソン]
self = 俺
avoid = 隊長どの
ハーデン = ハーデン少尉, 隊長
[イェルダ]
self = 私
ウル = ウル導師, 導師
"""


func test_the_table_reads() -> void:
	var table: VoiceCheck = VoiceCheck.load_table()
	assert_eq(Array(table.problems), [], "表の書き間違い")
	assert_true(table.speakers.has("ハーデン") and table.speakers.has("イェルダ"), "話し手の節")
	assert_true(table.pronouns.has("俺") and table.watch.has("あんた") and table.titles.has("導師"), "見張る言葉")


## 名前のある 10 人は、だれも一人称を持つ（表の節が抜けていない）。
func test_every_named_person_has_a_voice() -> void:
	var table: VoiceCheck = VoiceCheck.load_table()
	for name: String in table.people:
		assert_true(table.speakers.has(name) and not table.speakers[name]["self"].is_empty(), "%s の節か一人称が無い" % name)


## 全部の話の台詞が、表どおり。
func test_every_line_follows_the_table() -> void:
	var table: VoiceCheck = VoiceCheck.load_table()
	for line: String in table.check_all():
		var pending := false
		for id: String in PENDING:
			pending = pending or line.contains("/%s [" % id)
		assert_true(pending, line)


func test_pending_episodes_exist() -> void:
	var ids := {}
	for episode: Episode in Story.all_episodes():
		ids[String(episode.id)] = true
	for id: String in PENDING:
		assert_true(ids.has(id), "PENDING に、無い話: %s" % id)


func test_a_wrong_pronoun_is_found() -> void:
	var table: VoiceCheck = VoiceCheck.parse(TABLE)
	assert_eq(Array(table.check_line("ハーデン", "俺が行く。", {})), [], "表どおりの一人称")
	assert_eq(table.check_line("ハーデン", "私が行く。", {}).size(), 1, "表に無い一人称")
	assert_eq(Array(table.check_line("ハーデン", "怪我人を運べ。我慢しろ。", {})), [], "「怪我」「我慢」は一人称ではない")
	assert_eq(Array(table.check_line("イェルダ", "見ておれ。かわして進め。", {})), [], "「ておれ」「かわし」は一人称ではない")


func test_a_wrong_address_is_found() -> void:
	var table: VoiceCheck = VoiceCheck.parse(TABLE)
	var known := {"隊長": true, "曹長": true}
	assert_eq(Array(table.check_line("ドーソン", "隊長、旗の番を決めときましょう。", known)), [], "表どおりの呼び方")
	assert_eq(table.check_line("ドーソン", "あんたが生徒だ。", known).size(), 1, "表に無い二人称")
	assert_eq(table.check_line("ハーデン", "ドーソン、頼む。", known).size(), 1, "名前だけで呼ぶと表に無い")
	assert_eq(table.check_line("ドーソン", "行きますよ、隊長さん。", known).size(), 1, "表に無い敬称")
	assert_eq(table.check_line("ドーソン", "隊長どの、こちらへ。", known).size(), 2, "言わないことにした言葉（呼び方としても表に無い）")
	assert_eq(Array(table.check_line("ドーソン", "ドーソン曹長、着任しました。それも曹長の仕事です。", known)), [], "名乗りと自分の肩書きは見ない")
	assert_eq(Array(table.check_line("", "ハーデンが行く。あんたも来い。", known)), [], "地の文の呼び方は見ない")


## 肩書きだけの呼び方は、名前と同じ行に出たあとで。
func test_a_title_needs_the_name_first() -> void:
	var table: VoiceCheck = VoiceCheck.parse(TABLE)
	var introduced := {}
	assert_eq(table.check_line("イェルダ", "導師の前では、私は弟子だ。", introduced).size(), 1, "名前の前に肩書き")
	assert_eq(Array(table.check_line("イェルダ", "ウル導師の前では、私は弟子だ。", introduced)), [], "名前つき")
	assert_eq(Array(table.check_line("イェルダ", "導師、こちらへ。", introduced)), [], "結びついたあと")
