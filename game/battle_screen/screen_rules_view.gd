extends "res://game/battle_screen/screen_base.gd"
## 対戦の場面の、選べる決まりと軍略の見え方: 縫い目の様子の札、軍略の輪と線、拠点の旗。

const ArmyLook := preload("res://game/army_look.gd")


## 軍略の印（docs/troop-traits.md の「対戦の画面」）。色は軍略の軍の色。相手の軍略も同じに出す。
## - 頭の上の札（増える数）と足元の輪: 集中砲火・仇討ちは効く敵（このターンに攻撃された敵、味方を倒した敵）、誓いは誓いの相手が攻撃した敵（どれも照準の印）
## - 足元の小さな印: 隊列・守護がいま効いている兵（盾）、補給線がいま効いている兵（十字）。兵どうしを線では結ばない
## - 駒を選んでいる間だけ: 誓いの相手との細い線。動かす先を選んでいるなら、そこへ動けば効くマスに、薄い印
func _refresh_traits() -> void:
	var links: Array = []
	var marked: Dictionary[int, Array] = {}  # 駒の id → [色, 札の文, 札の役]
	var focus := _detail_unit()
	for shown in battle.units:
		if not _views.has(shown.id):
			continue
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			var id := Traits.of_side(battle, side)
			if id == Traits.NONE:
				continue
			var mark := [_trait_color(id), Text.t("battle.board.trait_mark", {"amount": Names.troop_trait_amount(id)})]
			if Traits.focus_marked(battle, shown, side) or Traits.vengeance_marked(battle, shown, side):
				marked[shown.id] = mark
			if shown.side != side and id == Traits.Id.OATH:
				for mate in battle.units:
					if mate.side == side and Traits.oath_marked(battle, mate, shown):
						marked[shown.id] = mark
		var own := Traits.of_side(battle, shown.side) if shown.side != Unit.Side.NEUTRAL else Traits.NONE
		_view(shown.id).set_trait_pip(TraitPip.kind_of(own) if _trait_covers(shown, shown.cell) else TraitPip.Kind.NONE, _trait_color(own))
		var partner := Traits.partner_of(battle, shown) if shown.side != Unit.Side.NEUTRAL else null
		if partner != null and shown.id < partner.id and _views.has(partner.id) and (focus == shown or focus == partner):
			links.append([_view(shown.id), _view(partner.id), _trait_color(own)])
	for shown in battle.units:
		if _views.has(shown.id):
			var mark: Array = marked.get(shown.id, [Color.WHITE, ""])
			_view(shown.id).set_trait_mark(marked.has(shown.id), mark[0], mark[1])
	_trait_links.set_links(links)
	# 動かす先を選んでいる間（移動範囲を塗っている間）だけ、そこへ動けば軍略が効くマスに印を置く。
	var spots: Array[Vector2i] = []
	var mover := selected_unit()
	if mover != null and inspected_unit() == null and not battle.is_over() and battle.can_act(mover) and _ui.mode == Mode.NONE and not _ui.busy:
		for cell: Vector2i in _move_cells:
			if _trait_covers(mover, cell):
				spots.append(cell)
	var trait_id := Traits.of_side(battle, mover.side) if mover != null else Traits.NONE
	_trait_links.set_spots(spots, TraitPip.kind_of(trait_id), _trait_color(trait_id))


## unit が cell に立ったら、隣り合うことで効く軍略（隊列・守護・補給線）が効くか。
func _trait_covers(unit: Unit, cell: Vector2i) -> bool:
	if unit.side == Unit.Side.NEUTRAL:
		return false
	return Traits.guard_at(battle, unit, cell) > 0 or Traits.supplier_at(battle, unit, cell) != null


## 軍略の印の色（その軍略の軍の色）。
static func _trait_color(id: int) -> Color:
	return ArmyLook.color(Traits.army_of(id))


## 軍略の線の数（検査用）。
func trait_link_count() -> int:
	return _trait_links.link_count() if _trait_links != null else 0


## 足元に軍略の印（盾・十字）が出ている駒の id（検査用）。
func trait_pip_ids() -> Array[int]:
	var ids: Array[int] = []
	for shown in battle.units:
		if _views.has(shown.id) and _view(shown.id).trait_pip() != TraitPip.Kind.NONE:
			ids.append(shown.id)
	return ids


## 動けば軍略が効く印を置いているマス（検査用）。
func trait_spot_cells() -> Array[Vector2i]:
	return _trait_links.spot_cells() if _trait_links != null else ([] as Array[Vector2i])


## 軍略の輪が出ている駒の数（検査用）。
func trait_mark_count() -> int:
	var count := 0
	for shown in battle.units:
		if _views.has(shown.id) and _view(shown.id).has_trait_mark():
			count += 1
	return count


## 上の帯に出ている、陣営の軍略の名前（出ていなければ空。検査用）。
func trait_name(player: int) -> String:
	return _hud.trait_name(player)


## 軍略の札（頭の上）の文の並び（札の出ている駒の順。検査用）。
func trait_mark_texts() -> Array[String]:
	var texts: Array[String] = []
	for shown in battle.units:
		if _views.has(shown.id) and _view(shown.id).trait_mark_text() != "":
			texts.append(_view(shown.id).trait_mark_text())
	return texts


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
