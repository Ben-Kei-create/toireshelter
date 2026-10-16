extends SceneTree
## 和室の仏壇と提灯の確認画像。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_washitsu_decor.gd
func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	main.hud.visible = false
	main.set_process(false)
	var p = main.player
	p.set_physics_process(false)
	var w = main.room.washitsu
	w.open_heirloom(true)
	main.room.sky_clock.ambient_scale = 0.05
	var base: Vector3 = w.global_position
	for v in [["night", Vector3(-1.3, 0.0, 0.9), Vector3(0.9, 1.0, -0.3)], ["butsudan", Vector3(-0.7, 0.0, -0.4), Vector3(1.7, 0.9, -0.45)], ["lanterns", Vector3(-1.4, 0.0, 0.9), Vector3(1.0, 1.9, -0.6)], ["attic", Vector3(0.0, 0.0, 0.4), Vector3(0.0, 3.0, -1.3)]]:
		p.global_position = base + v[1]
		var d: Vector3 = (base + v[2]) - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("washitsu_%s.png" % v[0]))
	quit()
