extends RefCounted
## 対戦モードで選べる盤の一覧（docs/stage-select.md の「選べる盤」）。ステージ選択のカード、対戦の設定のパネルのステージの行、
## 決着の画面の「新しい盤面」、F1〜F3、集計の道具（tools/cpu_matches.gd の --stage）が、ここを引く。ノードに依存しない。
##
## 盤は鍵（StringName）で持つ。ストーリーの話（game/story/episodes/ のファイルの名前）や見た目（stage_look.gd の名前）と同じ持ち方。
## 盤の出どころは 2 つ:
## - 生成のステージ（STAGE。BoardGenerator.Stage）: 対戦を始めるたびに、種から形を作り直す。見た目は StageLook.OF_STAGE。
## - 手で作ったマップ（MAP。game/maps/ のファイルの id。maps.gd）: 種によらず、いつも同じ形。見た目は LOOK。
## どちらも、勝ち方は対戦モードのいつもの 2 つ、初期位置はいつもの「本陣の前」、部隊は両方とも対戦の設定で選ぶ（予算と 6 体）。
##
## **盤を 1 つ足すには、FIELDS に 1 つ足すだけ**（手で作ったマップなら、game/maps/ のファイルと）。
## 並びが画面の並び（番号、1〜9 のキー、F1〜F3）。生成のステージを先に並べる。
## 対戦モードの画面に出すのは、CPU どうしの釣り合い（docs/cpu-ai.md の「いまの集計」）が対戦モードのめやすに入るものだけ。
## めやすを外れるものは HIDDEN を立てて一覧に残す（画面には出さない。集計の道具の --stage では測れる）。

const StageLook := preload("res://game/stage_look.gd")
const Maps := preload("res://game/maps.gd")

## 項目の欄の名前。
const ID := &"id"  ## 鍵
const STAGE := &"stage"  ## 生成のステージ（BoardGenerator.Stage）
const MAP := &"map"  ## 手で作ったマップ（game/maps/ のファイルの id。maps.gd で引く）
const LOOK := &"look"  ## 手で作ったマップの見た目（stage_look.gd の名前）
const TAGS := &"tags"  ## カードに載せる、置かれているもの（ひとことの特徴）
const NOTE := &"note"  ## カードにマウスを乗せると出す説明
const HIDDEN := &"hidden"  ## 真なら、対戦モードの画面に出さない（釣り合いがめやすを外れる。docs/stage-select.md）

const PLAIN := &"plain"
const LABYRINTH := &"labyrinth"
const TWIN_SPRINGS := &"twin_springs"
const RIDGE_PATH := &"ridge_path"
const CRYSTAL_GORGE := &"crystal_gorge"
const BOULDER_PASS := &"boulder_pass"

## 対戦の設定の既定。
const DEFAULT := PLAIN

const FIELDS := [
	{
		ID: PLAIN, STAGE: BoardGenerator.Stage.PLAIN,
		TAGS: "広場 ・ 起爆樽",
		NOTE: "開けた平地。中央は遮るもののない広場で、まわりに岩と森が散らばる。\n中央の左右に起爆樽。正面からぶつかり合う、基本の戦場。",
	},
	{
		ID: LABYRINTH, STAGE: BoardGenerator.Stage.LABYRINTH,
		TAGS: "迷路 ・ 回復の泉",
		NOTE: "格子に並んだ壁が通路を作る迷路。射線が通りにくく、本陣へは回り道になる。\n左右に回復の泉。遠くから撃つより、角を曲がって近づく駒が強い。",
	},
	{
		ID: TWIN_SPRINGS, STAGE: BoardGenerator.Stage.TWIN_SPRINGS,
		TAGS: "2 本の道 ・ ポータル",
		NOTE: "中央を大きな壁がふさぎ、戦場は左右 2 本の道に分かれる。本陣は対角。\nどちらの道にも、上下をつなぐポータル。どちらで攻め、どちらで守るか。",
	},
	# 手で作ったマップ（ストーリーと同じ形）。部隊を変えた CPU どうしの釣り合いがめやすに入る（docs/cpu-ai.md の「いまの集計」）。
	{
		ID: RIDGE_PATH, MAP: "ridge_path", LOOK: StageLook.STONE_WALLS,
		TAGS: "小さな盤 ・ 2 本の道",
		NOTE: "細長い小さな盤。真ん中の岩が尾根を左右 2 本の道に分け、どちらの道にも結晶泉と中ボス。\n本陣どうしが近く、すぐにぶつかる。押し込むか、道をふさいで迎え撃つか。",
	},
	{
		ID: CRYSTAL_GORGE, MAP: "crystal_gorge", LOOK: StageLook.CRYSTAL_FOREST,
		TAGS: "裂け目 ・ 橋 ・ ポータル",
		NOTE: "盤の中ほどを結晶の裂け目が横切る。渡れるのは左右の端の橋と、真ん中のポータルだけ。本陣は対角。\n遠回りの橋か、敵陣のただ中へ出る近道のポータルか。",
	},
	# 手で作ったマップ（対戦モードのために作ったもの）。
	{
		ID: BOULDER_PASS, MAP: "boulder_pass", LOOK: StageLook.GRASSLAND,
		TAGS: "大岩 ・ 広い 2 本の道",
		NOTE: "草原の真ん中を大岩がふさぎ、戦場は左右の広い道に分かれる。どちらの道にも中ボス。\n小さな盤でも、本陣どうしは遠い。どちらの道に厚く構えるか。",
	},
]


