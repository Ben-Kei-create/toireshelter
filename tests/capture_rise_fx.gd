extends SceneTree
## せり上がりの途中（煙・ひび）の確認画像。
## 実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_rise_fx.gd
func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	main.hud.visible = false
	var p = main.player
	p.set_physics_process(false)
	p.global_position = Vector3(0.3, 0.0, 2.2)
	var d: Vector3 = Vector3(0.0, 1.6, 1.2) - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	main.room.mirror_cabinet.pull_lever_visual(true)
	var dummy := Node3D.new()
	main.add_child(dummy)
	main.room.rise_unit(dummy)
	for k in 3:
		await create_timer(2.6).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("rise_fx_%d.png" % k))
	await create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("rise_fx_end.png"))
	quit()
