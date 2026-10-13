extends SceneTree
## 設定画面（Esc）の確認画像。1280×720 と小さめの画面。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_menu.gd
func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var m = current_scene
	m._pause()
	for sz in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = sz
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("settings_%d.png" % sz.x))
	quit()
