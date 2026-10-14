extends SceneTree
## タイトル画面の確認画像（周回の数か所）。
## 実行: SHOT_DIR=保存先 TOIRE_TITLE=1 xvfb-run -a Godot --path . --script res://tests/capture_title.gd
func _initialize() -> void:
	OS.set_environment("TOIRE_TITLE", "1")
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 30:
		await process_frame
	var title = current_scene._title
	title._fade.modulate.a = 0.0
	for k in 4:
		title._angle = 0.4 + k * 1.6
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("title_%d.png" % k))
	title.settings_requested.emit()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("title_settings.png"))
	quit()
