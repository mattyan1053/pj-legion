extends RefCounted
## ストーリー（game/story.gd）の土台: 物語と話の一覧（game/story/ から読む）。ノードに依存しない。静的な関数だけ。
## 継ぐ順: story_catalog.gd（物語と話の一覧）→ story_record.gd（記録と進み具合）→ story_unlocks.gd（解放と既定の編成）→ game/story.gd（話の流れ）。
## 外からは、どれも Story.xxx で呼ぶ（const Story := preload("res://game/story.gd")）。
##
## - 物語は、軍 1 つと話の列（game/story/ の 1 フォルダ。campaign.gd）。物語のファイル（story.txt）の order の順に並ぶ。物語を選んでから、その物語の話を選ぶ。
## - 話は物語の中で一本道（game/story/<物語>/ の 1 ファイル。episode.gd）。物語の [episodes] の順に並ぶ（一本道の前提は docs/story.md の「話の一本道」）。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const DeckText := preload("res://game/deck_text.gd")
const HeroName := preload("res://game/hero_name.gd")
const Run := preload("res://game/run.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const Campaign := preload("res://game/campaign.gd")
const Episode := preload("res://game/episode.gd")
const TalkScene := preload("res://game/talk_scene.gd")

## 最初の物語の id。版 1 の記録（物語が 1 つだったころ）は、この物語の記録として読む。
const MILITARY_ID := &"military"

## 読み込んだ物語の並び（最初に使うときに game/story/ から読む）と、読み込みの書き間違い。
static var _campaigns: Array[Campaign] = []
static var _problems: PackedStringArray = []
static var _loaded := false


## 物語の並び（物語のファイルの order の順）。話の無い物語は「準備中」で、選べない。
## 書き間違いのある話は並ばない（読み込みの書き間違いは load_problems() と、エラーの出力）。
static func campaigns() -> Array[Campaign]:
	if not _loaded:
		_loaded = true
		var found: Dictionary = Campaign.load_all()
		_campaigns.assign(found["campaigns"])
		_problems = found["problems"]
		for each: Campaign in _campaigns:
			_problems.append_array(each.problems)
		for problem: String in _problems:
			push_error("ストーリーのデータの書き間違い: " + problem)
	return _campaigns


## 物語と話のファイルの書き間違い（空なら正しい。test_episode_data.gd が見る）。
static func load_problems() -> PackedStringArray:
	campaigns()
	return _problems


## 物語 id（無ければ null）。
static func campaign_by_id(id: StringName) -> Campaign:
	for each: Campaign in campaigns():
		if each.id == id:
			return each
	return null


## 最初の物語（MILITARY の物語）。
static func military() -> Campaign:
	return campaign_by_id(MILITARY_ID)


## 軍 army の物語（並びの最初のもの。無ければ null）。
static func campaign_of_army(army: UnitKind.Army) -> Campaign:
	for each: Campaign in campaigns():
		if each.army == army:
			return each
	return null


## 物語 of_campaign を遊べるか（話が 1 つ以上ある）。話の無い物語は「準備中」。
static func is_ready(of_campaign: Campaign) -> bool:
	return of_campaign.is_ready()


## 話 episode の物語（どの物語にも無ければ null）。
static func campaign_of(episode: Episode) -> Campaign:
	for each: Campaign in campaigns():
		if each.episodes.has(episode):
			return each
	return null


## どの物語の話も、物語の順・話の順に並べたもの。
static func all_episodes() -> Array[Episode]:
	var episodes: Array[Episode] = []
	for each: Campaign in campaigns():
		episodes.append_array(each.episodes)
	return episodes


## 話 episode の、その物語の並びの番号（1 から。どの物語にも無ければ 0）。
static func number_of(episode: Episode) -> int:
	var of_campaign := campaign_of(episode)
	return 0 if of_campaign == null else of_campaign.episodes.find(episode) + 1


## 物語 of_campaign の、背景に景色を見せる話（物語選択・セーブデータ選択。title_backdrop.gd の show_story）:
## クリアしたいちばん先の話 last の次の話（last が最後の話ならそれ。last が無ければ最初の話）。
static func scape_episode(of_campaign: Campaign, last: Episode) -> Episode:
	if last == null:
		return of_campaign.episodes[0]
	var at := of_campaign.episodes.find(last)
	return of_campaign.episodes[mini(at + 1, of_campaign.episodes.size() - 1)]


## 物語の並びで episode の次の話（物語の最後なら null）。
static func episode_after(episode: Episode) -> Episode:
	var of_campaign := campaign_of(episode)
	if of_campaign == null:
		return null
	var at := of_campaign.episodes.find(episode)
	return of_campaign.episodes[at + 1] if at >= 0 and at + 1 < of_campaign.episodes.size() else null
