extends RefCounted
## 乗せた物で中身が替わる枠を、いちばん大きい中身に合わせた大きさに固定する。
## 中身で枠の大きさが変わると、まわりの部品（カードの段など）まで動いて、カーソルを動かすたびに画面が揺れる。
## 場面を作ったあと（木に入ってから）に、出しうる中身をすべて当ててみて、いちばん大きいものに合わせる。

## box の大きさを、fills（中身を当てる関数の列）のどれを当てても変わらない大きさにする。最後に当てた中身が残る。
static func fit_largest(box: Control, fills: Array[Callable]) -> void:
	var largest := box.custom_minimum_size
	for fill: Callable in fills:
		fill.call()
		largest = largest.max(box.get_combined_minimum_size())
	box.custom_minimum_size = largest
