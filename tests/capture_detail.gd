extends SceneTree
## カレンダー・玄関の靴・ゲームソフト5本・設定画面・床下の中身の確認画像（画角 80°）。SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_detail.gd
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
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name + ".png"))


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
	_look(Vector3(3.8, 0, 1.4), Vector3(3.8, 1.72, 2.4))
	await _shot("calendar")
	_look(Vector3(0.3, 0, 1.6), Vector3(-0.66, 0.05, 2.1))
	await _shot("shoes")
	var game = apt.tv_game
	for i in 4:
		game.select(i)
		game.start() if i == 2 else null
		await create_timer(2.0).timeout
		_look(Vector3(1.6, 0, 1.5), apt.tv_screen_position())
		await _shot("game_%d" % i, 2)
	game.select(4)
	await _shot("game_nodisc", 4)
	_look(Vector3(1.6, 0, 1.5), Vector3(1.5, 0.25, 2.3))
	await _shot("game_cases")
	apt.cellar.set_open(true, false)
	_look(Vector3(4.3, 0, 2.0), Vector3(4.3, -0.3, 1.3))
	await _shot("cellar_items")
	apt.kitchen.interact("fridge_lower")
	await create_timer(0.8).timeout
	_look(Vector3(4.6, 0, 0.9), Vector3(5.0, 0.8, 1.7))
	await _shot("fridge_door_open")
	main._pause()
	await _shot("settings")
	quit()
