extends "res://game/talk_screen/talk_base.gd"
## 会話の場面（game/talk_screen.gd）の、話し手の姿: 作る、左右の立つ所に置く、同じ所に立つ話し手から 1 人を選ぶ。


## 会話に出てくる話し手ごとに、姿を 1 つ作る。立つ所は、人の軍が左、敵の軍が右。
## 敵の軍が出てこない会話は、最初に話す人が左、ほかの人が右。
func _make_figures() -> void:
	var shapes: Array = talk.get("figures", [])
	var lines: Array = talk.get("lines", [])  # 渡された行の全部（どの答えを選んでも出てくる話し手の姿を、先に作っておく）
	var has_foe := lines.any(func(line: Dictionary) -> bool: return int(line.get("side", 0)) == 1)
	var seen := {}
	for line: Dictionary in lines:
		var who := _who(line)
		if who < 0 or who >= shapes.size() or seen.has(who):
			continue
		var side := int(line.get("side", 0))
		var place := side if has_foe or seen.is_empty() else 1
		seen[who] = true
		var figure: Dictionary = shapes[who]
		var view := TalkFigure.new(figure["kind"], side, figure.get("evolved", false), figure.get("look", &""), place, figure.get("crown", false))
		view.who = who
		view.visible = false
		_stage.add_child(view)
		_figures.append(view)


## 話し手の姿を、舞台の高さいっぱいに、文の枠の左端と右端にそろえて置く。
func _place_figures() -> void:
	var height := _stage.size.y
	var width := minf(height * TalkFigure.ASPECT, FIGURE_MAX_WIDTH)
	var left := (_stage.size.x - BOX_WIDTH) / 2.0
	for view in _figures:
		view.size = Vector2(width, height)
		view.position = Vector2(left if view.place == 0 else left + BOX_WIDTH - width, 0.0)


## 行 index のときに、左右それぞれの所に立つ話し手の番号（[左, 右]。誰もいなければ -1）。
## いちばん近くに話した人。まだ誰も話していない所は、次に話す人。
## いま出す行に話す人がいない所（答えを選ぶまで、その人の行がどれも出ない）は、渡された行の全部から探す（問われている人が、選ぶ前から立っている）。
func _standing_at(index: int) -> Array[int]:
	var place_of := {}
	for view in _figures:
		place_of[view.who] = view.place
	var standing: Array[int] = [-1, -1]
	var lines: Array = _lines
	for i in range(mini(index, lines.size() - 1), -1, -1):
		var who := _who(lines[i])
		if place_of.has(who) and standing[place_of[who]] < 0:
			standing[place_of[who]] = who
	for i in range(index + 1, lines.size()):
		var who := _who(lines[i])
		if place_of.has(who) and standing[place_of[who]] < 0:
			standing[place_of[who]] = who
	for line: Dictionary in talk.get("lines", []):
		var who := _who(line)
		if place_of.has(who) and standing[place_of[who]] < 0:
			standing[place_of[who]] = who
	return standing
