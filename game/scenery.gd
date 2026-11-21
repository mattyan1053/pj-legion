extends Node3D
## 盤の外の景色。戦う範囲の外も地続きの場所に見えるように置く。見た目だけで、ルールには関わらない。
## 何を置くかは、マップの見た目（stage_look.gd の SCENERY）が決める。ここは並べ方だけを持つ。
## 素材ごとの色（素材の定義の tint）があれば、景色の色（SCENERY の TINT）に掛ける。
## - 大きいもの（BIG。岩山など）: 尾根のノイズに沿って、盤から離れたところに。遠いほど大きい。
## - 小さいもの（SMALL。木など）: 森のノイズに沿って、かたまりで。盤の近くはまばらに、離れるほど濃く。
## - 散らばるもの（SCATTER。石など）: まばらに、どこにでも。低い。
##
## 置き方の決まり（layout。検査が確かめる）:
## - 盤の端から CLEAR マスまでは何も置かない（境目が分かり、端の駒に重ならない）。
## - 高さは、盤の端からの距離 × HEIGHT_PER_DISTANCE まで。カメラはいちばん浅くても 30 度（OrbitCamera.MIN_PITCH）で見下ろすので、
##   これより低ければ、盤の中のものを隠さない（カメラにも当たらない）。近くは低いものだけ、遠くほど大きいものになる。
## - 盤の端から REACH マスより先には置かない（その先は霞で見えない）。

const StageLook := preload("res://game/stage_look.gd")

const CLEAR := 2.0
const REACH := 66.0
const HEIGHT_PER_DISTANCE := 0.5
## 大きいもの・小さいもの・散らばるものの候補を置く間隔（マス）。
const SMALL_SPACING := 2.1
const BIG_SPACING := 4.6
const SCATTER_SPACING := 4.2
## 大きいものを置き始める距離。
const BIG_FROM := 7.0
## 大きいもの・小さいもの・散らばるものの高さ（マス）。近く〜遠く。素材の大きさ（size）を掛ける。
const BIG_HEIGHT := Vector2(1.9, 7.2)
const SMALL_HEIGHT := Vector2(0.7, 1.4)
const SCATTER_HEIGHT := Vector2(0.25, 0.7)
## まとめて描く区画の大きさ（マス）。区画ごとに、見えていなければ描かない。
const CHUNK := 34.0
## 盤の端からこの距離までの区画だけ、影を落とす。
const SHADOW_WITHIN := 30.0


## 置くもの。{ role（BIG・SMALL・SCATTER）, index（その候補の何番目）, position: Vector3, scale: float, yaw: float,
## height: float（マス）, distance: float（盤の端から）} の配列。
## scenery はマップの見た目の SCENERY。同じ盤の大きさ・種・見た目からは、同じ並びになる。
static func layout(board_size: Vector2i, look_seed: int, scenery: Dictionary) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var woods := FastNoiseLite.new()
	woods.seed = look_seed
	woods.frequency = 0.055
	var ridges := FastNoiseLite.new()
	ridges.seed = look_seed + 1
	ridges.frequency = 0.032

	var items: Array[Dictionary] = []
	var size := Vector2(board_size)
	var big: Array = scenery.get(StageLook.BIG, [])
	var small: Array = scenery.get(StageLook.SMALL, [])
	var scatter: Array = scenery.get(StageLook.SCATTER, [])
	# 小さいものを置く割合（1 = 森のように詰めて。木でないもの（荷や石の山）は、まばらにする）。
	var small_share := float(scenery.get(StageLook.SMALL_SHARE, 1.0))
	# 大きいものを、尾根のノイズのどこまで下まで置くか（大きいほど、尾根が太く、数が増える。谷の両側の山並み）。
	var big_spread := float(scenery.get(StageLook.BIG_SPREAD, 0.0))

	for at in _candidates(size, BIG_SPACING, 0.8, rng):
		var distance := distance_outside(at, size)
		if big.is_empty() or distance < BIG_FROM or distance > REACH:
			continue
		if ridges.get_noise_2d(at.x, at.y) < 0.12 - big_spread:
			continue
		var height := lerpf(BIG_HEIGHT.x, BIG_HEIGHT.y, clampf((distance - BIG_FROM) / 40.0, 0.0, 1.0)) * rng.randf_range(0.75, 1.2)
		items.append(_item(StageLook.BIG, big, rng.randi() % big.size(), at, height, rng.randf() * TAU, distance))

	for at in _candidates(size, SMALL_SPACING, 0.9, rng):
		var distance := distance_outside(at, size)
		if small.is_empty() or distance < CLEAR or distance > REACH:
			continue
		# かたまりで生える。盤の近くはまばらに、離れるほど濃く。大きいものの並ぶところは避ける。
		var wood := woods.get_noise_2d(at.x, at.y)
		var needed := lerpf(0.22, -0.08, clampf((distance - CLEAR) / 22.0, 0.0, 1.0))
		if wood < needed or ridges.get_noise_2d(at.x, at.y) > 0.2:
			continue
		if small_share < 1.0 and rng.randf() >= small_share:
			continue
		var height := lerpf(SMALL_HEIGHT.x, SMALL_HEIGHT.y, clampf(distance / 30.0, 0.0, 1.0)) * rng.randf_range(0.85, 1.2)
		items.append(_item(StageLook.SMALL, small, rng.randi() % small.size(), at, height, rng.randf() * TAU, distance))

	for at in _candidates(size, SCATTER_SPACING, 1.0, rng):
		var distance := distance_outside(at, size)
		if scatter.is_empty() or distance < CLEAR or distance > REACH:
			continue
		# 木のかたまりの外の、開けたところに。
		if woods.get_noise_2d(at.x, at.y) > 0.1 or rng.randf() < 0.6:
			continue
		var height := lerpf(SCATTER_HEIGHT.x, SCATTER_HEIGHT.y, clampf(distance / 20.0, 0.0, 1.0)) * rng.randf_range(0.8, 1.25)
		items.append(_item(StageLook.SCATTER, scatter, rng.randi() % scatter.size(), at, height, rng.randf() * TAU, distance))
	return items


