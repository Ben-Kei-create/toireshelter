extends SceneTree
## 路地・室外機・浴室ラベル・紙・コルクボードの確認画像（画角 80°）。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_street.gd
const Pose := preload("res://scripts/player.gd").Pose


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
	await _shot(p, "street_from_balcony_down", Vector3(2.4, 0, -1.85), 1.5, Vector3(2.4, -2.0, -4.4))
	await _shot(p, "street_from_balcony_left", Vector3(1.55, 0, -1.9), 1.5, Vector3(-3.0, -1.5, -3.2))
	await _shot(p, "street_from_balcony_right", Vector3(3.0, 0, -1.9), 1.5, Vector3(7.5, -1.2, -3.0))
	await _shot(p, "street_from_balcony_level", Vector3(2.2, 0, -1.9), 1.5, Vector3(2.2, 1.0, -4.4))
	await _shot(p, "balcony_aircon", Vector3(2.3, 0, -1.6), 1.5, Vector3(3.45, 0.3, -1.62))
	p.pose = Pose.DUCT
	await _shot(p, "street_from_duct_exit", Vector3(1.9, 2.5, -1.15), 0.38, Vector3(1.0, -1.0, -4.4))
	p.pose = Pose.WALK
	await _shot(p, "hall_corkboard", Vector3(0.3, 0, 1.85), 1.5, Vector3(-0.9, 1.42, 1.85))
	room.mirror_cabinet.unlock()
	await create_timer(0.4).timeout
	room.mirror_cabinet.toggle()
	await create_timer(0.7).timeout
	await _shot(p, "cabinet_labels", Vector3(0.35, 0, 0.15), 1.5, Vector3(0.95, 1.38, 0.1))
	await _shot(p, "tub_bottles_labels", Vector3(0.45, 0, -0.2), 1.5, room.bathtub.to_global(Vector3(0.86, 0.65, -0.15)))
	p.global_position = Vector3(0.3, 0, -0.2)
	var d: Vector3 = room.bathtub.to_global(Vector3(0.3, 0.3, 0.375)) - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	main.do_action()
	await create_timer(0.9).timeout
	await _shot(p, "tub_note_from_inside", p.global_position, -1.0, room.bathtub.to_global(room.bathtub.NOTE_POS))
	quit()


func _shot(p, name: String, pos: Vector3, eye: float, look: Vector3) -> void:
	p.global_position = pos
	if eye > 0.0:
		p.camera.position.y = eye
	var d: Vector3 = look - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-85.0), deg_to_rad(85.0))
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name + ".png"))
