extends "res://game/talk_screen/talk_ask.gd"
## 会話の場面（game/talk_screen.gd）の、主人公の名前を聞く行（行に "naming" がある。話のファイルの「(name)」。docs/story.md の「主人公の名前」）:
## 名を問う行を出しきったら、名前の窓（hero_name_window.gd）を出す。決めた名前は記録（story.gd の name_hero）に覚え、
## この先の文と札（この場面と、流れの先の場面）に入る。決めたら、次の行へ進む。
##
## - 聞くのは、まだ名乗っていないときだけ（記録に名前が無い）。名乗ったあとは、見直し（クリア済みの話をもう一度）でも、戻って読み直しても聞かない。
## - 決めるまで、先へ進まない（「スキップ」も、この行で止まる）。右クリック・Esc で閉じると、既定の名前で名乗ったことになる。
## - 検査とスクリーンショットでは聞かない（既定の名前のまま進み、名乗ったことにもしない）。

const HeroNameWindow := preload("res://game/hero_name_window.gd")

## 名前の窓（初めて聞くときに作る）。
var _name_window: HeroNameWindow


## まだ名前を聞くか（記録に名前が無く、遊んでいるとき）。
func _naming_due() -> bool:
	return context.story != null and context.checking == &"" and not context.story.is_hero_named(context.story.campaign)


## 行 index が、いま名前を聞く行か。
func _names_at(index: int) -> bool:
	return index < _lines.size() and (_lines[index] as Dictionary).get("naming", false) and _naming_due()


## 名前を聞いているか（窓が開いている）。
func is_naming() -> bool:
	return _name_window != null and _name_window.is_open()


## 名前の窓（検査用。まだ聞いていなければ null）。
func name_window() -> HeroNameWindow:
	return _name_window


## いまの行が名前を聞く行で、文が出きっていれば、名前の窓を出す。
func _ask_name_if_due() -> void:
	if not _names_at(_index) or _ended or is_naming() or _shown < float(_text.get_total_character_count()):
		return
	ask_name()


## 名前の窓を出す（スクリーンショットの道具は、ここから直に出す）。決めたら、次の行へ。
func ask_name() -> void:
	if is_naming() or context.story == null or context.story.campaign.hero == "":
		return
	if _name_window == null:
		_name_window = HeroNameWindow.new()
		_name_window.setup(context.overlays)
		_layer.add_child(_name_window)
	var campaign: RefCounted = context.story.campaign
	context.play_sound(&"menu_open")
	_name_window.ask(context.story.hero_name(campaign), campaign.hero, campaign.hero_role(), func(named: String) -> void:
		# 記録に覚える（流れの先の場面にも入る）。流れの外で開いた会話（テストなど）のために、この場面の行にも入れる。
		var given: String = context.story.name_hero(campaign, named)
		context.story.rename_talk(talk, campaign.hero, given)
		_refresh_lines()
		call(&"_after_naming"))  # talk_screen.gd（行を出す関数を呼ぶ）
