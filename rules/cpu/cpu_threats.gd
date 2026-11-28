extends "res://rules/cpu/cpu_player_base.gd"
## CPU の思考の、危険なマスの見積もり（敵が次の番に届くマスと、受けうるダメージ）。


## unit が cell に立っているときに、次の相手の番（と中立のフェーズ）に受けうるダメージの合計。
## ignored_id の敵は数えない。_build_threats のあとに呼ぶ。中身は _danger_in。
func _threat_at(unit: Unit, cell: Vector2i, ignored_id: int) -> int:
	return _danger_in(_threat_map, unit, cell, ignored_id)


## unit が cell に立っているとき、バリアがいちばん弱い 1 回ぶんを防ぐ量（バリアを持っていなくても、持っているとして）。
func _barrier_saves(unit: Unit, cell: Vector2i) -> int:
	return _danger_parts(_threat_map, unit, cell, 0, _battle).y


## _threat_at の中身。脅威範囲（map。盾を置いたあとの盤面で数え直したものでも読める）と、ダメージを解決する盤面（state）を受け取る。
## 届く敵ごとに、その敵のいちばん強い 1 回ぶん（駒の攻撃か、スキルのダメージ・樽の爆発）を足す。
## 駒の攻撃の量は、本物のダメージの解決（Combat.hit_from）に聞く: unit が cell に立ち、敵が攻撃するマスから攻撃したら。
## 煙幕、軍略（集中砲火・仇討ち・誓い・隊列・守護）、森、胞子は、どれもそちらの決まり。
## 集中砲火と誓いの「このターンに攻撃された」は、敵が 1 体ずつ順に攻撃するとして、先に攻撃した敵を覚えとして渡す。
## - 殻蟹（離れた所からは狙えない。Monsters）は、近くからの攻撃だけを数える
## - unit にバリアが付いていれば、いちばん弱い 1 回ぶんを引く（相手は、弱い攻撃で先にはがす）
func _danger_in(map: Threat.Map, unit: Unit, cell: Vector2i, ignored_id: int, state: Battle = null) -> int:
	var parts := _danger_parts(map, unit, cell, ignored_id, _battle if state == null else state)
	if parts.x > 0 and Statuses.blocking(unit) != -1:
		return parts.x - parts.y
	return parts.x


## 危険の合計（バリアを数えない）と、いちばん弱い 1 回ぶん（届く敵が無ければ 0）。いまの対戦の駒で、無視する敵が無ければ控える。
func _danger_parts(map: Threat.Map, unit: Unit, cell: Vector2i, ignored_id: int, state: Battle) -> Vector2i:
	var memo := -1
	if map == _threat_map and state == _battle and ignored_id == 0 and _battle.unit_by_id(unit.id) == unit:
		memo = (unit.id * _board.size.y + cell.y) * _board.size.x + cell.x
		if _danger_memo.has(memo):
			return _danger_memo[memo]
	var shelled := unit.has_trait(Evolution.Trait.SHELLED)
	var marks: Array = []  # 先に攻撃した敵（Battle.struck の形）
	var total := 0
	var weakest := _FAR
	for enemy_id in map.reachers(cell):
		if enemy_id == ignored_id:
			continue
		var hurt := map.flat_at(cell, enemy_id)
		var attacker: Unit = null
		for blow in map.blows_at(cell, enemy_id):
			if shelled and not blow[3]:
				continue
			var hit := Combat.hit_from(state, blow[2], blow[1], blow[0], unit, cell, marks)
			if hit.smoke == null:
				attacker = blow[2]
			hurt = maxi(hurt, hit.unblocked)
		if attacker != null:
			marks.append(Vector2i(enemy_id, attacker.side))
		if hurt > 0:
			total += hurt
			weakest = mini(weakest, hurt)
	var result := Vector2i(total, weakest if total > 0 else 0)
	if memo != -1:
		_danger_memo[memo] = result
	return result


## 次の相手の番（と中立のフェーズ）に、敵が攻撃できるマスを調べる（_threat_map と、届く敵の表 _threats、_close_threats）。
## 敵の脅威範囲（Threat.against。docs/threat-range.md）をそのまま使う。
func _build_threats() -> void:
	if _threats_ready:
		return
	_threats_ready = true
	for effect in _board.field_effects:
		if effect.type == FieldEffect.Type.SMOKE and effect.side == _me:
			for cell in effect.cells:
				_smoked[cell] = true
	_threat_map = _threats_of(_battle)
	_threats = _threat_map.hits
	_close_threats = _threat_map.close
	_foe_stops = _threat_map.stops


## state（いまの対戦か、その複製に手を進めたもの。自分の番）から、次の相手の番の脅威範囲を作る。state は変えない。
## 届く敵の表（hits）には、敵の駒（回復役を除く）の止まれるマス（stops）も入っている。
func _threats_of(state: Battle) -> Threat.Map:
	return Threat.against(state, _me)
