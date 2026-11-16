extends "res://tests/base_test.gd"
## 画面の大きさの計算（game/screen_size.gd）。

const ScreenSize := preload("res://game/screen_size.gd")

const BASE := Vector2(1280, 720)


func test_reads_the_size_argument() -> void:
	assert_eq(ScreenSize.requested(PackedStringArray(["--shots", "all", "--size", "1920x1080"])), Vector2i(1920, 1080))
	assert_eq(ScreenSize.requested(PackedStringArray(["--size=3440X1440"])), Vector2i(3440, 1440))
	assert_eq(ScreenSize.requested(PackedStringArray(["--autoplay"])), Vector2i.ZERO)
	for bad: String in ["", "1920", "x1080", "0x720", "axb", "1920x1080x2"]:
		assert_eq(ScreenSize.parse(bad), Vector2i.ZERO, bad)


func test_sixteen_by_nine_windows_keep_the_base_size() -> void:
	for window: Vector2 in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		for aspect: Window.ContentScaleAspect in [Window.CONTENT_SCALE_ASPECT_KEEP, Window.CONTENT_SCALE_ASPECT_EXPAND]:
			assert_true(ScreenSize.logical_size(window, BASE, aspect).is_equal_approx(BASE), "%s（%d）" % [window, aspect])


func test_expand_widens_or_heightens_from_the_base() -> void:
	var expand := Window.CONTENT_SCALE_ASPECT_EXPAND
	assert_true(ScreenSize.logical_size(Vector2(3440, 1440), BASE, expand).is_equal_approx(Vector2(1720, 720)))
	assert_true(ScreenSize.logical_size(Vector2(1280, 800), BASE, expand).is_equal_approx(Vector2(1280, 800)))
	assert_true(ScreenSize.logical_size(Vector2(1024, 768), BASE, expand).is_equal_approx(Vector2(1280, 960)))
	assert_eq(ScreenSize.logical_size(Vector2(3440, 1440), BASE, Window.CONTENT_SCALE_ASPECT_KEEP), BASE)
	assert_eq(ScreenSize.logical_size(Vector2.ZERO, BASE, expand), BASE, "大きさの無い窓は基準のまま")
