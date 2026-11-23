extends "res://game/battle_screen/screen_refresh.gd"
## 対戦の場面の、途中の会話の札（台詞を出す・送る・止める）と、終盤の曲。


## 対戦の途中の会話の台詞を、上の帯のすぐ下の札に順に出し、ログにも書く。
## 札が台詞を送られるまで出したままにする（hold）ときは、送り終えるまで待つ（その間、盤は止まる。CPU の番の早送り・スキップ・おまかせの途中でも）。
func _say(lines: Array[BattleCues.Line]) -> void:
	if lines.is_empty():
		return
	for line in lines:
		battle_log.say(line.name, line.text, line.side)
	if _playback.skipping and not _talk.hold:
		return  # 検査とスクリーンショットでは、スキップの途中の台詞は、ログにだけ残す
	_talk.say(lines)
	if not _talk.hold:
		return
	_talk_catcher.visible = true
	_refresh()
	while _talk.is_holding() and is_inside_tree():
		await _talk.drained
	_talk_catcher.visible = false
	if is_inside_tree():
		_refresh()


## 対戦の途中の台詞を送る（クリック・Enter・Space）。送ったかを返す。
func advance_talk() -> bool:
	if not _talk.advance():
		return false
	context.play_sound(&"ui_click")
	return true


## 対戦の途中の台詞を送られるのを待っているか。検査用。
func is_talk_holding() -> bool:
	return _talk.is_holding()


## 台詞を送られるまで出したままにするか（検査用。ふだんは遊ぶときだけ）。
func set_talk_hold(on: bool) -> void:
	_talk.hold = on


## いま画面に出ている、対戦の途中の会話の台詞（無ければ null。検査とスクリーンショットの道具用）。
func talk_line() -> BattleCues.Line:
	return _talk.current()


## 対戦の途中の会話の札が画面に占める四角と、上の帯の下の決まった枠（勝ち方の札、視点の案内）とミニマップの四角。検査用。
func talk_card_rect() -> Rect2:
	return _talk.card_rect()


## 対戦の途中の会話の札を薄くしているか（メニュー・予測のパネル・進化先の選択肢が重なっている間）。検査用。
func is_talk_dimmed() -> bool:
	return _talk.is_dimmed()


func talk_card_neighbors() -> Array[Rect2]:
	var rects := _hud.top_tag_rects()
	rects.append(minimap_rect())
	return rects


## 対戦の途中の会話の札に、台詞を出す（検査用。ふだんは話の [cues] から出す）。hold なら、送られるまで盤を止める。
func say_for_check(lines: Array[BattleCues.Line]) -> void:
	if _talk.hold:
		_say(lines)
	else:
		_talk.say(lines)


## 対戦の途中の会話の札を消す（スクリーンショットで、ほかの台詞を出すとき）。
func clear_talk_for_check() -> void:
	_talk.clear()
