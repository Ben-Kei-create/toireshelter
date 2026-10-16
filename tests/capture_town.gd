extends SceneTree
## 外の建物の広告（ポスター・広告塔）と屋上のバーベキュー会場の確認画像（画角 80°、廊下から）。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 Godot --path . --script res://tests/capture_town.gd
const VIEWS := [
	["bbq_day", Vector3(-2.1, 0, 4.5), Vector3(-14.0, 2.2, 15.0), 0.0],
	["bbq_sunset", Vector3(-2.1, 0, 4.5), Vector3(-14.0, 2.2, 15.0), 360.0],
	["bbq_dusk", Vector3(-2.1, 0, 4.5), Vector3(-14.0, 2.2, 15.0), 700.0],
	["ads_north", Vector3(-2.1, 0, 0.5), Vector3(-16.0, 4.0, -6.0), 360.0],
	["ads_west", Vector3(-2.1, 0, 2.0), Vector3(-16.0, 5.0, 2.0), 360.0],
	["ads_south", Vector3(-2.1, 0, 5.0), Vector3(-14.0, -1.0, 22.0), 360.0],
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
	for v in VIEWS:
		main.room.sky_clock.set_time(v[3])
		p.global_position = v[1]
		var d: Vector3 = v[2] - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(OS.get_environment("SHOT_PREFIX") + v[0] + ".png"))
	quit()
