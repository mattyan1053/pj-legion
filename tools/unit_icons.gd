extends SceneTree
## 駒のアイコンを、駒の 3D の形（game/unit_view.gd）から写して作る道具。絵は描かない。
## 種類ごと・陣営の色ごと・進化の前後で 1 枚ずつ、透明な地の PNG を、駒の見た目の組ごとのディレクトリ（組の定義の icon_dir）に書く。
## 使い方は assets/unit_icons/README.md。
##
##   tools/unit_icons.sh <godot> [組の名前]   （組の名前を省くと、全部の組）
##
## 写すには画面の描画が要る（--headless では絵が出ない）。unit_icons.sh が、画面の無いコンテナでは Xvfb の上で回す。

const UnitView := preload("res://game/unit_view.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const UnitLooks := preload("res://game/unit_looks.gd")

## 写す大きさ（px）。書くのは ICON_SIZE に縮めたもの（縁がなめらかになる）。
const RENDER_SIZE := 256

## 書く組の名前（空なら全部）と、書く先（空なら組の icon_dir。--out で替えられる。組を 1 つ選んだときだけ）。
var _look_set := &""
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--out")
	if at != -1 and at + 1 < args.size():
		_out = args[at + 1]
	at = args.find("--look")
	if at != -1 and at + 1 < args.size():
		_look_set = StringName(args[at + 1])
		if not UnitLooks.SETS.has(_look_set):
			push_error("unit_icons: 知らない組: %s（あるのは %s）" % [_look_set, ", ".join(UnitLooks.SETS.keys())])
			quit(1)
			return
	_run.call_deferred()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(RENDER_SIZE, RENDER_SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.own_world_3d = true
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.87, 0.92)
	environment.ambient_light_energy = 0.7
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.1
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true

	var written := 0
	for look_set: StringName in ([_look_set] if _look_set != &"" else UnitLooks.SETS.keys()):
		var out := _out if _out != "" and _look_set != &"" else UnitLooks.of(look_set).icon_dir
		if not await _write_set(viewport, camera, look_set, out):
			quit(1)
			return
		written += UnitIcons.variants().size()
		print("unit_icons: 組 %s を %s に書いた" % [look_set, out])
	print("unit_icons: %d 枚を書いた" % written)
	quit(0)


func _write_set(viewport: SubViewport, camera: Camera3D, look_set: StringName, out: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for variant: Array in UnitIcons.variants():
		var kind: UnitKind.Id = variant[0]
		var side: int = variant[1]
		var evolved: bool = variant[2]
		var look: StringName = variant[3]
		var view := UnitView.new()
		viewport.add_child(view)
		view.setup(kind, UnitIcons.COLORS[side], 1, 1, look, look_set)
		if evolved:
			view.set_evolved(1)
		# 正面から少し見下ろす。駒の高さに合わせて、全身が収まるように寄る。
		var height := view.height()
		camera.size = maxf(height, 1.0) * 1.12
		var look_at := Vector3(0.0, height * 0.47, 0.0)
		camera.position = look_at + Vector3(0.0, 0.55, 1.6).normalized() * 6.0
		camera.look_at(look_at)
		for i in 12:  # アニメーションの姿勢と、色の塗り替えが落ち着くまで
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.resize(UnitIcons.ICON_SIZE, UnitIcons.ICON_SIZE, Image.INTERPOLATE_LANCZOS)
		var path := "%s/%s" % [out, UnitIcons.file_name(kind, side, evolved, look)]
		var error := image.save_png(path)
		if error != OK:
			push_error("unit_icons: 書けない: %s" % path)
			return false
		viewport.remove_child(view)
		view.free()
	return true
