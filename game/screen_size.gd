extends RefCounted
## 画面の大きさ（docs/screen-size.md）。窓の大きさから、画面の部品を並べる大きさ（論理の大きさ）を出す計算と、
## 検査・スクリーンショットの道具で画面の大きさを決める入口（`-- --size <幅>x<高さ>`）。
##
## 画面の部品は、論理の大きさの上に並べる。窓の大きさとの比（拡大の倍率）は、プロジェクトの設定（display/window/stretch）で決まる。
## 画面の無い検査（--headless）では窓が実際には開かないので、論理の大きさを直に決めて、その大きさの窓と同じに並ぶようにする。

## 基準の大きさ（project.godot の display/window/size/viewport_*）。16:9 の窓は、これを等倍に拡大・縮小したものになる。
static func base_size() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"),
	)


## 縦横比の扱い（project.godot の display/window/stretch/aspect）。
static func project_aspect() -> Window.ContentScaleAspect:
	var names := {
		"ignore": Window.CONTENT_SCALE_ASPECT_IGNORE, "keep": Window.CONTENT_SCALE_ASPECT_KEEP,
		"keep_width": Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH, "keep_height": Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT,
		"expand": Window.CONTENT_SCALE_ASPECT_EXPAND,
	}
	return names.get(ProjectSettings.get_setting("display/window/stretch/aspect", "keep"), Window.CONTENT_SCALE_ASPECT_KEEP)


## 窓の大きさ window のときの、論理の大きさ。base は基準の大きさ、aspect は縦横比の扱い（Godot の canvas_items の拡大と同じ計算）。
static func logical_size(window: Vector2, base: Vector2, aspect: Window.ContentScaleAspect) -> Vector2:
	if window.x <= 0.0 or window.y <= 0.0:
		return base
	match aspect:
		Window.CONTENT_SCALE_ASPECT_EXPAND:
			return window / minf(window.x / base.x, window.y / base.y)
		Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH:
			return Vector2(base.x, maxf(base.y, window.y * base.x / window.x))
		Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT:
			return Vector2(maxf(base.x, window.x * base.y / window.y), base.y)
		Window.CONTENT_SCALE_ASPECT_IGNORE:
			return base
	return base


## `<幅>x<高さ>` を読む。読めなければ (0, 0)。
static func parse(text: String) -> Vector2i:
	var parts := text.to_lower().split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO
	var size := Vector2i(parts[0].to_int(), parts[1].to_int())
	return size if size.x > 0 and size.y > 0 else Vector2i.ZERO


## 引数の `--size <幅>x<高さ>`（か `--size=<幅>x<高さ>`）。無ければ (0, 0)。
static func requested(args: PackedStringArray) -> Vector2i:
	for i in args.size():
		if args[i].begins_with("--size="):
			return parse(args[i].trim_prefix("--size="))
		if args[i] == "--size" and i + 1 < args.size():
			return parse(args[i + 1])
	return Vector2i.ZERO


## 検査とスクリーンショットの道具の画面の大きさを決める。size は窓の大きさ（(0, 0) なら基準の大きさ）。
## 画面の無い検査では、論理の大きさを直に決める（窓が開かず、大きさが決まらないため）。画面のあるときは、窓をその大きさにする。
static func apply_for_check(window: Window, size: Vector2i) -> void:
	var wanted := Vector2(size) if size != Vector2i.ZERO else base_size()
	if DisplayServer.get_name() == "headless":
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		window.content_scale_size = Vector2i(logical_size(wanted, base_size(), project_aspect()).round())
	elif size != Vector2i.ZERO:
		window.size = size


## 画面いっぱいに広げた部品（anchors が全体）を、max_size より大きく広げない。画面がそれより広い（高い）ときは、
## はみ出すぶんを左右（上下）の余白に分けて、真ん中に置く。margin は、いつも空けておく余白（左、上、右、下）。
## 画面の大きさが変わるたびに置き直す。横長や縦長の画面で、まとまっていたほうが見やすい場面（部隊の編成など）に使う。
static func cap(control: Control, max_size: Vector2, margin := Vector4.ZERO) -> void:
	var fit := func() -> void:
		var screen := control.get_viewport_rect().size
		var extra := ((screen - max_size) / 2.0).max(Vector2.ZERO)
		control.offset_left = margin.x + extra.x
		control.offset_top = margin.y + extra.y
		control.offset_right = -margin.z - extra.x
		control.offset_bottom = -margin.w - extra.y
	# 画面の大きさの合図は、木にいる間だけつなぐ（場面を抜けて部品が消えたあとに呼ばれないように）。
	control.tree_entered.connect(func() -> void:
		if not control.get_viewport().size_changed.is_connected(fit):
			control.get_viewport().size_changed.connect(fit)
		fit.call())
	control.tree_exiting.connect(func() -> void:
		if control.get_viewport().size_changed.is_connected(fit):
			control.get_viewport().size_changed.disconnect(fit))
