extends SceneTree
## テレビ台まわりのケース・本 2 か所・レコード周辺・冷蔵庫・電子レンジの確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_assets_final.gd
var p


func _look(pos: Vector3, at: Vector3) -> void:
	p.global_position = pos
	var d: Vector3 = at - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _shot(n: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(n + ".png"))


func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var m = current_scene
	p = m.player
	p.set_physics_process(false)
	m.hud._message_panel.visible = false
	_look(Vector3(1.7, 0.0, 1.0), Vector3(1.55, 0.0, 1.85))
	await _shot("tv_cases")
	_look(Vector3(4.3, 0.0, 0.9), Vector3(4.2, 0.0, 0.08))
	await _shot("books_a")
	_look(Vector3(4.9, 0.0, 0.9), Vector3(4.78, 0.0, 0.1))
	await _shot("books_b")
	_look(Vector3(2.7, 0.0, 0.2), Vector3(1.8, 0.0, 0.2))
	await _shot("record_area")
	_look(Vector3(5.0, 0.0, 0.9), Vector3(5.15, 1.0, 1.78))
	await _shot("fridge")
	_look(Vector3(4.2, 0.0, 1.3), Vector3(4.21, 2.15, 2.15))
	await _shot("microwave")
	quit()
