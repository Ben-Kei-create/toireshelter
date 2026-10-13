extends SceneTree
## ユーザーの画像（トランプ・水槽・時計・インターホン・のぞき穴・くま・コイン・カレンダー・ラジオ・ティッシュ・卵）と宝石・ダクトの確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_images2.gd
var p


func _look(pos: Vector3, at: Vector3) -> void:
	p.global_position = pos
	var d: Vector3 = at - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _shot(n: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(n + ".png"))


func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var m = current_scene
	p = m.player
	p.set_physics_process(false)
	m.hud._message_panel.visible = false
	var apt = m.room.apartment
	_look(Vector3(2.0, 0.0, 0.2), Vector3(2.45, 0.4, 0.7))
	await _shot("cards_kotatsu")
	_look(Vector3(4.3, 0.55, 1.95), Vector3(5.5, 2.0, 1.95))
	await _shot("clock")
	_look(Vector3(3.8, 0.3, 1.8), Vector3(3.8, 1.72, 2.4))
	await _shot("calendar")
	_look(Vector3(-0.45, 0, 1.75), Vector3(-0.45, 1.4, 2.4))
	await _shot("intercom_idle")
	apt.intercom.ring()
	await create_timer(1.5).timeout
	await _shot("intercom_ringing")
	_look(Vector3(3.6, 0, -0.3), Vector3(3.6, 0.42, -0.9))
	await _shot("radio")
	_look(Vector3(3.7, 0, 0.5), Vector3(3.7, 0.05, -0.25))
	await _shot("tissue")
	_look(Vector3(3.05, 0.0, 1.55), Vector3(3.05, 0.46, 2.0))
	await _shot("teddy")
	_look(Vector3(4.2, 0, 0.82), Vector3(5.3, 1.0, 0.82))
	await _shot("aquarium")
	_look(Vector3(2.5, 0, 1.5), Vector3(3.3, 0.8, 1.15))
	await _shot("gem")
	apt.kitchen.interact("fridge_upper") if false else null
	m.hud.show_card(load("res://assets/textures/props/card_h_Q.png"), 30.0)
	await _shot("card_popup")
	m.hud.show_item_zoom(m.room.toilet.get("coin_root"), "x", "x") if false else null
	p.pose = p.Pose.DUCT
	p.camera.position.y = p.DUCT_EYE_HEIGHT
	_look(Vector3(-0.2, 2.5, -0.3), Vector3(1.5, 2.8, -0.58))
	await _shot("duct_dark")
	quit()
