extends RefCounted
## 話の場面 1 つ（話は、場面の列 episode.gd の scenes を順に通す。docs/story.md の「場面の列」）。ノードに依存しない。
## 話の流れ（story.gd の run_of）、台本・声・折り返しの道具、自動の対戦、テストは、この列を順に読む。
##
## 話のファイルの書き方は 2 つ（episode.gd の _build_scenes）: [before]・[after] の話は 出撃準備 → 会話 → 対戦 → 会話 の 4 つ。
## 場面の節（[talk 名前]・[sortie]・[battle]）で書いた話は、書いた順（game/episode/episode_scenes.gd）。
## 場面の種類を足すときは、Kind に足し、run_of がその種類を流れ（run.gd）のどの場面にするかを足す（docs/story.md）。

const TalkLine := preload("res://game/episode/talk_line.gd")
const StoryScene := preload("res://game/episode/story_scene.gd")

## カットシーンの色の幕に書ける名前（色は talk_screen.gd が決める）。
const COLORS: Array[StringName] = [&"black", &"night"]

## 場面の種類。
enum Kind {
	SORTIE,  ## 出撃準備（部隊と初期位置を決める。sortie_screen.gd）
	TALK,  ## 会話（talk_screen.gd）
	BATTLE,  ## 対戦（battle_screen.gd。決着の画面を含む。途中の台詞 [cues] と負けたときの台詞 [lost] は、この場面のもの）
}

var kind := Kind.TALK
## 話のファイルのどの節から来たか（"before"・"after"・"talk 兵舎" など。道具が見出しと書き間違いの場所に使う。対戦・出撃準備は空）。
var part := ""
## 場面の名前（[talk 名前] の名前。台本の見出しに出す。[before]・[after] の会話は空）。
var name := ""
## 背景にする別の場所（手で作ったマップ。[talk 名前] の place）。null なら、話の盤（兵を立たせる）。
var place: HandMap
## 背景の見た目（place のマップの見た目か、場面の look。place が無ければ空 = 話の盤の見た目）。
var look := &""
## カットシーンか（[cut 名前]。地の文だけの場面。話し手も文の枠も出さず、背景の上に文を真ん中に出す。docs/story.md の「カットシーン」）。
var cut := false
## カットシーンの背景を、景色でなく色の幕にするなら、その名前（COLORS の鍵。空なら景色）。
var color := &""
## 曲を、話のファイルが選んで書いたか（検査が、どの会話にも曲を選んであることを確かめる）。
var music_written := false
## 会話の行（TALK だけ）。
var lines: Array[TalkLine] = []
## 曲（TALK だけ。空なら場面の表の曲）。
var music := &""
## 1 度通り過ぎたら、前後へ動くときに飛ばす（run.gd の once。対戦の前の会話は、出撃準備へ戻って出撃し直しても、もう出さない）。
var once := false


static func sortie() -> StoryScene:
	var scene := StoryScene.new()
	scene.kind = Kind.SORTIE
	return scene


static func battle() -> StoryScene:
	var scene := StoryScene.new()
	scene.kind = Kind.BATTLE
	return scene


## 会話の場面: 節 from_part の行 talk_lines を、曲 track で。
static func talk(from_part: String, talk_lines: Array[TalkLine], track: StringName, only_once := false) -> StoryScene:
	var scene := StoryScene.new()
	scene.kind = Kind.TALK
	scene.part = from_part
	scene.lines = talk_lines
	scene.music = track
	scene.once = only_once
	return scene


func is_talk() -> bool:
	return kind == Kind.TALK


func is_battle() -> bool:
	return kind == Kind.BATTLE
