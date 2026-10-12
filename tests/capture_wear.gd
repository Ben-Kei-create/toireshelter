extends SceneTree
## 浴室の汚れ・傷の確認画像（画角 80°）。視点は下の VIEWS（[名前, 立つ位置, 見る点]）。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 Godot --path . --script res://tests/capture_wear.gd
const VIEWS := [
	["back_wall", Vector3(0.0, 0, 0.6), Vector3(0.1, 1.4, -1.2)],
	["tub_front", Vector3(0.0, 0, 0.45), Vector3(0.0, 0.25, -0.45)],
	["right_wall", Vector3(-0.5, 0, 0.3), Vector3(0.9, 1.0, 0.25)],
	["mirror", Vector3(0.1, 0, 0.5), Vector3(0.9, 1.5, 0.25)],
	["left_wall", Vector3(0.3, 0, 0.8), Vector3(-0.9, 0.9, 0.7)],
	["floor_bucket", Vector3(0.0, 0, 0.1), Vector3(0.6, 0.0, -0.3)],
	["floor_door", Vector3(0.0, 0, -0.1), Vector3(0.05, 0.0, 1.0)],
	["tub_inside", Vector3(0.3, 0, 0.0), Vector3(0.0, 0.55, -1.2)],
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
