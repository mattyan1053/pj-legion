extends "res://tests/base_test.gd"
## 兵の動きのつなぎ目（game/looks/model_body.gd）: 立ち姿の繰り返しと、攻撃の出入りと、走り出し・止まりで、姿勢が飛ばない。
## 人間の「スナイパーの動きだけカクついていないか」（Issue #46 の 11/23）から。原因は、素材の「狙い」「射撃」の動きの頭の数コマが
## 「構えるまで」で、狙いを立ち姿として繰り返すたびに構え直していたことと、構えから立ち姿へ短いつなぎで戻していたこと。
## 走りのつなぎは、立ち姿・走りのどの時刻から切り替えても、いちばん速い骨が上限を超えないこと（どの組・兵種も同じ長さ RUN_BLEND）。

const UnitLooks := preload("res://game/unit_looks.gd")
const ModelBody := preload("res://game/looks/model_body.gd")

## 立ち姿の繰り返しの終わりと頭の、骨の角度の差の上限（度）。
const LOOP_GAP := 12.0
## 攻撃の出入りと、走り出し・止まりのつなぎの間に、骨が回る速さの上限（度 / 秒）。
const BLEND_SPEED := 500.0


func _bodies() -> Array:
	var bodies: Array = []
	for set_name: StringName in UnitLooks.SETS:
		var looks := UnitLooks.of(set_name)
		for kind: UnitKind.Id in UnitKind.Id.values():
			bodies.append(["%s の %s" % [set_name, UnitKind.Id.find_key(kind)], looks.build(kind, Color.BLUE, &"", Vector3.ZERO)])
		for person: StringName in UnitLooks.PERSONS:
			if looks.has_person(person):
				bodies.append(["%s の %s" % [set_name, person], looks.build(UnitLooks.PERSONS[person], Color.BLUE, person, Vector3.ZERO)])
	return bodies


func test_no_pose_jumps_at_the_seams() -> void:
	var measured := 0
	var runs := 0
	for entry: Array in _bodies():
		var body := entry[1] as Node3D
		await settle(body)
		if body is ModelBody:
			var jumps := (body as ModelBody).motion_jumps()
			if not jumps.is_empty():
				measured += 1
				assert_true(jumps["idle_loop"] <= LOOP_GAP, "%s: 立ち姿を繰り返すたびに姿勢が飛ぶ（%.0f 度）" % [entry[0], jumps["idle_loop"]])
				assert_true(jumps["attack_in"] <= BLEND_SPEED, "%s: 攻撃へ入るつなぎが速すぎる（%.0f 度 / 秒）" % [entry[0], jumps["attack_in"]])
				assert_true(jumps["attack_out"] <= BLEND_SPEED, "%s: 攻撃から立ち姿へ戻るつなぎが速すぎる（%.0f 度 / 秒）" % [entry[0], jumps["attack_out"]])
				if jumps.has("run_in"):
					runs += 1
					assert_true(jumps["run_in"] <= BLEND_SPEED, "%s: 立ち姿から走り出すつなぎが速すぎる（%.0f 度 / 秒）" % [entry[0], jumps["run_in"]])
					assert_true(jumps["run_out"] <= BLEND_SPEED, "%s: 走りから止まるつなぎが速すぎる（%.0f 度 / 秒）" % [entry[0], jumps["run_out"]])
		body.free()
	assert_true(measured >= 25, "動きを測れた体が少ない（%d）" % measured)
	assert_true(runs >= 25, "走りのつなぎを測れた体が少ない（%d）" % runs)
