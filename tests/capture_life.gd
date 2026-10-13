extends SceneTree
## 水槽・冷蔵庫と卵・コンロ・ラジオ・壁掛け時計の確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_life.gd
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
	_look(Vector3(4.5, 0, 1.4), Vector3(4.5, 0.95, 0.55))
	await create_timer(1.5).timeout
	await _shot("aquarium")
	apt.aquarium.interact("aquarium")
	await create_timer(3.0).timeout
	await _shot("aquarium_feeding")
	_look(Vector3(3.8, 0, 1.0), Vector3(4.5, 0.9, 0.55))
	await _shot("aquarium_side")
	var k = apt.kitchen
	k.interact("fridge_lower")
	k.interact("fridge_upper")
	await create_timer(0.8).timeout
	_look(Vector3(5.0, 0, 0.9), Vector3(5.15, 0.85, 2.3))
	await _shot("fridge_open")
	k.interact("fridge_egg_0")
	k.interact("fridge_egg_1")
	k.interact("fridge_lower")
	k.interact("fridge_upper")
	await create_timer(0.8).timeout
	k.interact("kitchen_stove")
	k.interact("kitchen_stove")
	_look(Vector3(4.4, 0, 1.1), Vector3(4.55, 0.9, 2.1))
	await create_timer(0.5).timeout
	await _shot("stove_raw")
	await create_timer(7.0).timeout
	await _shot("stove_cooked")
	_look(Vector3(3.5, 0, 0.3), Vector3(3.6, 0.4, -0.9))
	apt.radio.interact("radio")
	await _shot("radio")
	_look(Vector3(3.9, 0, 1.2), Vector3(5.5, 2.0, 1.95))
	await _shot("clock")
	quit()
