extends SceneTree
## 玄関の三和土・トイレのカバー・温水洗浄の水・テレビ裏の配線・換気扇・コルク銃と射的・等身大パネル・鏡の顔・設定の肖像の確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_gadget.gd
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
	_look(Vector3(0.2, 0, 1.45), Vector3(-0.75, 0.0, 2.0))
	await _shot("genkan")
	_look(Vector3(0.6, 0, 1.3), Vector3(-0.5, 0.35, 1.9))
	await _shot("genkan_step")
	_look(Vector3(3.0, 0, 1.5), Vector3(3.8, 1.0, 2.1))
	await _shot("standee")
	_look(Vector3(0.2, 0, 0.1), Vector3(0.9, 1.52, 0.1))
	await _shot("mirror_front")
	_look(Vector3(0.0, 0, 0.75), Vector3(0.9, 1.5, 0.1))
	await _shot("mirror_side")
	var t = main.room.toilet
	t.toggle_lid()
	await create_timer(0.8).timeout
	_look(Vector3(-0.1, 0, -0.1), Vector3(-0.5, 0.45, 0.0))
	await _shot("toilet_covers")
	t.occupied = true
	main.room.toilet_panel.interact("washlet_rear")
	await create_timer(0.4).timeout
	_look(Vector3(-0.1, 0, 0.35), Vector3(-0.5, 0.25, 0.0))
	await _shot("spray_rear")
	main.room.toilet_panel.interact("washlet_bidet")
	await create_timer(0.3).timeout
	await _shot("spray_bidet")
	main.room.toilet_panel.stop()
	_look(Vector3(0.5, 0, 0.7), Vector3(0.68, 0.0, 0.98))
	await _shot("toilet_slippers")
	_look(Vector3(1.5, 0, 1.6), Vector3(1.3, 0.3, 2.4))
	await _shot("tv_cables")
	_look(Vector3(4.2, 0, 1.0), Vector3(4.63, 1.43, 1.9))
	apt.kitchen.interact("hood_3")
	await create_timer(0.3).timeout
	await _shot("hood_kyou")
	apt.kitchen.interact("hood_3")
	_look(Vector3(5.1, 0, 0.9), Vector3(5.12, 1.72, 1.77))
	await _shot("gun_on_fridge")
	main._on_interact_requested(apt.kitchen.gun_area)
	main.select_item(main.inventory.find("cork_gun"))
	_look(Vector3(2.0, 0, 1.3), Vector3(1.6, 1.3, -1.0))
	main._gun_cool = 0.0
	main._fire(apt.figures[3].node.get_node("FigureArea"))
	await create_timer(0.1).timeout
	await _shot("shoot_hit")
	await create_timer(1.0).timeout
	await _shot("shoot_after")
	main._pause()
	await _shot("settings")
	quit()
