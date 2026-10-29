extends SceneTree
## 段階 1c の確認画像：身を乗り出して右手の KO線を見る、はしご。画角 80°。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_balcony2.gd
const VIEWS := [
	["lean_right", Vector3(2.9, 0.0, -2.42), Vector3(24.0, 0.5, -14.0)],
	["lean_right2", Vector3(2.9, 0.0, -2.42), Vector3(30.0, -3.0, -60.0)],
	["lean_down", Vector3(2.5, 0.0, -2.42), Vector3(2.5, -10.0, -4.5)],
	["ladder", Vector3(1.7, 0.0, -1.85), Vector3(1.66, 1.2, -1.38)],
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
	main.room.exterior.lower_ladder(2.5, true)
	main.room.exterior._ko_z = -6.0
	main.room.exterior._process(0.0)
	main.room.sky_clock.set_time(700.0)
	for v in VIEWS:
		p.global_position = v[1]
		p.camera.position.y = 1.3
		var d: Vector3 = v[2] - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(v[0] + ".png"))
	quit()
