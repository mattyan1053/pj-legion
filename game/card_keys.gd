extends RefCounted
## 横に並ぶカード（物語選択・話の一覧・マップ選択）を、キーボードで選ぶときの決まり（ノードに依存しない）。
## 主の操作はマウス。キーボードは、左右の矢印で選び、Enter で決める（数字キーは 1〜9 までしか届かないので、それより先も選べるように）。
## 選んでいるカードは、マウスを乗せたときと同じ見た目にする（見た目は画面の側）。

## 押したキーが左右のどちらか（左 -1、右 +1、どちらでもない 0）。
static func direction(event: InputEvent) -> int:
	if not (event is InputEventKey and event.pressed):
		return 0
	match (event as InputEventKey).physical_keycode:
		KEY_LEFT:
			return -1
		KEY_RIGHT:
			return 1
	return 0


## 決めるキー（Enter。テンキーの Enter でも）か。
static func is_accept(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo \
		and (event as InputEventKey).physical_keycode in [KEY_ENTER, KEY_KP_ENTER]


## いま index のカードから、step の向きに次の選べるカードへ（count 枚。enabled.call(i) が真のものだけ）。
## まだ何も選んでいない（index が -1）ときは、start（選べなければその先）から始める。端では止まる。選べるカードが無ければ index のまま。
static func next(index: int, step: int, count: int, enabled: Callable, start := 0) -> int:
	if count <= 0 or step == 0:
		return index
	if index < 0 or index >= count:
		var from := clampi(start, 0, count - 1)
		for way: int in [step, -step]:
			var i := from
			while i >= 0 and i < count:
				if enabled.call(i):
					return i
				i += way
		return index
	var i := index + step
	while i >= 0 and i < count:
		if enabled.call(i):
			return i
		i += step
	return index



## マウスを本当に動かしたか（キーで送ったカードがマウスの下へ来て、乗ったことになるのとは分ける）。
## マウスに持ち替えたら、キーでの選びをやめる。
static func is_pointer_move(event: InputEvent) -> bool:
	return event is InputEventMouseMotion and (event as InputEventMouseMotion).relative != Vector2.ZERO
