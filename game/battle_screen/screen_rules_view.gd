extends "res://game/battle_screen/screen_base.gd"
## 対戦の場面の、選べる決まりと部隊の特徴の見え方: 縫い目の様子の札、特徴の輪と線、拠点の旗。


## 部隊の特徴の印（docs/troop-traits.md の「画面」）: 効く相手の足元の輪と、組む兵どうしの線。色は特徴の軍の色。相手の特徴も同じに出す。
## - 輪: 集中砲火・仇討ちは効く敵（このターンに攻撃された敵、味方を倒した敵）、誓いは誓いの相手が攻撃した敵、
##   単騎は、その陣営の番に、まだ動ける、隣に味方のいない攻撃する兵（増えるのは攻撃する側なので、番の間だけ）
## - 線: 誓いの 2 人、隊列で隣り合う同じ兵種、補給線で隣り合う回復役
func _refresh_traits() -> void:
	var links: Array = []
	var marked: Dictionary[int, Color] = {}
	for shown in battle.units:
		if not _views.has(shown.id):
			continue
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			var id := Traits.of_side(battle, side)
			if id == Traits.NONE:
				continue
			var color := _trait_color(id)
			if Traits.focus_marked(battle, shown, side) or Traits.vengeance_marked(battle, shown, side):
				marked[shown.id] = color
			if shown.side == side and battle.phase == side and Traits.alone_at(battle, shown, shown.cell) and battle.can_act(shown) and shown.kind != UnitKind.Id.KING and UnitKind.role(shown.kind) != UnitKind.Role.HEALER:
				marked[shown.id] = color
			if shown.side != side and id == Traits.Id.OATH:
				for mate in battle.units:
					if mate.side == side and Traits.oath_marked(battle, mate, shown):
						marked[shown.id] = color
		if shown.side == Unit.Side.NEUTRAL:
			continue
		var own := Traits.of_side(battle, shown.side)
		var tint := _trait_color(own)
		var partner := Traits.partner_of(battle, shown)
		if partner != null and shown.id < partner.id and _views.has(partner.id):
			links.append([_view(shown.id), _view(partner.id), tint])
		for mate in Traits.neighbors_at(battle, shown, shown.cell):
			if mate.id <= shown.id or not _views.has(mate.id):
				continue
			var ranks := own == Traits.Id.RANKS and mate.kind == shown.kind
			var supply := own == Traits.Id.SUPPLY and (UnitKind.role(mate.kind) == UnitKind.Role.HEALER) != (UnitKind.role(shown.kind) == UnitKind.Role.HEALER)
			if ranks or supply:
				links.append([_view(shown.id), _view(mate.id), Color(tint, TraitLinks.FAR_ALPHA if supply else 1.0)])
	for shown in battle.units:
		if _views.has(shown.id):
			_view(shown.id).set_trait_mark(marked.has(shown.id), marked.get(shown.id, Color.WHITE))
	_trait_links.set_links(links)


## 特徴の印の色（その特徴の軍の色）。
static func _trait_color(id: int) -> Color:
	return Palette.NATION_MILITARY if Traits.army_of(id) == UnitKind.Army.MILITARY else Palette.NATION_FANTASY


## 特徴の線の数（検査用）。
func trait_link_count() -> int:
	return _trait_links.link_count() if _trait_links != null else 0


## 特徴の輪が出ている駒の数（検査用）。
func trait_mark_count() -> int:
	var count := 0
	for shown in battle.units:
		if _views.has(shown.id) and _view(shown.id).has_trait_mark():
			count += 1
	return count


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
