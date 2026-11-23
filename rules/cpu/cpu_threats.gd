extends "res://rules/cpu/cpu_player_base.gd"
## CPU の思考の、危険なマスの見積もり（敵が次の番に届くマスと、受けうるダメージ）。


## unit が cell に立っているときに、次の相手の番（と中立のフェーズ）に受けうるダメージの合計。
## ignored_id の敵は数えない。_build_threats のあとに呼ぶ。
## - 自分の煙幕の中のマスでは、煙幕に防がれない攻撃だけを数える
## - unit にバリアが付いていれば、いちばん弱い 1 回ぶんを引く（相手は、弱い攻撃で先にはがす）
## - unit が cell で隊列（部隊の特徴）になるなら、1 回ごとに隊列のぶんを引く
## - 敵の部隊の特徴で伸びるぶんを足す（集中砲火は 2 体目から、誓いは 2 人そろえば 2 人目、仇討ちは unit が仇なら、単騎はいま隣に味方のいない敵）
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
	var guard := Traits.RANKS_GUARD if Traits.ranked_at(_battle, unit, cell) else 0  # 隊列
	var foe_trait := Traits.of_side(_battle, _foe)
	var focusers := 0
	for enemy_id: int in by:
		if enemy_id != ignored_id:
			var hurt := by[enemy_id] as int
			if hurt > 0 and foe_trait != Traits.NONE:
				var enemy := _battle.unit_by_id(enemy_id)
				if enemy != null and enemy.side == _foe:
					match foe_trait:
						Traits.Id.FOCUS:
							focusers += 1
							if focusers > 1:
								hurt += Traits.FOCUS_BONUS
						Traits.Id.VENGEANCE:
							if Traits.slew(unit, _foe):
								hurt += Traits.VENGEANCE_BONUS
						Traits.Id.OATH:
							if enemy.oath_partner != 0 and enemy.oath_partner < enemy_id and by.has(enemy.oath_partner) and enemy.oath_partner != ignored_id:
								hurt += Traits.OATH_BONUS
						Traits.Id.LONE:
							if Traits.alone_at(_battle, enemy, enemy.cell):  # いま隣に味方がいない敵（動いた先は読まない）
								hurt += Traits.LONE_BONUS
			hurt = maxi(0, hurt - guard)
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
