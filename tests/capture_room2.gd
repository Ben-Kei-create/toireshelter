extends SceneTree
## 広げた自室（押入れのクレーンゲーム・キッチン・半分の本棚・黒電話・ギター・剥製・こたつの携帯）の確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 Godot --path . --script res://tests/capture_room2.gd
var main
var p


func _look(pos: Vector3, at: Vector3) -> void:
	p.global_position = pos
	var d: Vector3 = at - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _shot(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(OS.get_environment("SHOT_PREFIX") + name + ".png"))


func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	main = current_scene
	main.hud._message_panel.visible = false
	main.set_process(false)
	p = main.player
	p.set_physics_process(false)
	var apt = main.room.apartment
	apt.toggle_curtain()
	main.room.sky_clock.set_time(0.0)
	await create_timer(1.1).timeout
	_look(Vector3(1.3, 0, 1.8), Vector3(4.3, 0.8, 0.3))
	await _shot("room_wide")
	_look(Vector3(2.6, 0, 1.6), Vector3(5.0, 1.0, -0.3))
	await _shot("room_east")
	_look(Vector3(4.6, 0, 0.9), Vector3(4.7, 1.0, -1.0))
	await _shot("closet_open_crane")
	apt.closet.interact("fusuma")
	await create_timer(1.0).timeout
	await _shot("closet_futon")
	apt.closet.interact("fusuma")
	await create_timer(1.0).timeout
	_look(Vector3(4.6, 0, 0.3), Vector3(5.0, 1.0, 2.4))
	await _shot("kitchen")
	_look(Vector3(3.9, 0, 0.6), Vector3(5.4, 1.2, 0.5))
	await _shot("shelf_phone")
	_look(Vector3(4.3, 0, 0.4), Vector3(5.5, 1.9, 0.9))
	await _shot("guitar_taxidermy")
	_look(Vector3(4.6, 0, 0.9), Vector3(5.5, 2.0, 1.1))
	await _shot("taxidermy_close")
	_look(Vector3(2.0, 0, 0.1), Vector3(2.7, 0.45, 0.85))
	await _shot("kotatsu_phone")
	quit()
