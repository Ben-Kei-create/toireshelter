extends SceneTree
## 廊下と、廊下から見える街並み（写真を使った遠景・バーベキュー会場の建物）の確認画像。画角 80°。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_corridor.gd
const VIEWS := [
	["co_west", Vector3(-1.9, 0, 3.0), Vector3(-30.0, 1.0, 3.0)],
	["co_west_bbq", Vector3(-2.0, 0, 6.0), Vector3(-30.0, 4.0, 10.0)],
	["co_north", Vector3(-1.85, 0, 5.8), Vector3(-1.85, 1.2, -1.0)],
	["co_south", Vector3(-1.85, 0, -0.8), Vector3(-1.85, 1.2, 6.0)],
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
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(v[0] + ".png"))
	quit()
