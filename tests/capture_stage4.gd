extends SceneTree
## 段階 4 の確認画像：割れた宝石、こたつの中の壁と穴、隣の和室（ライターで照らして）、掛け軸、家宝、テーブルの 3D マップ。
## 実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_stage4.gd
const Pose := preload("res://scripts/player.gd").Pose


func _initialize() -> void:
	_run()


func _shot(main: Node, name: String, pos: Vector3, target: Vector3, eye := -1.0) -> void:
	var p = main.player
	p.global_position = pos
	var d: Vector3 = target - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 8:
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
	var room = main.room
	var apt = room.apartment
	room.rise_unit(main.player, true)
	room.set_power(true, true)
	await process_frame
	await _shot(main, "s4_gem_before", Vector3(2.3, 0.0, 0.6), Vector3(3.3, 0.7, 1.15))
	apt.break_gem(true)
	await _shot(main, "s4_gem_after", Vector3(2.3, 0.0, 0.6), Vector3(3.3, 0.5, 1.15))
	# こたつの中の壁
	var kot = apt.kotatsu
	kot.set_solid(false)
	var ww: Vector3 = kot.global_position + kot.WALL_LOCAL
	main.player.camera.position.y = 0.27
	await _shot(main, "s4_wall", Vector3(ww.x - 0.5, 0.0, ww.z), ww + Vector3(0, 0.2, 0))
	kot.break_wall()
	await _shot(main, "s4_hole", Vector3(ww.x - 0.5, 0.0, ww.z), ww + Vector3(0, 0.2, 0))
	main.player.camera.position.y = 1.5
	# 和室（ライターで照らす）
	room.set_power(false, true)
	room.sky_clock.ambient_scale = 0.01
	room.sky_clock.set_time(room.sky_clock.time)
	main.add_item("lighter")
	main._give_stage4_model("lighter")
	main.select_item(main.inventory.find("lighter"))
	var wp: Vector3 = room.washitsu.global_position
	await _shot(main, "s4_washitsu_a", wp + Vector3(-1.25, 0.0, 0.25), wp + Vector3(0.5, 1.0, -0.6))
	main.player.set_eye_height(1.42)
	room.washitsu.set_scroll_alignment(1.0)
	await _shot(main, "s4_scroll", wp + Vector3(-0.75, 0.0, 0.1), wp + Vector3(-0.75, 1.3, -1.32))
	room.washitsu.set_scroll_alignment(0.0)
	main.player.set_eye_height(1.5)
	await _shot(main, "s4_heirloom", wp + Vector3(0.55, 0.0, -0.55), wp + Vector3(0.55, 0.3, -1.1))
	await _shot(main, "s4_table", wp + Vector3(0.3, 0.0, 1.0), wp + Vector3(0.3, 0.38, 0.25))
	await _shot(main, "s4_washitsu_b", wp + Vector3(1.2, 0.0, 0.9), wp + Vector3(-0.6, 1.0, -0.8))
	quit()
