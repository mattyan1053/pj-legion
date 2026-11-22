class_name TrialRules
extends RefCounted
## 対戦モードで、対戦設定から入・切できる決まり（docs/match-setup.md の「選べる決まり」）の名前。
## 入にするのは MatchSetup.trials に名前を並べること（MatchSetup の既定は空 = どれも切。ストーリーの話は入にしない）。
## 対戦モードの対戦設定の既定は DEFAULTS（拠点は入、砲台は切）。
## 決まりを 1 つ足すには、ここに名前を足し、MatchSetup.create_battle に入のときの準備を書く。
## （名前の TrialRules は、選べる決まりとして入れた名残り。拠点は正式な勝ち方、砲台はまだ試し。）

## 砲台: 盤の決まった場所に砲台が置かれ、後衛が乗ると射程が伸びる（docs/map-objects.md の「砲台」）。
const BATTERY := &"battery"

## 拠点: 盤の中央の拠点に乗って番を終えると確保が進み、決まった数に届いたら勝ち（docs/map-objects.md の「拠点」）。
const STRONGHOLD := &"stronghold"

## 名前の一覧。
const ALL: Array[StringName] = [BATTERY, STRONGHOLD]
## 対戦モードの対戦設定の既定（拠点は、将の撃破・本陣の占拠と並ぶ勝ち方として入。砲台は切）。
const DEFAULTS: Array[StringName] = [STRONGHOLD]


static func is_known(id: StringName) -> bool:
	return ALL.has(id)
