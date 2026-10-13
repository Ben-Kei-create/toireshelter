extends SceneTree
## 針なし文字盤の時計と、こたつの上のトランプ・床のカードの確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_cards_clock.gd
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
	_look(Vector3(4.55, 0.3, 1.95), Vector3(5.5, 2.0, 1.95))
	await _shot("clock")
	_look(Vector3(2.0, 0.0, 0.3), Vector3(2.45, 0.4, 0.65))
	await _shot("cards_kotatsu")
	m.hud.show_card(load("res://assets/textures/props/card_s_Q.png"), 30.0)
	await _shot("card_popup")
	quit()
