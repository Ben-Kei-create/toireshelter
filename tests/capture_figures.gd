extends SceneTree
## 置物・お酒のセラー・ペタペタ貼ったシールの確認画像。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_figures.gd
func _initialize() -> void:
	_run()


func _shot(main: Node, name: String, pos: Vector3, target: Vector3) -> void:
	var p = main.player
	p.global_position = pos
	var d: Vector3 = target - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name + ".png"))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	main.hud._message_panel.visible = false
	main.set_process(false)
	main.player.set_physics_process(false)
	# お酒のセラー：せり上がった浴室の下の柱にはめ込まれている（電気がついた状態）。ヒビ → 割れた
	var room = main.room
	room.rise_unit(main.player, true)
	room.set_power(true, true)
	await process_frame
	var cel = room.wine_cellar
	var c_center: Vector3 = cel.to_global(Vector3(0.5, 0.21, 0.0))
	await _shot(main, "fig_cellar", Vector3(-0.3, 0.0, 2.1), c_center)
	for i in 5:
		cel.add_crack(cel.to_global(Vector3(0.15 + 0.17 * i, 0.12 + 0.08 * (i % 3), 0.03)))
	await _shot(main, "fig_cellar_cracked", Vector3(-0.3, 0.0, 1.8), c_center)
	cel.break_glass(true)
	await _shot(main, "fig_cellar_broken", Vector3(-0.3, 0.0, 1.8), c_center)
	await _shot(main, "fig_desk", Vector3(2.0, 0.0, 0.5), Vector3(1.4, 0.8, -0.6))
	await _shot(main, "fig_floor", Vector3(2.8, 0.0, 0.2), Vector3(2.7, 0.3, -1.05))
	await _shot(main, "fig_drain", Vector3(-0.1, 0.0, 0.5), Vector3(-0.15, 0.0, -0.33))
	await _shot(main, "fig_tub", Vector3(0.0, 0.0, 0.2), Vector3(-0.1, 0.3, -0.45))
	await _shot(main, "fig_corridor", Vector3(-1.85, 0.0, 0.0), Vector3(-2.4, 0.0, 3.0))
	quit()
