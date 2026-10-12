extends SceneTree
## 照明の比較用に、同じ視点のスクリーンショットを撮る（ウィンドウ表示が必要）。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 Godot --path . --script res://tests/capture_lighting.gd

const VIEWS := [
	["overview", Vector3(0.45, 0.0, 0.95), Vector3(-0.3, 0.7, -0.8)],
	["toilet", Vector3(0.0, 0.0, 0.35), Vector3(-0.6, 0.55, 0.0)],
	["sink", Vector3(-0.1, 0.0, 0.2), Vector3(0.8, 0.9, 0.1)],
	["floor_driver", Vector3(0.1, 0.0, 0.45), Vector3(0.6, 0.0, 0.05)],
]


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := OS.get_environment("SHOT_DIR")
	var prefix := OS.get_environment("SHOT_PREFIX")
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	main.hud._message_panel.visible = false
	main.hud._message_time_left = 0.0
	main.room.toilet.toggle_lid()
	await create_timer(0.6).timeout
	var p = main.player
	for v in VIEWS:
		p.global_position = v[1]
		var eye: Vector3 = p.camera.global_position
		var d: Vector3 = v[2] - eye
		p.rotation.y = atan2(-d.x, -d.z)
		var pitch := atan2(d.y, Vector2(d.x, d.z).length())
		p._pitch = pitch
		p.camera.rotation.x = pitch
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(prefix + v[0] + ".png"))
	quit()
