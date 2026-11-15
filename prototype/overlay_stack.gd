extends RefCounted
## 開いている重なる画面（システムメニュー、ログ、対戦の設定）の積み上げ。ノードに依存しない。
## アプリが 1 つ作り、AppContext.overlays として場面と重なる画面に渡す。
##
## - 重なる画面は、開いたら open で積み、閉じたら close で降ろす（木から抜けるときも降ろす）。
## - Esc と右クリックは、いちばん上の重なる画面（is_top）だけが受ける。
## - 後ろの場面は、何かが開いているか（is_open）、時間を止める重なりが開いているか（pauses）だけを見る。
##   重なる画面を 1 つ足すときは、開く・閉じるでここを通すだけでよい。

## 開いている重なる画面（下から上へ）。[画面, 時間を止めるか] の列。
var _stack: Array = []


## overlay を開いた（いちばん上に積む。もう積んであれば、そのままの位置に置いておく）。
## pausing が真なら、開いている間、後ろの場面は時間を止め、盤の操作（マウスの下のマスの追跡、視点の操作）をやめる。
func open(overlay: Object, pausing := false) -> void:
	if not has(overlay):
		_stack.append([overlay, pausing])


## overlay を閉じた（積んでいなければ何もしない）。
func close(overlay: Object) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i][0] == overlay:
			_stack.remove_at(i)


## overlay を積んでいるか。
func has(overlay: Object) -> bool:
	for entry: Array in _stack:
		if entry[0] == overlay:
			return true
	return false


## 何か重なる画面が開いているか。
func is_open() -> bool:
	return not _stack.is_empty()


## 時間を止める重なる画面が開いているか。
func pauses() -> bool:
	for entry: Array in _stack:
		if entry[1]:
			return true
	return false


## いちばん上の重なる画面（無ければ null）。
func top() -> Object:
	return _stack.back()[0] if not _stack.is_empty() else null


## overlay が、いちばん上の重なる画面か（Esc と右クリックを受けるか）。
func is_top(overlay: Object) -> bool:
	return top() == overlay
