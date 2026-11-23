class_name OptionalRules
extends RefCounted
## 対戦モードで、対戦設定から入・切できる決まり（docs/match-setup.md の「選べる決まり」）の名前。
## 入にするのは MatchSetup.rules に名前を並べること（MatchSetup の既定は空 = どれも切。ストーリーの話は入にしない）。
## 対戦モードの対戦設定の既定は DEFAULTS（拠点は入、砲台・組み方・縫い目の様子は切）。
## 休眠の決まり（DORMANT）は、画面からは入にできない（集計の道具の --rules= とテストだけが入にする）。
## 決まりを 1 つ足すには、ここに名前を足し、MatchSetup.create_battle に入のときの準備を書く。

## 砲台: 盤の決まった場所に砲台が置かれ、後衛が乗ると射程が伸びる（docs/map-objects.md の「砲台」）。
const BATTERY := &"battery"

## 拠点: 盤ごとに決めたマスの拠点に乗って番を終えると確保が進み、決まった数に届いたら勝ち（docs/map-objects.md の「拠点」）。
const STRONGHOLD := &"stronghold"

## 組み方: 軍ごとの組み合わせの効果（連邦の分隊、騎士領の誓い。docs/formation.md）。休眠（DORMANT）。
const FORMATION := &"formation"

## 縫い目の様子: 対戦ごとに条件の札が 2 枚めくられ、対戦のあいだずっと効く（Seam。docs/seam-signs.md）。
const SEAM := &"seam"

## 名前の一覧。
const ALL: Array[StringName] = [BATTERY, STRONGHOLD, FORMATION, SEAM]
## 対戦モードの対戦設定の既定（拠点は、将の撃破・本陣の占拠と並ぶ勝ち方として入。砲台・組み方・縫い目の様子は切）。
const DEFAULTS: Array[StringName] = [STRONGHOLD]
## 休眠の決まり: ルールと CPU は残すが、画面からは入にできない（対戦設定に行が無く、部隊編成にも組み方の欄を出さない）。
## 組み方は作り直すまで休ませる（人間の決定。Issue #47 の 11/23）。
const DORMANT: Array[StringName] = [FORMATION]


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
