extends SceneTree
## クリア画面（記録つき）の確認画像。実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_clear.gd
func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var m := current_scene
	m.add_item("driver")
	m.add_item("spare_roll")
	m.add_coin(3)
	m.progress.add_note("n1", "題", "本文")
	m.play_time = 3725.0
	m._clear("legit")
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("clear.png"))
	quit()
