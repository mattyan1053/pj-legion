extends "res://rules/cpu/cpu_player_base.gd"
## CPU の思考の、危険なマスの見積もり（敵が次の番に届くマスと、受けうるダメージ）。


## unit が cell に立っているときに、次の相手の番（と中立のフェーズ）に受けうるダメージの合計。
## ignored_id の敵は数えない。_build_threats のあとに呼ぶ。
## - 自分の煙幕の中のマスでは、煙幕に防がれない攻撃だけを数える
## - unit にバリアが付いていれば、いちばん弱い 1 回ぶんを引く（相手は、弱い攻撃で先にはがす）
## - unit が cell で肩並べ（組み方の分隊）になるなら、1 回ごとに肩並べのぶんを引く
func _threat_at(unit: Unit, cell: Vector2i, ignored_id: int) -> int:
	return _danger_in(_threats, _close_threats, unit, cell, ignored_id)


## _threat_at の中身。危険の表（threats、close）を受け取る（盾を置いたあとの盤面で数え直した表でも読めるように）。
func _danger_in(
	threats: Dictionary[Vector2i, Dictionary], close: Dictionary[Vector2i, Dictionary],
	unit: Unit, cell: Vector2i, ignored_id: int
) -> int:
	var by: Dictionary = (close if _smoked.has(cell) else threats).get(cell, {})
	var total := 0
	var weakest := _FAR
	var guard := Formation.SQUAD_GUARD if Formation.guarded_at(_battle, unit, cell) else 0  # 肩並べ（組み方が切なら 0）
	for enemy_id: int in by:
		if enemy_id != ignored_id:
			var hurt := maxi(0, by[enemy_id] - guard)
			total += hurt
			weakest = mini(weakest, hurt)
	if total > 0 and Statuses.blocking(unit) != -1:
		total -= weakest
	return total


## 次の相手の番（と中立のフェーズ）に、敵が攻撃できるマスを調べる（_threats、_close_threats）。
## 敵の脅威範囲（Threat.against。docs/threat-range.md）をそのまま使う。
func _build_threats() -> void:
	if _threats_ready:
		return
	_threats_ready = true
	for effect in _board.field_effects:
		if effect.type == FieldEffect.Type.SMOKE and effect.side == _me:
			for cell in effect.cells:
				_smoked[cell] = true
	_fill_threats(_battle, _threats, _close_threats, _foe_stops)


## state（いまの対戦か、その複製に手を進めたもの。自分の番）から、次の相手の番の危険の表を作って、threats と close に書く。
## stops には、敵の駒（回復役を除く）が止まれるマスを書く。state は変えない。
func _fill_threats(
	state: Battle, threats: Dictionary[Vector2i, Dictionary], close: Dictionary[Vector2i, Dictionary],
	stops: Dictionary[Vector2i, bool]
) -> void:
	var map := Threat.against(state, _me)
	threats.merge(map.hits)
	close.merge(map.close)
	stops.merge(map.stops)
