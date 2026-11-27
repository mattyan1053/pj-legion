extends RefCounted
## ストーリーの台本を、物語と話のファイル（game/story/）から作る。
## 人間が、遊ばずに読み物として会話を読むためのもの（Issue #49）。作るものは 2 つ:
## - 目次（game/story/README.md。コミットする）: 物語ごとに、話の順に話のファイルへのリンクを並べる。
##   会話そのものは話のファイルを読む（会話を写さないので、台詞を直しても作り直しが要らない）。
## - 通しの台本（build/story-script/。コミットしない）: 物語 1 つが Markdown 1 つ。1 本で読みたいときに手元で作る。
##
## 書き出すのは tools/write_story_script.gd。テスト（tests/tools/test_story_script.gd）は、
## 置いてある目次が、いまの物語のファイルから作り直したものと同じことを確かめる。
## ノードに依存しない。

const Story := preload("res://game/story.gd")
const Campaign := preload("res://game/campaign.gd")
const Episode := preload("res://game/episode.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const WinText := preload("res://game/win_text.gd")
const Names := preload("res://game/names.gd")

## 通しの台本を書き出す所（物語の id が、ファイルの名前）。コミットしない（.gitignore の /build/）。
const DIR := "res://build/story-script/"
## 目次を置く所（GitHub で game/story/ を開くと、下に出る）。
const INDEX := "res://game/story/README.md"
## きっかけ（battle_cues.gd）の読み方。陣営ごとのものは [人の軍, 敵の軍]。
const CUE_WORDS := {
	BattleCues.KING_HALF: ["味方の将の HP が半分を切ったら", "敵の将の HP が半分を切ったら"],
	BattleCues.FALLEN: ["味方の駒が初めて倒れたら", "敵の駒が初めて倒れたら"],
	BattleCues.ULT_READY: ["味方の必殺技のゲージがたまったら", "敵の必殺技のゲージがたまったら"],
	BattleCues.RELIC: ["味方が聖遺物を受け取ったら", "敵が聖遺物を受け取ったら"],
}
const SIDE_WORDS := ["味方", "敵"]


## 目次（Markdown）。物語ごとに、話の順に、話の名前と話のファイルへのリンク。
## 持つのは話の並びと名前だけ（敵や勝ち方は写さない。話を足す・並べ替える・名前を変えたときだけ作り直す）。
static func index_text() -> String:
	var lines: PackedStringArray = []
	lines.append("# ストーリーの台本")
	lines.append("")
	lines.append("<!-- 生成物。手で書かない。話を足す・並べ替える・名前を変えたら `tools/write_story_script.sh` で作り直す。 -->")
	lines.append("")
	lines.append("話の順に並べた目次。会話は、それぞれの話のファイルにそのまま書いてある（ここには写さない）。")
	lines.append("")
	lines.append("- `[before]`: 対戦の前の会話。`[after]`: 勝ったあとの会話。`[lost]`: 負けたときの台詞（決着の画面に出す）。1 行が「話し手: 文」（頭が `>` の行は地の文）。")
	lines.append("- `[cues]`: 対戦の途中の台詞。頭の括弧が出るとき（`(turn 3)` はターン 3 の始め、`(fallen ally)` は味方が初めて倒れたとき、")
	lines.append("  `(king_half enemy)` は敵の将の HP が半分を切ったとき、`(ult_ready ally)` は必殺技が使えるようになったとき）。")
	lines.append("- 頭の `[episode]` は話の名前・マップ・勝ち方、`[cast]` は話し手（`ally` が遊ぶ人の軍、`enemy` が敵の軍。後ろは会話に立つ姿）。")
	lines.append("- 「ここから下は、戦いの設定」の線より下は、部隊・初期位置・クリアで増えるもの（書式は `docs/story.md` の「話のファイル」）。")
	lines.append("- 物語を足すときは、`_template/` のフォルダを写す（`docs/story.md` の「物語を 1 つ足す」）。")
	lines.append("- 登場人物は `docs/story.md` の「世界と登場人物」。")
	for campaign: Campaign in Story.campaigns():
		lines.append("")
		lines.append("## %s（%s）" % [campaign.title, Names.army(campaign.army)])
		lines.append("")
		lines.append("物語のファイル: [%s](%s)" % [campaign.path.trim_prefix("res://game/story/"), campaign.path.trim_prefix("res://game/story/")])
		lines.append("")
		for at in campaign.episodes.size():
			var episode: Episode = campaign.episodes[at]
			var drill := "（演習）" if episode.lesson != "" else ""
			lines.append("%d. %s[%s](%s)" % [at + 1, drill, episode.title, episode.path.trim_prefix("res://game/story/")])
	lines.append("")
	return "\n".join(lines)


## 物語 campaign の台本を置くファイル。
static func path_of(campaign: Campaign) -> String:
	return DIR + String(campaign.id) + ".md"


## 物語 campaign の台本（Markdown）。
static func text_of(campaign: Campaign) -> String:
	var lines: PackedStringArray = []
	lines.append("# %s" % campaign.title)
	lines.append("")
	lines.append("ストーリーの会話を、遊ばずに通しで読むための台本。人が使う軍は %s、全 %d 話。" % [Names.army(campaign.army), campaign.episodes.size()])
	lines.append("話のファイル（`game/story/<物語>/`）から作った写しで、コミットしない。直すのは話のファイル。")
	lines.append("")
	var given := Story.starting(campaign)
	for episode: Episode in campaign.episodes:
		_episode(lines, campaign, episode, given)
		given.add(episode)
	return "\n".join(lines)


static func _episode(lines: PackedStringArray, campaign: Campaign, episode: Episode, given: Story.Unlocked) -> void:
	var number := campaign.episodes.find(episode) + 1
	lines.append("## 第 %d 話%s　%s" % [number, "（演習）" if episode.lesson != "" else "", episode.title])
	lines.append("")
	lines.append("- 話のファイル: `%s`" % episode.path.trim_prefix("res://"))
	lines.append("- マップ: %s" % episode.map_title)
	# 勝ち方の文（出撃準備と同じ）の 1 行目。2 行目は負け方で、どの話も同じ。
	var goal := WinText.of_scenario(StoryBattle.scenario_of(episode), Unit.Side.PLAYER1)
	lines.append("- 勝ち方: %s" % goal.get_slice("\n", 0))
	lines.append("- 敵: %s" % _enemy(episode))
	if episode.lesson != "":
		lines.append("- 覚えること: %s" % episode.lesson)
	lines.append("- 話し手: %s" % "、".join(_cast(episode)))
	lines.append("")
	lines.append("### 対戦の前")
	lines.append("")
	_talk(lines, episode, episode.before)
	if not episode.cues.is_empty():
		lines.append("### 対戦の途中")
		lines.append("")
		for cue: Episode.TalkCue in episode.cues:
			lines.append("- （%s）**%s**　%s" % [_cue_word(cue), cue.line.speaker_in(episode.speakers), cue.line.shown_text()])
		lines.append("")
	lines.append("### 対戦のあと")
	lines.append("")
	_talk(lines, episode, episode.after)
	if not episode.lost.is_empty():
		lines.append("### 負けたとき（決着の画面）")
		lines.append("")
		_talk(lines, episode, episode.lost)
	var news := given.news_of(episode)
	if not news.is_empty():
		lines.append("クリアで増えるもの:")
		lines.append("")
		for row: Dictionary in news:
			lines.append("- %s" % row["text"])
		lines.append("")


static func _talk(lines: PackedStringArray, episode: Episode, rows: Array[Episode.TalkLine]) -> void:
	for row in rows:
		if row.is_narration():
			lines.append("- *%s*" % row.shown_text())
		else:
			lines.append("- **%s**　%s" % [row.speaker_in(episode.speakers), row.shown_text()])
	lines.append("")


## 話し手の一覧（「隊長（味方・将）」。味方が先。姿は駒の名前、進化後の形なら「進化後」を添える）。台詞の無い話し手は並べない。
static func _cast(episode: Episode) -> PackedStringArray:
	var talks := {}
	for row: Episode.TalkLine in episode.before + episode.after + episode.lost:
		talks[row.who] = true
	for cue: Episode.TalkCue in episode.cues:
		talks[cue.line.who] = true
	var cast: PackedStringArray = []
	for side in 2:
		for who in episode.speakers.size():
			if episode.speaker_sides[who] == side and talks.has(who):
				var figure: Dictionary = episode.figures[who]
				var shape := Names.kind(figure["kind"]) + ("・進化後" if figure.get("evolved", false) else "")
				cast.append("%s（%s・%s）" % [episode.speakers[who], SIDE_WORDS[side], shape])
	return cast


## 敵の軍と顔ぶれ（「FANTASY（将と 3 体: パラディン 2、ソーサラー）」。将のいない群れは「将なし、」）。
static func _enemy(episode: Episode) -> String:
	var counts := {}
	for row: Array in episode.enemy:
		counts[row[0]] = counts.get(row[0], 0) + 1
	var parts: PackedStringArray = []
	for kind: UnitKind.Id in counts:
		parts.append(Names.kind(kind) if counts[kind] == 1 else "%s %d" % [Names.kind(kind), counts[kind]])
	var leader := "将と " if episode.enemy_king else "将なし、"
	return "%s（%s%d 体: %s）" % [Names.army(episode.enemy_army), leader, episode.enemy.size(), "、".join(parts)]


static func _cue_word(cue: Episode.TalkCue) -> String:
	if cue.trigger == BattleCues.TURN:
		return "対戦の始め" if cue.value == 1 else "ターン %d の始め" % cue.value
	return CUE_WORDS[cue.trigger][cue.value]
