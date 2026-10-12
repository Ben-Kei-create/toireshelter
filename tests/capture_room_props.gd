extends SceneTree
## 雑貨のスタンド・額・コルクボード・棚の化粧板の確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 Godot --path . --script res://tests/capture_room_props.gd
const VIEWS := [
	["desk", Vector3(2.0, 0, -0.55), Vector3(1.5, 0.78, -0.55)],
	["desk_close", Vector3(1.95, 0, -0.55), Vector3(1.58, 0.78, -0.58)],
	["overhead_pic", Vector3(0.3, 0, 0.72), Vector3(0.9, 1.3, 0.72)],
	["supply_shelf", Vector3(0.0, 0, 0.0), Vector3(-0.8, 1.3, 0.0)],
	["paper_holder", Vector3(-0.3, 0, 0.4), Vector3(-0.85, 0.7, 0.3)],
	["room_whole", Vector3(3.6, 0, 1.8), Vector3(2.0, 0.9, -0.4)],
	["tv_corner", Vector3(1.6, 0, 0.9), Vector3(1.6, 0.4, 2.4)],
	["tv_close", Vector3(1.55, 0, 1.75), Vector3(1.58, 0.3, 2.4)],
	["tv_shelf", Vector3(1.6, 0, 1.95), Vector3(1.6, 0.17, 2.4)],
	["hall_slippers", Vector3(-0.2, 0, 1.45), Vector3(-0.64, 0.0, 1.55)],
	["bath_slippers", Vector3(0.0, 0, 0.5), Vector3(0.68, 0.0, 0.98)],
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
