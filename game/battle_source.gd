extends RefCounted
## 対戦の画面（battle_screen.gd）に渡す、「対戦設定（MatchSetup）を作ってくれるもの」（docs/battle-source.md）。
## 対戦の画面は、どのモードの対戦かを知らない。対戦を作るのも、やり直すのも、ここに聞く。
##
## ここに書いてあるのは、どれも既定の答え（何も選び直せない対戦）。モードごとに継いで、答えを書き換える。
## いまあるのは、対戦モード（match_choice.gd。対戦設定のパネルで選んだもの）と、ストーリーの 1 話（story_battle.gd）。
## ここはノードに依存しない（テストから呼べる）。

const StageLook := preload("res://game/stage_look.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const SoundCatalog := preload("res://game/sound_catalog.gd")


## 種 battle_seed の対戦設定。対戦の画面は、これの create_battle() で対戦を作る。
## 同じ種なら同じ対戦になる（「同じマップで再戦」）。
func make_setup(_battle_seed: int) -> MatchSetup:
	return null


## 盤の見た目の名前（stage_look.gd の THEMES の鍵）。
func look() -> StringName:
	return StageLook.DEFAULT


## 対戦の曲（sound_catalog.gd の MUSIC の名前）。既定は、盤の見た目の曲。
func music() -> StringName:
	return SoundCatalog.battle_music(look())


## 終盤の曲（どちらかの将の HP が半分を切ったら替わる。sound_catalog.gd の CLIMAX_MUSIC）。
func climax_music() -> StringName:
	return SoundCatalog.CLIMAX_MUSIC


## 人が勝ったときの調子（sound_catalog.gd の MOOD_BRIGHT か MOOD_QUIET）。既定は明るい（ファンファーレを鳴らす）。
func victory_mood() -> StringName:
	return SoundCatalog.MOOD_BRIGHT


## 決着の曲のあとに続ける曲（ループ）。既定は静かな曲（sound_catalog.gd の AFTER_RESULT_MUSIC）。
func after_result_music() -> StringName:
	return SoundCatalog.AFTER_RESULT_MUSIC


## 相手のプレイヤー: CPU が動かすプレイヤー。人どうしなら、相手を CPU に切り替えたときに CPU が動かすほう。
## その反対が、CPU と対戦するときに人が動かすプレイヤー。
func cpu_side() -> Unit.Side:
	return Unit.Side.PLAYER2


## 陣営を遊ぶ人の側から「味方」「敵」と呼ぶか（ストーリー。names.gd の story_sides）。偽なら色とプレイヤーの番号で呼ぶ（対戦モード）。
## 真なら、決着の画面の理由も遊ぶ人の側から書く（「敗北　将が倒れた」。result_summary.gd）。
func story_sides() -> bool:
	return false


## 対戦の途中で、相手を人と CPU で切り替えられるか（F4、下の帯の「相手」のボタン）。
func can_switch_opponent() -> bool:
	return false


## 相手を CPU にするか人にするかを、次に作る対戦設定（make_setup）に覚えておく。切り替えられないなら何もしない。
func set_cpu_opponent(_cpu: bool) -> void:
	pass


## 新しい盤面でやり直すときに選べるマップ（versus_fields.gd の鍵の並び。F1〜F3、決着の画面の「新しいマップ」）。
## 空なら、やり直しは「同じマップで再戦」だけ。
func new_board_fields() -> Array[StringName]:
	return []


## 次に作る対戦設定のマップを field にする（new_board_fields() にあるものだけ）。
func choose_field(_field: StringName) -> void:
	pass


## 対戦の途中と決着の画面から、対戦設定のパネル（match_setup_panel.gd）を開けるか。
## 開けるなら、パネルは、これを match_choice.gd として読む。
func can_open_setup() -> bool:
	return false


## 決着の画面に「次へ」を出すか（押すと、流れ（run.gd）の次の場面へ進む）。won は、CPU と対戦して人が勝ったか。
func can_continue(_won: bool) -> bool:
	return false


## 決着の画面の Enter を「同じマップで再戦」にするか（偽なら、「次へ」があればそれ、無ければ流れの外への行き先 leave()）。won は can_continue と同じ。
func retries_on_enter(_won: bool) -> bool:
	return false


## 決着の画面の、流れの外への行き先（[終わり方（scene_flow.gd の対戦の場面の next）, ボタンの文の鍵]）。
## 既定はタイトル。対戦モードはマップ選択、ストーリーは話の一覧。
func leave() -> Array:
	return [&"title", "result.to_title"]


## 決着の画面に「部隊を選び直す」を出すか（押すと、流れ（run.gd）の 1 つ前の場面、出撃準備へ戻る）。
func can_choose_squad() -> bool:
	return false


## 対戦の途中の会話（battle_cues.gd）。新しい対戦を始めるたびに、新しく作る（台詞は 1 回の対戦で 1 度ずつ）。
## 既定は台詞なし。
func talk_cues() -> RefCounted:
	return BattleCues.new()


## 負けたときの台詞（battle_cues.gd の Line の列。決着の画面の見出しの下に出す）。既定は無し。
func lost_lines() -> Array[BattleCues.Line]:
	return []


## 将の姿（見た目だけ。unit_looks.gd の KING_LOOKS の名前。空ならいつもの将）: [プレイヤー1, プレイヤー2]。既定はどちらもいつもの将。
func king_looks() -> Array[StringName]:
	return [&"", &""]


## CPU と対戦して人が勝った（決着の画面が出たとき）。context は app_context.gd。
func record_win(_context: RefCounted) -> void:
	pass


func copy() -> RefCounted:
	return get_script().new()
