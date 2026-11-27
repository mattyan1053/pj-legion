extends RefCounted
## 話（game/episode.gd）の土台: 読み込み、調整値（文の長さの上限など）、読んだ値の変数と、読んだ値から作るもの（部隊、曲）。
## 継ぐ順: episode_base.gd → episode_sides.gd（[ally]・[enemy]）→ episode_talks.gd（[cast]・会話・[cues]）→ game/episode.gd（読む入口、[episode]・[unlock]）。

const StoryFile := preload("res://game/story_file.gd")
const StageLook := preload("res://game/stage_look.gd")
const SoundCatalog := preload("res://game/sound_catalog.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const Maps := preload("res://game/maps.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const UnitLooks := preload("res://game/unit_looks.gd")
const TalkLine := preload("res://game/episode/talk_line.gd")
const TalkCue := preload("res://game/episode/talk_cue.gd")
const StoryScene := preload("res://game/episode/story_scene.gd")
const Names := preload("res://game/names.gd")
const HeroName := preload("res://game/hero_name.gd")

## 話のファイルを置く所（ファイルの名前が話の id）。
## 書ける節。
const SECTIONS := ["episode", "cast", "before", "cues", "after", "lost", "ally", "enemy", "unlock"]
## 場面の節（書いた順が、場面の順。game/episode/episode_scenes.gd）: 「[talk 名前]」（会話。名前は話の中で重ならない）、[sortie]（出撃準備）、[battle]（対戦）。
## 1 つでも書いた話は、[before]・[after] を書かない。
const TALK_SECTION := "talk "
const SCENE_MARKS := ["sortie", "battle"]
## 選択肢（docs/story.md の「選択肢」）: 答えの数、答えの文の長さの上限（選ぶ枠のボタンに 1 行で収まる）、名前と鍵に使える字。
const OPTIONS_MIN := 2
const OPTIONS_MAX := 3
const OPTION_MAX_CHARS := 22
const CHOICE_WORD := "^[a-z][a-z0-9_]*$"
## 場面の節で書く話の、会話の場面の数の上限。
const TALK_SCENES_MAX := 8
## 会話（前と後）の行の数の上限、対戦の途中の台詞の数と文の長さの上限、出撃準備に出す覚えることの長さの上限。
const TALK_MAX_LINES := 10
## 会話（前と後）の 1 行の文の長さの上限（会話の場面の文の枠に 2 行で収まる）。
const TALK_MAX_CHARS := 60
const CUES_MAX := 3
## 負けたときの台詞（[lost]。決着の画面に出す）の行の数と、1 行の文の長さの上限。
const LOST_MAX_LINES := 3
const LOST_MAX_CHARS := 40
const CUE_MAX_CHARS := 40
const LESSON_MAX_CHARS := 48
## 会話の行の話し手の陣営（0 = 人の軍、1 = 敵の軍）。きっかけの値の陣営も同じ言葉で書く。
const SIDE_WORDS := {"ally": 0, "enemy": 1}
## 地の文（話し手のいない行。場面の説明や時間の経過）の陣営。話し手の番号は -1。会話の行の頭に NARRATION_MARK（全角の「＞」でもよい）を付けて書く。
## 会話の場面では、名前の札を出さず、文を真ん中に明朝で出す（talk_screen.gd）。
const NARRATION_SIDE := TalkLine.NARRATION_SIDE
const NARRATION_MARK := ">"

## 話の id（クリアの記録に書く。変えると記録が外れる）。ファイルの名前と同じ。
var id := &""
## 会話の見出しと、話の一覧のカードに出す名前。
var title := ""
## 盤（手で作ったマップ）と、その名前（戦いの定義の名前。決着の画面の「マップ」）。
var map: HandMap
var map_title := ""
## 盤の見た目（stage_look.gd の THEMES の鍵）。マップの見た目（マップのファイルの look）。話のファイルが look を書けば、それ。
var look := &""
## 対戦の曲（無ければ空。battle_music が盤の見た目の曲にする）。
var music := &""
## 前の会話と、あとの会話の曲（無ければ空。before_talk_music・after_talk_music が既定を決める）。
var before_music := &""
var after_music := &""
## 終盤の曲（無ければ空 = いつもの終盤の曲。sound_catalog.gd の CLIMAX_MUSIC）。
var climax_music := &""
## 勝ったときの調子（sound_catalog.gd の MOOD_BRIGHT か MOOD_QUIET。無ければ明るい）。静かなら、ファンファーレを鳴らさない。
var victory_mood := SoundCatalog.MOOD_BRIGHT
## 出撃準備に出す、この話で覚えること（チュートリアルだけ。無ければ空）。
var lesson := ""
## クリアで増えるもの: 雇える駒、持たせられる装備、部隊のコストの上限の上がり幅。
var unlock_kinds: Array[UnitKind.Id] = []
var unlock_items: Array[Equipment.Id] = []
## クリアで選べるようになる軍略（Traits.Id。ストーリー用の部隊が出撃準備で持てる。docs/story.md の「解放」）。
var unlock_traits: Array[int] = []
var budget_up := 0
## 人（プレイヤー1）の勝ち方: 守り切るターン数（0 なら無し）と、勝ち方の列（空ならいつもの勝ち方）。
var hold_turns := 0
var wins: Array[GameWonEvent.Reason] = []
## 中ボスの名前（[episode] の boss。無ければマップのファイルの boss。どちらも無ければ空 = 既定の「番人」）。
var boss := ""
## この話の縫い目の様子（Seam.Sign の並び。空なら付かない。docs/seam-signs.md）。[episode] の signs。
var signs: Array[int] = []
## 人の部隊が決まっている話の、その部隊（[駒の種類, [装備, …]] の列。空なら出撃準備で選ぶ）と、必殺技のゲージの始めの量。
var squad: Array = []
var start_gauge := 0
## 敵の軍と部隊（将を除く。[駒の種類, [装備, …]] の列。並びの順に初期位置へ置く）。
## 軍が none（Army.NONE）なら、敵は軍に属さない（必殺技もゲージも無い）。魔物の群れの話に使う（docs/story.md）。
var enemy_army := UnitKind.Army.FANTASY
## 敵に将を置くか（[enemy] の king = none で偽。将のいない群れ。docs/scenario.md）。
var enemy_king := true
## 敵の側が番人（中ボス）を狙わないか（[enemy] の spare_boss = yes。Battle.spares_bosses。docs/story.md）。
var enemy_spares_boss := false
var enemy: Array = []
## 陣営の呼び名: [人の軍, 敵の軍]（[ally] / [enemy] の name。Names.STORY_NAME_MAX 字まで）。空なら軍の既定の呼び名（story_battle.gd の side_names）。
var side_names: Array[String] = ["", ""]
## 陣営の短い呼び名（[ally] / [enemy] の short。上の帯の陣営の欄とログ。Names.STORY_SHORT_MAX 字まで）。空なら、呼び名が短ければ呼び名、長ければ軍の既定。
var side_shorts: Array[String] = ["", ""]
## 陣営ごとの軍略（Traits.Id。書かなければ Traits.NONE = 軍略なし。docs/troop-traits.md）。[ally] / [enemy] の trait。
var traits: Array[int] = [Traits.NONE, Traits.NONE]
## 陣営ごとの誓いの組（その陣営の unit の行の、1 から数えた番号の組を、0 からの Vector2i で。軍略が誓いの陣営だけ）。[ally] / [enemy] の oath。
var oaths: Array[Array] = [[], []]
## 初期位置: [プレイヤー1 のマスの列, プレイヤー2 のマスの列]。空の列は、いつもの「本陣の前」。
var deploy: Array = [[] as Array[Vector2i], [] as Array[Vector2i]]
## 駒の始めのレベルと経験値: [人の部隊の列, 敵の部隊の列]。どちらも [レベル, 経験値] の列で、部隊（squad、enemy）と同じ並び。
## 駒の行に書かなければ [1, 0]（いつもどおり）。戦いの定義の start_growth へ写す（story_battle.gd）。
var growth: Array = [[], []]
## 話し手の名前: [人の軍の主な話し手, 敵の軍の主な話し手, ほかの話し手（書いた順）, …]。[cast] に書く。
## 主な話し手は、その陣営で最初に書いた人。
## 会話と途中の台詞の行は、話し手をこの並びの番号で持つ。
var speakers: PackedStringArray = ["", ""]
## 話し手の陣営（0 = 人の軍、1 = 敵の軍）。speakers と同じ並び。
var speaker_sides: PackedInt32Array = [0, 1]
## 話し手の姿（会話の場面に立たせる駒の形と、対戦の途中の台詞のアイコン）。speakers と同じ並び。
## どれも {"kind": 駒の種類, "evolved": 進化後の形か, "look": 将の別の姿}。書かなければ、その陣営の将の姿。
## [1]（敵の主な話し手）は、話の一覧のカードの顔にも使う。
var figures: Array[Dictionary] = [{"kind": UnitKind.Id.KING, "evolved": false, "look": &""}, {"kind": UnitKind.Id.KING, "evolved": false, "look": &""}]
## 将の姿（見た目だけ。unit_looks.gd の KING_LOOKS の名前。空ならいつもの将）: [人の軍, 敵の軍]。敵の将だけ書ける（[enemy] の king_figure）。
## 盤の将、駒の情報・決着の画面のアイコン、話し手の姿が king のときの姿に使う。ルールの上では将のまま。
var king_looks: Array[StringName] = [&"", &""]
## 対戦の前と後の会話: 会話の行（talk_line.gd。話し手の陣営・文・話し手の番号を名前で読む）の列。
var before: Array[TalkLine] = []
var after: Array[TalkLine] = []
## 負けたときの台詞（無ければ空。決着の画面の見出しの下に出す）。地の文は無い。
var lost: Array[TalkLine] = []
## 対戦の途中の会話: 途中の台詞（talk_cue.gd。きっかけ・値・会話の行）の列（battle_cues.gd）。
var cues: Array[TalkCue] = []
## 場面の列（story_scene.gd）。話の流れ（story.gd の run_of）と、台本などの道具は、これを順に読む。
## いまは、どの話も 出撃準備 → 会話（before）→ 対戦 → 会話（after）（episode.gd の _build_scenes）。
var scenes: Array[StoryScene] = []
## 場面の節（[talk 名前]・[sortie]・[battle]）で書いた話か（偽なら [before]・[after] の話）。
var written_as_scenes := false
## 対戦のある話か（読む間に使う。読んだあとは has_battle()）。
var _fights := true
## 主人公の既定の名前（物語のファイルの hero。物語の読み込みが set_hero で入れる。話のファイルだけを読んだときは空）。
var hero := ""
## この話が選ばせる選択肢: 名前 -> 答えの鍵の列（書いた順）。
var choices := {}
## この話の行が条件に使う選択肢: [{"line": 行, "choice": 名前, "answer": 答えの鍵, "here": この話の、その行より前で選ばせた選択肢か}, …]。
## 物語の読み込み（campaign.gd）が、前の話までに選ばせた選択肢と答えかを確かめる。
var conditions: Array[Dictionary] = []
## 読んだファイルのパスと、書き間違い（空なら正しい）。
var path := ""
var problems: PackedStringArray = []
## 初期位置を書いた行（陣営ごと。書き間違いの文に使う）。
var _deploy_lines := [0, 0]


## 部隊が決まっている話か。
func has_squad() -> bool:
	return not squad.is_empty()


## 決まっている人の部隊（無ければ null）。軍は、最初の駒の軍（話の物語の軍の駒で書く。story.gd の読み込みが確かめる）。
func squad_deck() -> Deck:
	return null if squad.is_empty() else _bound(_deck_of(UnitKind.army(squad[0][0]), squad), 0)


## 敵の部隊（決め打ち。編成の決まりの検査は通さない。docs/scenario.md）。
func enemy_deck() -> Deck:
	return _bound(_deck_of(enemy_army, enemy), 1)


## 決め打ちの部隊 deck に、陣営 side の誓いの組を結ぶ（軍略が誓いの陣営だけ）。
func _bound(deck: Deck, side: int) -> Deck:
	if traits[side] == Traits.Id.OATH:
		for pair: Vector2i in oaths[side]:
			if pair.x < deck.entries.size() and pair.y < deck.entries.size():
				deck.oaths.append([deck.entries[pair.x], deck.entries[pair.y]])
	return deck


## 対戦のある話か（場面の節で書いた話は、[battle] を書かなければ、読むだけの話。読み終えたらクリア）。
func has_battle() -> bool:
	return scenes.any(func(scene: StoryScene) -> bool: return scene.is_battle())


## 対戦の曲（無ければ、盤の見た目の曲）。
func battle_music() -> StringName:
	return music if music != &"" else SoundCatalog.battle_music(look)


## 会話の場面（場面の列の順）。
func talk_scenes() -> Array[StoryScene]:
	var found: Array[StoryScene] = []
	for scene in scenes:
		if scene.is_talk():
			found.append(scene)
	return found


## 対戦の場面の前の最後の会話の場面と、対戦の場面のあとの最後の会話の場面（無ければ null）。検査と道具が、どちらの会話かを見分けるのに使う。
func talk_before_battle() -> StoryScene:
	var found: StoryScene = null
	for scene in scenes:
		if scene.is_battle():
			return found
		if scene.is_talk():
			found = scene
	return found


func talk_after_battle() -> StoryScene:
	var fought := false
	var found: StoryScene = null
	for scene in scenes:
		fought = fought or scene.is_battle()
		if fought and scene.is_talk():
			found = scene
	return found


## 対戦の場面のすぐあとの場面（無ければ null。対戦の無い話や、対戦で終わる話）。
func scene_after_battle() -> StoryScene:
	for i in scenes.size() - 1:
		if scenes[i].is_battle():
			return scenes[i + 1]
	return null


## 話の台詞の全部: 場面の列の順に、会話の場面の行と、対戦の場面の途中の台詞。最後に、負けたときの台詞（台本もこの順）。
## 台本・声・文の検査が読む。
func all_lines() -> Array[TalkLine]:
	var found: Array[TalkLine] = []
	for scene in scenes:
		if scene.is_talk():
			found.append_array(scene.lines)
		elif scene.is_battle():
			for cue in cues:
				found.append(cue.line)
	found.append_array(lost)
	return found


## 主人公の既定の名前を、話と、話の全部の行に入れる（物語の読み込み campaign.gd が呼ぶ）。
func set_hero(name: String) -> void:
	hero = name
	for line in all_lines():
		line.hero = name


## 差し込みの印（HeroName.MARK）を使っている行があるか（主人公のいない物語の話には書けない）。
func uses_hero_mark() -> bool:
	return all_lines().any(func(line: TalkLine) -> bool: return line.text.contains(HeroName.MARK))


## 前の会話の曲（無ければ、対戦の曲。会話の間は小さく鳴らし、そのまま対戦へつながる。docs/sound.md）。
func before_talk_music() -> StringName:
	return before_music if before_music != &"" else battle_music()


## あとの会話の曲（無ければ、落ち着いた曲。sound_catalog.gd の AFTER_TALK_MUSIC）。
func after_talk_music() -> StringName:
	return after_music if after_music != &"" else SoundCatalog.AFTER_TALK_MUSIC


static func _deck_of(army: UnitKind.Army, rows: Array) -> Deck:
	var deck := Deck.new(army)
	for row: Array in rows:
		var entry := DeckEntry.new(row[0])
		for item: Equipment.Id in row[1]:
			entry.equip(item)
		deck.entries.append(entry)
	return deck



## side の部隊に、始めのレベルか経験値を決めた駒がいるか。
func has_growth(side: int) -> bool:
	return growth[side].any(func(row: Array) -> bool: return row != [1, 0])
