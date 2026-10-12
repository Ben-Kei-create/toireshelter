extends SceneTree
## カーテン・風呂桶・鏡の鍵・カセットの確認画像（画角 80°）。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_bath_items.gd
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
	var room = main.room
	await _shot(p, "curtain_open", Vector3(0.0, 0, 0.75), 1.5, Vector3(0.0, 0.9, -1.0))
	room.shower_curtain.toggle()
	await create_timer(0.7).timeout
	await _shot(p, "curtain_closed", Vector3(0.0, 0, 0.75), 1.5, Vector3(0.0, 0.9, -1.0))
	await _shot(p, "curtain_closed_near", Vector3(0.2, 0, -0.1), 1.5, Vector3(0.3, 0.6, -0.9))
	room.shower_curtain.toggle()
	await create_timer(0.7).timeout
	await _shot(p, "bath_bucket", Vector3(0.2, 0, 0.0), 1.5, Vector3(0.74, 0.05, -0.31))
	await _shot(p, "mirror_lock", Vector3(0.45, 0, 0.3), 1.5, Vector3(0.9, 1.45, 0.25))
	await _shot(p, "cartridges", Vector3(1.75, 0, 0.55), 1.5, Vector3(1.15, 0.45, 0.53))
	p.camera.fov = 35.0
	await _shot(p, "cartridges_zoom_reference", Vector3(1.75, 0, 0.55), 1.5, Vector3(1.15, 0.45, 0.53))
	quit()


func _shot(p, name: String, pos: Vector3, eye: float, look: Vector3) -> void:
	p.global_position = pos
	p.camera.position.y = eye
	var d: Vector3 = look - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-85.0), deg_to_rad(85.0))
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name + ".png"))
