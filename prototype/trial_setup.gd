extends RefCounted
## 試作の対戦の設定画面（match_setup_panel.gd）で選ぶもの。選んだものから、ルールの対戦の設定（MatchSetup）を作る。
##
## 選べるのは、両方のプレイヤーの軍、ステージ、相手（人か CPU か）、CPU と対戦するときの人の手番（先手か後手か）。
## 編成は軍ごとの既定の編成（MatchSetup.default_deck。予算どおり）。駒や装備を 1 つずつ選ぶ編成画面は無い。
## ここはノードに依存しない（テストから呼べる）。

var stage := BoardGenerator.Stage.PLAIN
## プレイヤー番号（0 が先手）ごとの軍。
var armies: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
## 相手を CPU が動かすか。偽なら、2 人が 1 台で交代する。
var cpu_opponent := true
## CPU と対戦するときに、人が動かすプレイヤー（PLAYER1 = 先手、PLAYER2 = 後手）。人どうしでは見ない。
var human_side := Unit.Side.PLAYER1


## CPU が動かすプレイヤー（cpu_opponent が偽でも、CPU に切り替えたときに動かすほう）。
func cpu_side() -> Unit.Side:
	return (1 - human_side) as Unit.Side


func copy() -> RefCounted:
	var other: RefCounted = get_script().new()
	other.stage = stage
	other.armies = armies.duplicate()
	other.cpu_opponent = cpu_opponent
	other.human_side = human_side
	return other


## この選択で、種 battle_seed の対戦の設定を作る。
func to_setup(battle_seed: int) -> MatchSetup:
	if cpu_opponent:
		return MatchSetup.versus_cpu(
			stage, battle_seed, MatchSetup.default_deck(armies[human_side]), armies[cpu_side()], human_side
		)
	return MatchSetup.versus_human(
		stage, battle_seed, MatchSetup.default_deck(armies[0]), MatchSetup.default_deck(armies[1])
	)
