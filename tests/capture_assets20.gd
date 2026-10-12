extends SceneTree
## ASSETS-20 の確認画像（画角 80°）。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_assets20.gd
func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	main.hud._message_panel.visible = false
	main.set_physics_process(false)
	var p = main.player
	p.set_physics_process(false)
	var views := [
		["a20_room_overview", Vector3(1.3, 0, 1.85), Vector3(3.0, 1.0, -0.5)],
		["a20_room_toward_front_wall", Vector3(2.6, 0, -0.6), Vector3(2.3, 1.2, 2.4)],
		["a20_painting_large", Vector3(1.75, 0, 1.0), Vector3(1.6, 1.3, 2.4)],
		["a20_paintings_above_bed", Vector3(2.9, 0, 0.9), Vector3(2.9, 1.05, 2.4)],
		["a20_painting_window_right", Vector3(2.6, 0, 0.3), Vector3(3.45, 1.4, -1.2)],
	]
	for v in views:
		p.global_position = v[1]
		var d: Vector3 = v[2] - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(v[0] + ".png"))
	quit()
