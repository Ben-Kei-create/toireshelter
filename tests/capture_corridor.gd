extends SceneTree
## 玄関ホール・玄関ドア・5階の廊下・下南澤の街並みの確認画像（画角 80°）。玄関ドアを開けて撮る。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 Godot --path . --script res://tests/capture_corridor.gd
const VIEWS := [
	["hall_door", Vector3(0.4, 0, 1.85), Vector3(-0.95, 1.2, 1.85)],
	["hall_end", Vector3(0.0, 0, 1.55), Vector3(0.0, 1.2, 2.4)],
	["hall_wide", Vector3(0.7, 0, 1.45), Vector3(-0.3, 1.1, 2.2)],
	["corr_south", Vector3(-1.9, 0, 1.2), Vector3(-1.85, 1.3, 6.4)],
	["corr_north", Vector3(-1.9, 0, 3.0), Vector3(-1.85, 1.3, -1.3)],
	["town_west", Vector3(-2.1, 0, 1.2), Vector3(-9.0, -1.0, 2.0)],
	["town_southwest", Vector3(-2.1, 0, 4.0), Vector3(-9.0, -1.5, 14.0)],
	["town_down", Vector3(-2.0, 0, 1.0), Vector3(-6.0, -9.0, 0.0)],
	["neighbors", Vector3(-2.2, 0, 2.6), Vector3(-1.0, 1.3, 4.3)],
	["elevator", Vector3(-1.85, 0, 4.8), Vector3(-1.85, 1.3, 6.4)],
]


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
	main.room.open_door()
	main.room.front_door.interact("front_door")
	await create_timer(1.6).timeout
	for v in VIEWS:
		p.global_position = v[1]
		var d: Vector3 = v[2] - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(OS.get_environment("SHOT_PREFIX") + v[0] + ".png"))
	quit()
