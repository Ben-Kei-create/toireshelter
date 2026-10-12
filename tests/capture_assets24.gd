extends SceneTree
## ASSETS-24 の確認画像（画角 80°）。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_assets24.gd
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
		["a24_toy_boxes_crouched", Vector3(2.1, 0, -0.55), 0.6, Vector3(1.44, 0.12, -0.58)],
		["a24_specimen_tags", Vector3(1.95, 0, -0.38), 1.5, Vector3(1.52, 0.76, -0.38)],
		["a24_card_case_fronts", Vector3(1.75, 0, 0.1), 1.5, Vector3(1.0, 1.55, 0.15)],
		["a24_art_above_bed", Vector3(2.9, 0, 0.9), 1.5, Vector3(2.9, 1.1, 2.4)],
		["a24_gem_sign", Vector3(2.5, 0, 1.15), 1.5, Vector3(3.09, 0.3, 1.15)],
	]
	for v in views:
		p.global_position = v[1]
		p.camera.position.y = v[2]
		var d: Vector3 = v[3] - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-85.0), deg_to_rad(85.0))
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(v[0] + ".png"))
	quit()
