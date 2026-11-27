class_name OptionalRules
extends RefCounted
## 対戦モードで、対戦設定から入・切できる決まり（docs/match-setup.md の「選べる決まり」）の名前。
## 入にするのは MatchSetup.rules に名前を並べること（MatchSetup の既定は空 = どれも切。ストーリーの話は入にしない）。
## 対戦モードの対戦設定の既定は DEFAULTS（拠点と縫い目の様子は入）。
## 軍略（Traits）は決まりではなく、部隊が持つもの（入・切は無い。docs/troop-traits.md）。
## 砲台は決まりではなく、マップの物（docs/map-objects.md の「砲台」。盤の出どころが置く）。
## 休眠の決まり（DORMANT）は、画面からは入にできない（集計の道具の --rules= とテストだけが入にする）。
## 決まりを 1 つ足すには、ここに名前を足し、MatchSetup.create_battle に入のときの準備を書く。

## 拠点: 盤ごとに決めたマスの拠点に乗って番を終えると確保が進み、決まった数に届いたら勝ち（docs/map-objects.md の「拠点」）。
const STRONGHOLD := &"stronghold"

## 縫い目の様子（ランダム）: 対戦ごとに、マップに付く効果が 0〜2 つめくられ、対戦のあいだずっと効く（Seam。docs/seam-signs.md）。
## 対戦設定では「ランダム」「なし」。ストーリーの話は、話のファイルが決めた様子（Scenario.signs）を使う。
const SEAM := &"seam"

## 手札（試し）: 軍ごとの札の山から、自分の番の始めに 1 枚引き、1 つの番に 1 枚使える（Hand。docs/hand-cards.md）。既定は切。
const HAND := &"hand"

## 名前の一覧。
const ALL: Array[StringName] = [STRONGHOLD, SEAM, HAND]
## 対戦モードの対戦設定の既定（拠点は、将の撃破・本陣の占拠と並ぶ勝ち方として入。縫い目の様子はランダム = 入）。
const DEFAULTS: Array[StringName] = [STRONGHOLD, SEAM]
## 休眠の決まり: ルールと CPU は残すが、画面からは入にできない（対戦設定に行が無い）。
## いまは無い（決まりを試すときの置き場所として残す）。
const DORMANT: Array[StringName] = []


static func is_known(id: StringName) -> bool:
	return ALL.has(id)


## 画面から入にできる決まりか（知っていて、休眠でない）。
static func is_choosable(id: StringName) -> bool:
	return is_known(id) and not DORMANT.has(id)


## 画面から入にできる決まりの一覧（ALL から休眠の決まりを抜いたもの。並びは ALL の順）。
static func choosable() -> Array[StringName]:
	var found: Array[StringName] = []
	for id in ALL:
		if not DORMANT.has(id):
			found.append(id)
	return found
