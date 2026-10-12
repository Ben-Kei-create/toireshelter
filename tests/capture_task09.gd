extends SceneTree
## TASK-09 の確認画像（ウィンドウ表示が必要）。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_task09.gd

var out := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	out = OS.get_environment("SHOT_DIR")
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	var p = main.player
	var room = main.room
	var sup = room.supplies
	main.hud._message_panel.visible = false
	main.hud._message_time_left = 0.0

	# 1：浴槽内の紙
	p.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(p, room.bathtub.to_global(Vector3(0.3, 0.3, 0.375)))
	main.do_action()
	await create_timer(0.9).timeout
	await _shot(p, "t9_tub_note_from_inside", room.bathtub.to_global(room.bathtub.NOTE_POS))
	main.do_action()
	await create_timer(0.9).timeout

	# 2：タオルの裏の傷
	room.towel.toggle()
	await create_timer(0.6).timeout
	p.global_position = Vector3(-0.2, 0.0, 0.7)
	await _shot(p, "t9_towel_slid_scratches", room.towel.to_global(Vector3(0.0, -0.25, -0.05)))
	room.towel.toggle()
	await create_timer(0.6).timeout

	# 3：座って見上げた棚の裏の紙
	room.toilet.toggle_lid()
	await create_timer(0.6).timeout
	p.global_position = Vector3(0.0, 0.0, 0.35)
	_aim(p, room.toilet.seat_pivot.to_global(Vector3(0.335, 0.012, 0.0)))
	main.do_action()
	await create_timer(0.9).timeout
	await _shot(p, "t9_shelf_note_seated", sup.SHELF_NOTE_POS)
	main.do_action()
	await create_timer(0.9).timeout
	room.toilet.toggle_lid()
	await create_timer(0.6).timeout

	# 4：しゃがんで見たタンクの下の紙
	p.global_position = Vector3(-0.05, 0.0, 0.45)
	p.toggle_crouch()
	await create_timer(1.0).timeout
	await _shot(p, "t9_tank_note_crouched", sup.TANK_NOTE_POS)
	p.toggle_crouch()
	await create_timer(1.0).timeout

	# 持ち物：拾って所持品欄と拡大表示
	p.global_position = Vector3(0.0, 0.0, 0.3)
	_aim(p, room.driver_node.global_position)
	p.try_interact()
	p.global_position = Vector3(-0.4, 0.0, 0.6)
	_aim(p, sup.get_node("SupplyShelf/SpareRoll").global_position + Vector3(0, 0.06, 0))
	p.try_interact()
	main.hud._message_panel.visible = false
	main.hud._message_time_left = 0.0
	await _shot(p, "t9_inventory_bar", Vector3(0.0, 1.2, -1.0))
	main.toggle_zoom()
	await create_timer(0.5).timeout
	await _shot(p, "t9_item_zoom_roll", Vector3(0.0, 1.2, -1.0))
	main.select_item(0)
	await create_timer(0.5).timeout
	await _shot(p, "t9_item_zoom_driver", Vector3(0.0, 1.2, -1.0))
	main.toggle_zoom()

	# ペーパーホルダー：カバーを開けた状態（芯だけ）→ 交換後
	sup.toggle_cover()
	await create_timer(0.5).timeout
	p.global_position = Vector3(-0.3, 0.0, 0.75)
	main.select_item(1)
	await _shot(p, "t9_holder_cover_open_core", sup.get_node("PaperHolder").global_position + Vector3(0.06, 0.0, 0.0))
	_aim(p, sup.get_node("PaperHolder").global_position + Vector3(0.08, -0.02, 0.0))
	main.use_selected()
	await create_timer(0.9).timeout
	main.hud._message_panel.visible = false
	main.hud._message_time_left = 0.0
	await _shot(p, "t9_holder_after_swap", sup.get_node("PaperHolder").global_position + Vector3(0.06, 0.0, 0.0))
	p.global_position = Vector3(-0.4, 0.0, 0.5)
	await _shot(p, "t9_core_on_dish", sup.DISH_POS)
	quit()


func _shot(p, name: String, look: Vector3) -> void:
	_aim(p, look)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


func _aim(p, point: Vector3) -> void:
	var d: Vector3 = point - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-85.0), deg_to_rad(85.0))
	p._pitch = pitch
	p.camera.rotation.x = pitch
