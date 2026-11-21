class_name TrialRules
extends RefCounted
## 試しの決まり（docs/match-setup.md の「試しの決まり」）。対戦設定で入・切する、まだ本決まりでない決まりの名前。
## **既定はどれも切。** 切のとき、対戦は 1 局も変わらない。入にするのは MatchSetup.trials に名前を並べること。
## 決まりを 1 つ足すには、ここに名前を足し、MatchSetup.create_battle に入のときの準備を書く。

## 砲台: 盤の決まった場所に砲台が置かれ、後衛が乗ると射程が伸びる（docs/map-objects.md の「砲台」）。
const BATTERY := &"battery"

## 作戦: 対戦の前に選んだ札を、対戦中に 1 回ずつ使う（docs/tactics.md）。
const TACTICS := &"tactics"

## 名前の一覧（画面の並び）。
const ALL: Array[StringName] = [BATTERY, TACTICS]


static func is_known(id: StringName) -> bool:
	return ALL.has(id)
