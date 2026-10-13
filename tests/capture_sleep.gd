extends SceneTree
## ダクトの中のステッカー・寝たときの視点・地下室の確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_sleep.gd
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
	p.pose = p.Pose.DUCT
	p.camera.position.y = p.DUCT_EYE_HEIGHT
	_look(Vector3(-0.2, 2.5, -0.3), Vector3(1.5, 2.8, -0.58))
	await _shot("duct_back_wall")
	_look(Vector3(1.4, 2.5, -0.3), Vector3(0.3, 2.8, 0.0))
	await _shot("duct_front_wall")
	_look(Vector3(0.9, 2.5, -0.3), Vector3(0.9, 3.1, -0.3))
	await _shot("duct_ceiling")
	p.pose = p.Pose.LYING
	p.global_position = m.BED_FEET
	p.camera.position.y = m.BED_EYE
	p.rotation.y = m.BED_YAW
	p.camera.rotation.x = p.LYING_PITCH
	await _shot("lying_view")
	quit()
