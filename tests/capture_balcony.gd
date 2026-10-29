extends SceneTree
## ベランダと廊下から下を見下ろした確認画像（地面や建物の下に透けて見える所がないか）。画角 80°。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 Godot --path . --script res://tests/capture_balcony.gd
const VIEWS := [
	["b_down", Vector3(2.5, 0, -1.9), Vector3(2.5, -12.0, -2.6)],
	["b_down_left", Vector3(1.5, 0, -1.9), Vector3(-4.0, -9.0, -3.5)],
	["b_down_right", Vector3(3.5, 0, -1.9), Vector3(9.0, -9.0, -3.5)],
	["b_far_left", Vector3(1.5, 0, -1.9), Vector3(-9.0, -7.0, -3.0)],
	["b_far_right", Vector3(3.5, 0, -1.9), Vector3(14.0, -7.0, -3.0)],
	["b_under", Vector3(2.5, 0, -2.0), Vector3(2.5, -20.0, -1.3)],
	["c_down_west", Vector3(-2.1, 0, 1.5), Vector3(-6.0, -13.0, 1.5)],
	["c_down_north", Vector3(-2.1, 0, -0.9), Vector3(-3.5, -13.0, -4.0)],
	["c_down_south", Vector3(-2.1, 0, 5.5), Vector3(-5.0, -13.0, 9.0)],
	["c_down_wall", Vector3(-2.2, 0, 3.0), Vector3(-1.0, -13.0, 3.0)],
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
	main.set_process(false)
	var p = main.player
	p.set_physics_process(false)
	main.room.sky_clock.set_time(0.0)
	for v in VIEWS:
		p.global_position = v[1]
		var d: Vector3 = v[2] - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(OS.get_environment("SHOT_PREFIX") + v[0] + ".png"))
	quit()
