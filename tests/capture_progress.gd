extends SceneTree
## 文字送りの途中・神の声・発見の知らせの確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_progress.gd
func _shot(n: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(n + ".png"))


func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var m = current_scene
	m.player.set_physics_process(false)
	m.hud.show_message("そういえば、床の一部が……少しだけ、色が違う気がする。", 30.0, "voice")
	m.hud._type_pos = 14.0
	await _shot("typing_voice_partial")
	m.hud.finish_typing()
	await _shot("voice_full")
	m.progress.discover("stairs")
	m.progress.discover("mahjong")
	await create_timer(0.6).timeout
	await _shot("discovery_toast")
	quit()
