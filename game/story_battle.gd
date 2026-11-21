extends "res://game/battle_source.gd"
## ストーリーの 1 話の対戦（docs/story.md）。対戦の画面に渡すもの（battle_source.gd）。
## 話（episode.gd。game/story/<物語>/ の 1 ファイル）から、戦いの定義（手で作ったマップ、決め打ちの敵）を持った対戦設定を作る。
##
## 人はいつもプレイヤー1（先手）で、渡された部隊（story.gd が、いま雇える駒で組む）。敵はプレイヤー2 で、CPU が動かす。
## 選び直せるものは無い（マップ、相手、対戦設定のパネル）。やり直しは「同じマップで再戦」と、出撃準備へ戻る「部隊を選び直す」。
## 人が勝ったら、決着の画面に「次へ」を出し（流れの次の場面、あとの会話へ）、話をクリアしたと書く。
## ここはノードに依存しない（テストから呼べる）。

const Episode := preload("res://game/episode.gd")

## 話（episode.gd）。
var episode: Episode
## 人の部隊。
var human_deck: Deck
## 人が出撃準備で決めた初期位置（本陣からのずれ。部隊の並びの順。空ならいつもの置き方。MatchSetup.placements）。
var placement: Array[Vector2i] = []


func _init(of_episode: Episode = null, deck: Deck = null) -> void:
	episode = of_episode
	human_deck = deck


func make_setup(battle_seed: int) -> MatchSetup:
	# 敵の部隊は戦いの定義が決め打ちにしているので、CPU の編成は作られない（MatchSetup.on_scenario）。
	var setup := MatchSetup.on_scenario(scenario(), battle_seed, Unit.Side.PLAYER1, human_deck)
	setup.placements[Unit.Side.PLAYER1] = placement.duplicate()
	return setup


## 話の戦いの定義（種に依らない。マップ、決め打ちの敵、初期位置、勝ち方）。出撃準備も、勝ち方と敵の部隊をここから読む。
func scenario() -> Scenario:
	return scenario_of(episode)


func look() -> StringName:
	return episode.look


## 話のファイルの music があれば、その曲（守り切る話の緊迫した曲など）。無ければ、盤の見た目の曲。
func music() -> StringName:
	return episode.battle_music()


## 終盤の曲は、話のファイルの climax_music（無ければ、いつもの終盤の曲）。
func climax_music() -> StringName:
	return episode.climax_music if episode.climax_music != &"" else SoundCatalog.CLIMAX_MUSIC


## 勝ったときの調子は、話のファイルの victory_mood（暗い話は静か）。
func victory_mood() -> StringName:
	return episode.victory_mood


## 決着の曲のあとは、その話のあとの会話の曲（「次へ」で、そのまま会話へつながる）。
func after_result_music() -> StringName:
	return episode.after_talk_music()


func can_continue(won: bool) -> bool:
	return won


## 負けたら（引き分けも）、Enter は「同じマップで再戦」（話を進めるには勝つしかないので、まずはそのまま挑み直す）。
func retries_on_enter(won: bool) -> bool:
	return not won


## 決着の画面の、流れの外への行き先は話の一覧。
func leave() -> Array:
	return [&"episodes", "result.to_episodes"]


## 決着の画面に「部隊を選び直す」を出すか（部隊が決まっている話は出さない）。
func can_choose_squad() -> bool:
	return not episode.has_squad()


## 話のファイルの [enemy] の king_figure（敵の将の姿。魔物の群れを率いる骸骨の将など）。
func king_looks() -> Array[StringName]:
	return episode.king_looks


## 話のファイルの [cues]（いつ・だれが・何と言うか）。無い話は台詞なし。
func talk_cues() -> RefCounted:
	if episode.cues.is_empty():
		return BattleCues.new()
	return BattleCues.new(episode.cues, episode.speakers, episode.figures)


## 話のファイルの [lost]（負けたときの台詞）。無い話は無し。
func lost_lines() -> Array[BattleCues.Line]:
	var lines: Array[BattleCues.Line] = []
	for row: Array in episode.lost:
		lines.append(BattleCues.Line.new(row[0], episode.speakers[row[2]], row[1], episode.figures[row[2]]))
	return lines


func record_win(context: RefCounted) -> void:
	if context != null and context.story != null:
		context.story.clear(episode.id)


func copy() -> RefCounted:
	var other: RefCounted = get_script().new(episode, human_deck)
	other.placement = placement.duplicate()
	return other


## 話 of_episode の戦いの定義（種に依らない）。
static func scenario_of(of_episode: Episode) -> Scenario:
	var defined := Scenario.on_map(of_episode.map, of_episode.map_title)
	defined.fix_deck(Unit.Side.PLAYER2, of_episode.enemy_deck())
	# 将のいない群れ（[enemy] の king = none。docs/scenario.md）。
	if not of_episode.enemy_king:
		defined.remove_king(Unit.Side.PLAYER2)
	# 人の部隊が決まっている話（[ally] の unit。チュートリアル）は、出撃準備で選んだ部隊のかわりに、それを置く。
	if of_episode.has_squad():
		defined.fix_deck(Unit.Side.PLAYER1, of_episode.squad_deck())
	defined.set_start_gauge(Unit.Side.PLAYER1, of_episode.start_gauge)
	# 駒の始めのレベルと経験値（駒の行の「level」「exp」。進化の選び方を教える話）。
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if of_episode.has_growth(side):
			defined.set_start_growth(side, of_episode.growth[side])
	# 初期位置（話のファイルの deploy。空の列は、いつもの「本陣の前」）。
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var cells: Array[Vector2i] = []
		cells.assign(of_episode.deploy[side])
		if not cells.is_empty():
			defined.set_deploy_cells(side, cells)
	# 勝ち方（docs/win-conditions.md）。hold_turns があれば、人がそのターン数を守り切れば勝ち。
	if of_episode.hold_turns > 0:
		defined.hold_for(Unit.Side.PLAYER1, of_episode.hold_turns)
	# wins があれば、人の勝ち方はその列だけ（たとえば全滅だけ。敵の将を倒しても終わらない）。
	if not of_episode.wins.is_empty():
		defined.set_win_conditions(Unit.Side.PLAYER1, of_episode.wins)
	return defined
