extends SceneTree
## クレーンゲームと本棚の確認画像（画角 80°）。読書画面と、遊んでいる途中・遊んだあとも撮る。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 Godot --path . --script res://tests/capture_books_ufo.gd
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
	_look(Vector3(2.4, 0, 0.0), Vector3(3.3, 1.0, 0.0))
	await _shot("ufo_front")
	_look(Vector3(2.0, 0, 0.85), Vector3(3.3, 0.9, 0.0))
	await _shot("ufo_wide")
	var ufo = main.room.apartment.ufo_catcher
	ufo.interact("ufo_catcher")
	await create_timer(2.6).timeout
	await _shot("ufo_down", 2)
	await create_timer(7.0).timeout
	await _shot("ufo_after_1", 2)
	ufo.interact("ufo_catcher")
	await create_timer(9.5).timeout
	ufo.interact("ufo_catcher")
	await create_timer(3.0).timeout
	await _shot("ufo_grab", 2)
	await create_timer(7.0).timeout
	_look(Vector3(2.4, 0, 0.15), Vector3(3.3, 0.45, 0.15))
	await _shot("ufo_outlet")
	_look(Vector3(2.9, 0, 0.5), Vector3(3.7, 1.0, 0.5))
	await _shot("shelf")
	var books = main.room.apartment.books
	books.interact("book_01")
	await _shot("reader_book01_p1", 3)
	main._reader_page = 1
	main._show_reader_page()
	await _shot("reader_book01_p2", 3)
	main._close_reader()
	p.global_position = Vector3(3.0, 0, 0.2)
	books.interact("shelf_books")
	await _shot("reader_spine", 3)
	main._close_reader()
	quit()
