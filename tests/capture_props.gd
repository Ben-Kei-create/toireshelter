extends SceneTree
## じゅうたん・床下の貯蔵庫・小物・テレビゲームの確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 xvfb-run -a Godot --path . --script res://tests/capture_props.gd
var main
var p


func _initialize() -> void:
	_run()


func _look(pos: Vector3, at: Vector3) -> void:
	p.global_position = pos
	var d: Vector3 = at - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _shot(name: String, frames := 6) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(OS.get_environment("SHOT_PREFIX") + name + ".png"))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	main = current_scene
	main.hud._message_panel.visible = false
	p = main.player
	p.set_physics_process(false)
	var apt = main.room.apartment
	_look(Vector3(1.3, 0, 2.0), Vector3(3.0, 0.0, 0.5))
	await _shot("rug_overview")
	_look(Vector3(3.3, 0, 1.55), Vector3(2.6, 0.4, 0.78))
	await _shot("table_items")
	_look(Vector3(2.75, 0, 0.0), Vector3(2.45, 0.38, 0.65))
	await _shot("table_cards")
	_look(Vector3(3.7, 0, 1.6), Vector3(3.6, 0.0, 1.15))
	await _shot("floor_cards")
	_look(Vector3(3.9, 0, 2.2), Vector3(4.3, 0.0, 1.3))
	await _shot("cellar_closed")
	apt.cellar.interact("cellar")
	await create_timer(0.8).timeout
	await _shot("cellar_open")
	_look(Vector3(4.3, 0, 1.9), Vector3(4.3, -0.3, 1.3))
	await _shot("cellar_inside")
	_look(Vector3(4.3, 0, 0.0), Vector3(4.7, 0.1, 0.3))
	await _shot("tissue_magazines")
	_look(Vector3(4.2, 0, 1.0), Vector3(5.0, 0.15, 0.6))
	await _shot("teddy")
	_look(Vector3(1.6, 0, 1.5), apt.tv_screen_position())
	await create_timer(1.0).timeout
	await _shot("tv_demo")
	main.gaming = false
	main._start_game()
	await create_timer(2.0).timeout
	await _shot("tv_playing")
	quit()