## 対戦モードの画面に出す鍵（並びの順。HIDDEN のものは入れない）。
static func ids() -> Array[StringName]:
	var shown: Array[StringName] = []
	for field: Dictionary in FIELDS:
		if not field.get(HIDDEN, false):
			shown.append(field[ID])
	return shown


## 一覧の全部の鍵（HIDDEN のものも。集計の道具とテストが使う）。
static func all_ids() -> Array[StringName]:
	var all: Array[StringName] = []
	for field: Dictionary in FIELDS:
		all.append(field[ID])
	return all


## 対戦モードの画面に出すか。
static func is_shown(id: StringName) -> bool:
	return has(id) and not _field(id).get(HIDDEN, false)


## 生成のステージの鍵（並びの順）。「新しい盤面」（種を替えて作り直す）を選べるのは、これだけ。
static func generated_ids() -> Array[StringName]:
	var generated: Array[StringName] = []
	for id in ids():
		if is_generated(id):
			generated.append(id)
	return generated


## 生成のステージ stage の鍵（一覧に無ければ空）。
static func field_of_stage(stage: BoardGenerator.Stage) -> StringName:
	for field: Dictionary in FIELDS:
		if field.has(STAGE) and field[STAGE] == stage:
			return field[ID]
	return &""


static func has(id: StringName) -> bool:
	return _find(id) != -1


## 画面に出す並びの番号（1 から。出さないものは 0）。カードと対戦の設定のパネルに出す番号、ステージ選択のキー。
static func number_of(id: StringName) -> int:
	return ids().find(id) + 1


## 生成のステージか（偽なら、手で作ったマップ。種によらず、いつも同じ形）。
static func is_generated(id: StringName) -> bool:
	return _field(id).has(STAGE)


## 画面に出す名前（戦いの定義の名前と同じ）。
static func title_of(id: StringName) -> String:
	var field := _field(id)
	if field.has(MAP):
		return Maps.find(field[MAP])["title"]
	return MatchSetup.stage_name(field.get(STAGE, -1))


static func tags_of(id: StringName) -> String:
	return _field(id).get(TAGS, "")


static func note_of(id: StringName) -> String:
	return _field(id).get(NOTE, "")


## 盤の見た目（stage_look.gd の名前）。
static func look_of(id: StringName) -> StringName:
	var field := _field(id)
	if field.has(LOOK):
		return field[LOOK]
	return StageLook.name_of_stage(field.get(STAGE, -1))


## 対戦モードの戦いの定義（docs/scenario.md）。知らない鍵なら null。
static func scenario_of(id: StringName) -> Scenario:
	var field := _field(id)
	if field.has(MAP):
		var found: Dictionary = Maps.find(field[MAP])
		return Scenario.on_map(found["map"], found["title"])
	if field.has(STAGE):
		return Scenario.versus(field[STAGE])
	return null


## カードの縮図に描く盤（生成のステージは種 card_seed で作る。手で作ったマップは、いつもの形）。
static func card_board(id: StringName, card_seed: int) -> Board:
	var defined := scenario_of(id)
	return defined.make_board(card_seed) if defined != null else null


static func _find(id: StringName) -> int:
	for index in FIELDS.size():
		if FIELDS[index][ID] == id:
			return index
	return -1


static func _field(id: StringName) -> Dictionary:
	var index := _find(id)
	return FIELDS[index] if index != -1 else {}
