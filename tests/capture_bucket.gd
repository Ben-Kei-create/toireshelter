extends SceneTree
## 風呂桶（大きくした）と、逆さに置いた足場の確認画像。実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_bucket.gd
const VIEWS := [
	["bucket_floor", Vector3(0.2, 0, 0.1), Vector3(0.74, 0.15, -0.31), false],
	["bucket_in_tub", Vector3(0.3, 0, 0.1), Vector3(-0.05, 0.3, 0.0), true],
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
		if v[3]:
			main.room.take_bucket()
			main.room.place_bucket_in_tub()
		p.global_position = v[1]
		var tpos: Vector3 = v[2] if not v[3] else main.room.bathtub.to_global(Vector3(-0.05, 0.3, 0.0))
		var d: Vector3 = tpos - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(v[0] + ".png"))
	quit()
