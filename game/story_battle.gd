extends "res://game/battle_source.gd"
## ストーリーの 1 話の対戦（docs/story.md）。対戦の画面に渡すもの（battle_source.gd）。
## 話のデータ（game/episodes/ の 1 ファイル）から、戦いの定義（手で作ったマップ、決め打ちの敵）を持った対戦の設定を作る。
##
## 人はいつもプレイヤー1（先手）で、渡された部隊（story.gd が、いま雇える駒で組む）。敵はプレイヤー2 で、CPU が動かす。
## 選び直せるものは無い（ステージ、相手、対戦の設定のパネル）。やり直しは「同じ盤面でもう一度」と、出撃の準備へ戻る「部隊を選び直す」。
## 人が勝ったら、決着の画面に「次へ」を出し（流れの次の場面、あとの会話へ）、話をクリアしたと書く。
## ここはノードに依存しない（テストから呼べる）。

## 話のデータ（game/episodes/ の 1 ファイル）。
var episode: Script
## 人の部隊。
var human_deck: Deck


func _init(of_episode: Script = null, deck: Deck = null) -> void:
	episode = of_episode
	human_deck = deck


func make_setup(battle_seed: int) -> MatchSetup:
	# 敵の部隊は戦いの定義が決め打ちにしているので、CPU の編成は作られない（MatchSetup.on_scenario）。
	return MatchSetup.on_scenario(scenario(), battle_seed, Unit.Side.PLAYER1, human_deck)


## 話の戦いの定義（種に依らない。マップ、決め打ちの敵、初期位置、勝ち方）。出撃の準備も、勝ち方と敵の部隊をここから読む。
func scenario() -> Scenario:
	return scenario_of(episode)


func look() -> StringName:
	return episode.LOOK


## 話のデータの MUSIC があれば、その曲（守り切る話の緊迫した曲など）。無ければ、盤の見た目の曲。
func music() -> StringName:
	return music_of(episode)


func can_continue(won: bool) -> bool:
	return won


## 負けたら（引き分けも）、Enter は「同じ盤面でもう一度」（話を進めるには勝つしかないので、まずはそのまま挑み直す）。
func retries_on_enter(won: bool) -> bool:
	return not won


func can_choose_squad() -> bool:
	return true


## 話のデータの CUES（いつ・だれが・何と言うか）。無い話は台詞なし。
func talk_cues() -> RefCounted:
	var cues := cues_of(episode)
	if cues.is_empty():
		return BattleCues.new()
	return BattleCues.new(cues, episode.SPEAKERS)


func record_win(context: RefCounted) -> void:
	if context != null and context.story != null:
		context.story.clear(episode.ID)


func copy() -> RefCounted:
	return get_script().new(episode, human_deck)


## 話 of_episode の戦いの定義（種に依らない）。
static func scenario_of(of_episode: Script) -> Scenario:
	var defined := Scenario.on_map(of_episode.MAP.map(), of_episode.MAP.TITLE)
	defined.fix_deck(Unit.Side.PLAYER2, enemy_deck_of(of_episode))
	# 初期位置（話のデータの DEPLOY。[プレイヤー1 のマスの列, プレイヤー2 のマスの列]。空の列は、いつもの「本陣の前」）。
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var cells: Array[Vector2i] = []
		cells.assign(of_episode.DEPLOY[side])
		if not cells.is_empty():
			defined.set_deploy_cells(side, cells)
	# 勝ち方（docs/win-conditions.md）。HOLD_TURNS があれば、人がそのターン数を守り切れば勝ち。
	var hold := hold_turns_of(of_episode)
	if hold > 0:
		defined.hold_for(Unit.Side.PLAYER1, hold)
	# WINS があれば、人の勝ち方はその列だけ（たとえば全滅だけ。敵の将を倒しても終わらない）。
	var wins := wins_of(of_episode)
	if not wins.is_empty():
		defined.set_win_conditions(Unit.Side.PLAYER1, wins)
	return defined


## 話 of_episode の敵の部隊（話のデータの ENEMY_ARMY と ENEMY から。決め打ち。編成の決まりの検査は通さない。docs/scenario.md）。
static func enemy_deck_of(of_episode: Script) -> Deck:
	var deck := Deck.new(of_episode.ENEMY_ARMY)
	for row: Array in of_episode.ENEMY:
		var entry := DeckEntry.new(row[0])
		for item: Equipment.Id in row[1]:
			entry.equip(item)
		deck.entries.append(entry)
	return deck


# ---- 話のデータの、無くてもよい定数の読み口（docs/story.md の「話のデータ」） ----
# 話のデータを読む側（画面、自動の対戦、スクリーンショットの道具、テスト）は、定数の有る無しを自分で調べず、ここを通す。
# 既定の値（無い話の値）も、ここだけに持つ。


## 人が守り切るターン数（HOLD_TURNS）。無い話は 0（守り切るは無い）。
static func hold_turns_of(of_episode: Script) -> int:
	return _constant(of_episode, &"HOLD_TURNS", 0)


## 人の勝ち方の列（WINS）。無い話は空（いつもの勝ち方のまま）。
static func wins_of(of_episode: Script) -> Array[GameWonEvent.Reason]:
	var wins: Array[GameWonEvent.Reason] = []
	wins.assign(_constant(of_episode, &"WINS", []))
	return wins


## 対戦の途中の会話（CUES）。無い話は空（台詞なし）。
## 話のクリアで、新しく持たせられるようになる装備（UNLOCK_ITEMS。無ければ空）。
static func unlock_items_of(of_episode: Script) -> Array[Equipment.Id]:
	var items: Array[Equipment.Id] = []
	items.assign(_constant(of_episode, &"UNLOCK_ITEMS", []))
	return items


## 話のクリアで、部隊のコストの上限が上がる量（BUDGET_UP。無ければ 0）。
static func budget_up_of(of_episode: Script) -> int:
	return _constant(of_episode, &"BUDGET_UP", 0)


static func cues_of(of_episode: Script) -> Array:
	return _constant(of_episode, &"CUES", [])


## 話 of_episode の対戦の曲（MUSIC。無ければ、盤の見た目 LOOK の曲）。
static func music_of(of_episode: Script) -> StringName:
	var track: StringName = _constant(of_episode, &"MUSIC", &"")
	return track if track != &"" else SoundCatalog.battle_music(of_episode.LOOK)


## 話 of_episode の会話の場面の曲（TALK_MUSIC）。無ければ空（場面の表の曲。scene_flow.gd の talk）。
static func talk_music_of(of_episode: Script) -> StringName:
	return _constant(of_episode, &"TALK_MUSIC", &"")


static func _constant(of_episode: Script, name: StringName, fallback: Variant) -> Variant:
	return of_episode.get_script_constant_map().get(name, fallback)
