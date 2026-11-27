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

## 話のファイルを置く所（ファイルの名前が話の id）。
## 書ける節。
const SECTIONS := ["episode", "cast", "before", "cues", "after", "lost", "ally", "enemy", "unlock"]
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


## 対戦の曲（無ければ、盤の見た目の曲）。
func battle_music() -> StringName:
	return music if music != &"" else SoundCatalog.battle_music(look)


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
