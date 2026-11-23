extends "res://game/battle_screen/screen_base.gd"
## 対戦の場面の、選べる決まりの見え方: 縫い目の様子の札、組み方の線、拠点の旗。


## 組み方の印（docs/formation.md）: 分隊と誓いの駒の足元の輪と、誓いの 2 体・肩並べの仲間どうしの線。組み方が切なら、何も出さない。
func _refresh_formation() -> void:
	var links: Array = []
	for shown in battle.units:
		if not _views.has(shown.id):
			continue
		var squad := Formation.squad_of(battle, shown)
		var partner := Formation.partner_of(battle, shown)
		var color := Palette.NATION_MILITARY if not squad.is_empty() else Palette.NATION_FANTASY
		_view(shown.id).set_formation_mark(not squad.is_empty() or partner != null, color)
		if partner != null and shown.id < partner.id and _views.has(partner.id):
			var near := Formation.oath_near(battle, shown)
			links.append([_view(shown.id), _view(partner.id), Color(Palette.NATION_FANTASY, 1.0 if near else FormationLinks.FAR_ALPHA)])
		for mate in squad:
			if mate.id > shown.id and _views.has(mate.id) and maxi(absi(mate.cell.x - shown.cell.x), absi(mate.cell.y - shown.cell.y)) == 1:
				links.append([_view(shown.id), _view(mate.id), Palette.NATION_MILITARY])
	_formation_links.set_links(links)


## 組み方の線の数（検査用）。
func formation_link_count() -> int:
	return _formation_links.link_count() if _formation_links != null else 0


## 拠点の旗の色（検査用。拠点が無ければ透明）。
func stronghold_flag_color() -> Color:
	return _board_view.stronghold_flag_color()


## 拠点の旗と竿の上の札を、いまの確保から直す（確保の多いほうの陣営の色と数。どちらも 0 なら白）。拠点の無い盤では何もしない。
func _sync_stronghold_flag() -> void:
	if _board_view == null or battle.board.stronghold_cell == Board.NO_CELL:
		return
	var color := BoardView.COLOR_STRONGHOLD_FLAG
	var holds := 0
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if battle.stronghold_holds[side] > holds:
			holds = battle.stronghold_holds[side]
			color = TEAM_COLORS[side]
	# 乗っている駒の確保が、隣の敵で止まっていれば、札にそう添える。
	var blocked := false
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		blocked = blocked or (Stronghold.holds(battle, side) and Stronghold.contested(battle, side))
	_board_view.set_stronghold_progress(holds, Stronghold.HOLDS_TO_WIN, color, blocked)


## 対戦の始めの「対戦ルール」の文（札ごとに 1 行。出ていなければ空。検査用）。
func notice_text() -> String:
	return _hud.notice_text()


## 「対戦ルール」の札のうち、説明が欄からはみ出しているもの（検査用）。
func notice_cut_texts() -> Array[String]:
	return _hud.notice_cut_texts()


## 拠点の竿の上の札の文（検査用）。
func stronghold_mark() -> String:
	return _board_view.stronghold_mark()


## 拠点の旗の高さ（0〜1。検査用）。
func stronghold_flag_rate() -> float:
	return _board_view.stronghold_flag_rate()
