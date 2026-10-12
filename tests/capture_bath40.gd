extends SceneTree
## タオル裏の傷の確認画像（画角 80°。ずらしたタオルの裏を通常視点と近寄った視点で）。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 Godot --path . --script res://tests/capture_bath40.gd
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
	main.room.towel.toggle()
	await create_timer(0.6).timeout
	var target: Vector3 = main.room.towel.to_global(Vector3(0.0, -0.27, -0.09))
	for v in [["towel_scratch_normal", Vector3(0.0, 0, 0.7)], ["towel_scratch_near", Vector3(-0.45, 0, 0.62)]]:
		p.global_position = v[1]
		var d: Vector3 = target - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(OS.get_environment("SHOT_PREFIX") + v[0] + ".png"))
	quit()
