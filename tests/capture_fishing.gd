extends SceneTree
## 釣り竿・釣り糸・釣果表示の確認画像（画角 80°）。SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_fishing.gd
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
	var f = main.fishing
	_look(Vector3(2.9, 0, -1.7), Vector3(3.64, 1.0, -1.68))
	await _shot("rod_prop")
	_look(Vector3(2.0, 0, -1.6), Vector3(3.6, 0.9, -1.7))
	await _shot("rod_balcony")
	f.has_rod = true
	f.player = p
	_look(Vector3(2.5, 0, -1.9), Vector3(2.5, -1.5, -3.2))
	f.interact("fish_spot")
	await create_timer(1.6).timeout
	await _shot("cast")
	f._wait = 0.0
	await create_timer(0.3).timeout
	await _shot("bite")
	f.interact("fish_spot")
	await create_timer(0.8).timeout
	await _shot("reeling")
	main.hud.show_message(f.last_text)
	main.hud._message_panel.visible = true
	await create_timer(1.5).timeout
	await _shot("caught")
	main._pause()
	await _shot("settings")
	quit()
