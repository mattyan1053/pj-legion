extends SceneTree
## 駒のアイコン（assets/unit_icons/）を、駒の 3D の形（game/unit_view.gd）から写して作る道具。絵は描かない。
## 種類ごと・陣営の色ごと・進化の前後で 1 枚ずつ、透明な地の PNG を書く。使い方は assets/unit_icons/README.md。
##
##   tools/unit_icons.sh <godot>
##
## 写すには画面の描画が要る（--headless では絵が出ない）。unit_icons.sh が、画面の無いコンテナでは Xvfb の上で回す。

const UnitView := preload("res://game/unit_view.gd")
const UnitIcons := preload("res://game/unit_icons.gd")

## 写す大きさ（px）。書くのは ICON_SIZE に縮めたもの（縁がなめらかになる）。
const RENDER_SIZE := 256

var _out := "res://assets/unit_icons"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--out")
	if at != -1 and at + 1 < args.size():
		_out = args[at + 1]
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
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
	for variant: Array in UnitIcons.variants():
		var kind: UnitKind.Id = variant[0]
		var side: int = variant[1]
		var evolved: bool = variant[2]
		var look: StringName = variant[3]
		var view := UnitView.new()
		viewport.add_child(view)
		view.setup(kind, UnitIcons.COLORS[side], 1, 1, look)
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
		var path := "%s/%s" % [_out, UnitIcons.file_name(kind, side, evolved, look)]
		var error := image.save_png(path)
		if error != OK:
			push_error("unit_icons: 書けない: %s" % path)
			quit(1)
			return
		written += 1
		viewport.remove_child(view)
		view.free()
	print("unit_icons: %d 枚を書いた（%s）" % [written, _out])
	quit(0)
