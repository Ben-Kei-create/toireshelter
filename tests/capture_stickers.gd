extends SceneTree
## ステッカーと自動販売機の確認画像（画角 80°）。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_stickers.gd
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
	var views := [
		["st_room_rack_plinth", Vector3(2.3, 0, 0.6), 1.5, Vector3(1.4, 0.3, 0.6)],
		["st_room_gem_bookshelf", Vector3(2.6, 0, 0.5), 1.5, Vector3(3.4, 0.6, 1.6)],
		["st_balcony", Vector3(2.4, 0, -1.6), 1.5, Vector3(1.35, 0.9, -1.7)],
		["st_balcony_aircon_top", Vector3(2.8, 0, -1.65), 1.5, Vector3(3.45, 0.45, -1.65)],
		["st_street_wall_pole", Vector3(2.2, 0, -1.85), 1.5, Vector3(1.5, 0.2, -4.4)],
		["st_vending_from_balcony", Vector3(2.9, 0, -1.9), 1.5, Vector3(2.9, -5.6, -4.0)],
		["st_vending_closeup_reference", Vector3(2.9, -6.8, -2.6), 1.5, Vector3(2.9, -5.9, -4.05)],
		["st_vending_side_reference", Vector3(4.0, -6.8, -2.3), 1.5, Vector3(5.0, -5.8, -1.65)],
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
	p.pose = Pose.DUCT
	p.global_position = Vector3(1.9, 2.5, -1.15)
	p.camera.position.y = 0.38
	var d2: Vector3 = Vector3(3.5, -6.0, -3.6) - p.camera.global_position
	p.rotation.y = atan2(-d2.x, -d2.z)
	p.camera.rotation.x = atan2(d2.y, Vector2(d2.x, d2.z).length())
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("st_vending_from_duct_exit.png"))
	quit()
