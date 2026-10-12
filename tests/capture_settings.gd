extends SceneTree
## Esc の設定画面の確認画像。SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_settings.gd
func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 15:
		await process_frame
	current_scene._pause()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("settings.png"))
	quit()
