extends SceneTree
## ASSETS-30 の確認画像（ウィンドウ表示が必要、画角 80°）。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_assets30.gd

const Pose := preload("res://scripts/player.gd").Pose
var out := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	out = OS.get_environment("SHOT_DIR")
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	var p = main.player
	main.hud._message_panel.visible = false
	main.hud._message_time_left = 0.0
	main.set_physics_process(false)   # 撮影でクリア判定が動かないように
	p.set_physics_process(false)
	await _shot(p, "a30_room_overview", Vector3(1.3, 0, 1.85), 1.5, Vector3(3.0, 1.0, -0.5))
	await _shot(p, "a30_room_from_window", Vector3(2.5, 0, -0.9), 1.5, Vector3(2.4, 1.1, 2.2))
	await _shot(p, "a30_books_closeup", Vector3(3.15, 0, 0.5), 1.5, Vector3(3.8, 1.1, 0.55))
	await _shot(p, "a30_rocks_on_desk", Vector3(2.0, 0, -0.1), 1.5, Vector3(1.46, 0.76, -0.38))
	await _shot(p, "a30_card_case", Vector3(2.4, 0, 0.3), 1.5, Vector3(1.0, 1.5, 0.2))
	await _shot(p, "a30_painting_a", Vector3(2.0, 0, 0.9), 1.5, Vector3(1.6, 1.25, 2.4))
	await _shot(p, "a30_painting_b_and_gem", Vector3(2.6, 0, 0.4), 1.5, Vector3(3.4, 1.2, -0.6))
	await _shot(p, "a30_bath_floor", Vector3(0.0, 0, 0.75), 1.5, Vector3(0.0, 0.0, -0.4))
	p.toggle_crouch()
	p.camera.position.y = 0.6
	await _shot(p, "a30_pipe_wallpaper_crouched", Vector3(0.25, 0, 0.55), 0.6, Vector3(0.88, 0.45, 0.1))
	p.pose = Pose.DUCT
	await _shot(p, "a30_duct_metal", Vector3(-0.6, 2.5, -0.3), 0.38, Vector3(2.0, 2.8, -0.3))
	await _shot(p, "a30_exterior_wall", Vector3(1.9, 2.5, -1.15), 0.38, Vector3(2.0, 2.6, -4.4))
	p.pose = Pose.WALK
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
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
