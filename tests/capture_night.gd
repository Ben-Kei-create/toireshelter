extends SceneTree
## 24 時のインターホン・玄関ドアの内側（のぞき穴・ミニポスト）・タンクのコイン・ベランダの置き物の確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_night.gd
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
	var ic = apt.intercom
	_look(Vector3(0.0, 0, 1.6), Vector3(-0.45, 1.4, 2.4))
	await _shot("intercom_idle")
	_look(Vector3(0.3, 0, 1.7), Vector3(-0.9, 1.0, 1.85))
	await _shot("door_inside")
	ic.ring()
	await create_timer(0.2).timeout
	await _shot("flicker_dark")
	await create_timer(1.3).timeout
	_look(Vector3(0.0, 0, 1.6), Vector3(-0.45, 1.4, 2.4))
	await _shot("intercom_visitor")
	main._open_peephole()
	await _shot("peephole")
	main._close_peephole()
	main.hud._message_panel.visible = false   # のぞいたときのメッセージが、次の絵に残らないように
	var t = main.room.toilet
	t.toggle_tank()
	await create_timer(1.8).timeout
	_look(Vector3(-0.3, 0, 0.5), Vector3(-0.8, 0.84, 0.02))
	await _shot("tank_coin")
	var f = main.fishing
	for i in 8:
		f._place(f.CATCHES[i * 3])
	_look(Vector3(2.3, 0, -1.6), Vector3(2.4, 0.0, -2.0))
	await _shot("balcony_catches")
	quit()
