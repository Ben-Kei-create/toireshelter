extends SceneTree
## TASK-10 の確認画像（ウィンドウ表示が必要）。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_task10.gd

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
	var room = main.room
	main.hud._message_panel.visible = false
	main.hud._message_time_left = 0.0
	main.set_physics_process(false)   # 撮影でクリア判定が動かないように
	p.set_physics_process(false)

	await _shot(p, "t10_room_from_doorway", Vector3(1.3, 0, 1.85), 1.5, Vector3(3.0, 1.0, -0.5))
	await _shot(p, "t10_room_from_window", Vector3(2.5, 0, -0.9), 1.5, Vector3(2.3, 1.1, 2.2))
	await _shot(p, "t10_room_card_case", Vector3(3.2, 0, 0.3), 1.5, Vector3(1.0, 1.4, 0.0))
	p.pose = Pose.DUCT
	await _shot(p, "t10_duct_side", Vector3(-0.6, 2.5, -0.3), 0.38, Vector3(2.0, 2.8, -0.3))
	await _shot(p, "t10_duct_corner_exit", Vector3(1.9, 2.5, -0.3), 0.38, Vector3(1.9, 2.7, -1.5))
	await _shot(p, "t10_duct_back_to_vent", Vector3(-0.7, 2.5, -0.35), 0.38, Vector3(-0.72, 2.2, -1.02))
	p.pose = Pose.WALK
	await _shot(p, "t10_balcony_landing", Vector3(1.55, 0, -1.95), 1.5, Vector3(3.2, 1.0, -1.4))
	await _shot(p, "t10_balcony_view_opposite", Vector3(2.3, 0, -1.6), 1.5, Vector3(2.3, 2.4, -4.4))
	await _shot(p, "t10_balcony_look_up_exit", Vector3(1.9, 0, -1.9), 1.5, Vector3(1.9, 2.8, -1.3))
	room.apartment.toggle_window()
	await create_timer(0.7).timeout
	await _shot(p, "t10_window_opened_into_room", Vector3(2.15, 0, -1.75), 1.5, Vector3(2.6, 1.1, 0.8))
	quit()


func _shot(p, name: String, pos: Vector3, eye: float, look: Vector3) -> void:
	p.global_position = pos
	p.camera.position.y = eye
	var d: Vector3 = look - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
