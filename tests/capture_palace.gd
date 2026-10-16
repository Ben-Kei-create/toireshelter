extends SceneTree
## トイレ（宮殿風）の確認画像。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_palace.gd
func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	main.hud.visible = false
	var p = main.player
	p.set_physics_process(false)
	main.room.painting_map.set_slid(false)
	for v in [["v1", Vector3(0.4, 0.0, 0.9), Vector3(-0.5, 0.7, -0.6)], ["v2", Vector3(0.0, 0.0, 0.8), Vector3(0.0, 0.5, -0.9)], ["v3", Vector3(-0.3, 0.0, 0.5), Vector3(0.6, 0.9, 0.9)], ["v4", Vector3(0.6, 0.0, 0.9), Vector3(-0.8, 1.4, 0.2)], ["v5", Vector3(0.0, 0.0, 0.1), Vector3(0.15, 2.0, 0.35)]]:

		p.global_position = v[1]
		var d: Vector3 = v[2] - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		if v[0] == "map":
			main.room.painting_map.set_slid(true)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(v[0] + ".png"))
	quit()
