extends RefCounted
## 話の場面 1 つ（話は、場面の列 episode.gd の scenes を順に通す。docs/story.md の「場面の列」）。ノードに依存しない。
## 話の流れ（story.gd の run_of）、台本・声・折り返しの道具、自動の対戦、テストは、この列を順に読む。
##
## いまの話のファイルからは、どの話も 出撃準備 → 会話（[before]）→ 対戦 → 会話（[after]）の 4 つ（episode.gd の _build_scenes）。
## 場面の種類を足すときは、Kind に足し、run_of がその種類を流れ（run.gd）のどの場面にするかを足す（docs/story.md）。

const TalkLine := preload("res://game/episode/talk_line.gd")
const StoryScene := preload("res://game/episode/story_scene.gd")

## 場面の種類。
enum Kind {
	SORTIE,  ## 出撃準備（部隊と初期位置を決める。sortie_screen.gd）
	TALK,  ## 会話（talk_screen.gd）
	BATTLE,  ## 対戦（battle_screen.gd。決着の画面を含む。途中の台詞 [cues] と負けたときの台詞 [lost] は、この場面のもの）
}

var kind := Kind.TALK
## 話のファイルのどの節から来たか（"before"・"after" など。道具が見出しと書き間違いの場所に使う。対戦・出撃準備は空）。
var part := ""
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
