extends RefCounted
## 流れ（docs/scene-flow.md の「流れ」）: ひと続きに進む場面の列。場面の名前と、その場面に渡すもの、いま何番目か。
##
## 場面の表（scene_flow.gd）は「場面 + 終わり方 → 次の場面」なので、同じ場面を 1 続きの中で 2 回、違うものを渡して使えない。
## 流れは、それを並べる。流れの中の場面が NEXT で終わると、アプリ（app.gd）は流れの次の場面へ進む。
## 列を終えたら exit の場面へ。流れの中の場面がほかの終わり方で終わったら、場面の表で進み、流れは捨てる。
## いま流れを作るのは、対戦モードの「対戦を始める」（match_choice.gd の run。対戦の場面 1 つ）だけ。
## ここはノードに依存しない（テストから呼べる）。

## 流れの中の場面が「次へ」で終わるときの終わり方。
const NEXT := &"next"
## 流れの中の場面が「1 つ前の場面へ」で終わるときの終わり方（ストーリーの決着の画面の「部隊を選び直す」→ 出撃の準備）。
const PREVIOUS := &"previous"

## 列を終えたら行く場面。
var exit := &"title"
## いま何番目か（0 から）。
var index := 0
var _steps: Array[Dictionary] = []  # {scene: StringName, data: Variant}


## 場面 step_scene（渡すもの step_data）を、列の終わりに足す。
func add(step_scene: StringName, step_data: Variant = null) -> void:
	_steps.append({"scene": step_scene, "data": step_data})


## いまの場面の名前。列を終えていたら空。
func scene() -> StringName:
	return _steps[index]["scene"] if index < _steps.size() else &""


## いまの場面に渡すもの。列を終えていたら null。
func data() -> Variant:
	return _steps[index]["data"] if index < _steps.size() else null


## 次の場面へ進み、その名前を返す。列を終えたら exit を返す。
func advance() -> StringName:
	index = mini(index + 1, _steps.size())
	return scene() if index < _steps.size() else exit


## 1 つ前の場面へ戻り、その名前を返す（最初の場面なら、そのまま）。
func back() -> StringName:
	index = clampi(index - 1, 0, maxi(_steps.size() - 1, 0))
	return scene()


## 場面 step_scene（渡すもの step_data）を、いまの場面の前に差し込み、そこを「いま」にする。
## 差し込んだ場面が NEXT で終わると、もとの場面へ戻る（出撃の準備から、部隊の編成へ寄り道する）。
func insert(step_scene: StringName, step_data: Variant = null) -> void:
	_steps.insert(index, {"scene": step_scene, "data": step_data})


func is_done() -> bool:
	return index >= _steps.size()