## 盤の周り REACH マスの、間隔 spacing の格子を、jitter（間隔に対する割合）だけ揺らした点。
static func _candidates(size: Vector2, spacing: float, jitter: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var area := Rect2(Vector2.ONE * -REACH, size + Vector2.ONE * 2.0 * REACH)
	var z := area.position.y
	while z < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			points.append(Vector2(x, z) + Vector2(rng.randf(), rng.randf()) * spacing * jitter)
			x += spacing
		z += spacing
	return points


## 盤（0, 0）〜 size の外へ、どれだけ離れているか（マス）。中なら 0。
static func distance_outside(at: Vector2, size: Vector2) -> float:
	return (at - at.clamp(Vector2.ZERO, size)).length()


func setup(board_size: Vector2i, look_seed: int, look: Dictionary) -> void:
	var scenery: Dictionary = look[StageLook.SCENERY]
	var tint: Color = StageLook.SCENERY_SHADE * (scenery.get(StageLook.TINT, Color.WHITE) as Color)
	# 区画と素材ごとにまとめる（[区画, 役, 何番目] -> 置くものの配列）。
	var groups := {}
	for item in layout(board_size, look_seed, scenery):
		var at: Vector3 = item.position
		var key := [Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK)), item.role, item.index]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(item)

	for key: Array in groups:
		var items: Array = groups[key]
		var prop: Dictionary = scenery[key[1]][key[2]]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = StageLook.mesh_of(prop)
		multimesh.instance_count = items.size()
		var nearest := INF
		for i in items.size():
			var item: Dictionary = items[i]
			var turned := Basis(Vector3.UP, item.yaw).scaled(Vector3.ONE * float(item.scale))
			multimesh.set_instance_transform(i, Transform3D(turned, item.position))
			nearest = minf(nearest, item.distance)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		# 結晶は沈ませない（光るもの）。
		instance.material_override = StageLook.material_of(prop, Color.WHITE if prop.has("crystal") else tint * (prop.get("tint", Color.WHITE) as Color))
		if nearest > SHADOW_WITHIN or prop.has("crystal"):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


## 置くもの 1 つ。高さ height（マス）は、素材の大きさ（size）を掛け、高さの決まりで抑える。
static func _item(role: StringName, props: Array, index: int, at: Vector2, height: float, yaw: float, distance: float) -> Dictionary:
	var prop: Dictionary = props[index]
	height = minf(height * float(prop.get("size", 1.0)), distance * HEIGHT_PER_DISTANCE)
	return {
		"role": role, "index": index, "position": Vector3(at.x, 0.0, at.y), "scale": height / float(prop.height),
		"yaw": yaw, "height": height, "distance": distance,
	}
