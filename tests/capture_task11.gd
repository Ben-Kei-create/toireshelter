extends SceneTree
## TASK-11 の確認画像（ウィンドウ表示が必要）。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_task11.gd

const Pose := preload("res://scripts/player.gd").Pose
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
	var tub = room.bathtub

	# 3品を拾って所持品欄を3枠埋める
	p.global_position = Vector3(0.0, 0.0, 0.3)
	_aim(p, room.driver_node.global_position)
	p.try_interact()
	p.global_position = Vector3(-0.4, 0.0, 0.6)
	_aim(p, room.supplies.get_node("SupplyShelf/SpareRoll").global_position + Vector3(0, 0.06, 0))
	p.try_interact()
	p.global_position = Vector3(0.0, 0.0, 0.3)
	_aim(p, room.get_node("BathPowder/Visual").global_position + Vector3(0, 0.08, 0))
	p.try_interact()
	_hide_msg(main)
	await _shot(p, "t11_inventory_three_slots", Vector3(0.0, 0.0, 0.5), Vector3(0.0, 1.0, -1.2))

	# 色付き浴槽：リモコンでふろ自動 → 入浴剤
	tub.level = 0.6
	tub.advance(0.0)
	room.bath_remote.interact("remote_power")
	tub.start_reheat()
	p.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(p, tub.to_global(Vector3(0.3, 0.3, 0.375)))
	main.use_selected()
	await create_timer(3.0).timeout
	_hide_msg(main)
	await _shot(p, "t11_tub_yuzu", Vector3(0.35, 0.0, -0.1), tub.to_global(Vector3(0.0, 0.3, 0.0)))
	await _shot(p, "t11_bath_remote", Vector3(0.45, 0.0, -0.55), room.bath_remote.global_position)

	# 着座：左下のパネル（おしり作動中）
	room.toilet.toggle_lid()
	await create_timer(0.6).timeout
	p.global_position = Vector3(0.0, 0.0, 0.35)
	_aim(p, room.toilet.seat_pivot.to_global(Vector3(0.335, 0.012, 0.0)))
	main.do_action()
	await create_timer(0.9).timeout
	room.toilet_panel.interact("washlet_rear")
	_hide_msg(main)
	await _shot_seated(p, "t11_toilet_panel_seated", room.toilet_panel.global_position)
	# 参考：同じ着座位置から画角を狭めた拡大（ゲーム内の画角は 80°）
	p.camera.fov = 25.0
	await _shot_seated(p, "t11_toilet_panel_seated_zoom_reference", room.toilet_panel.global_position)
	main.do_action()
	await create_timer(0.9).timeout
	p.global_position = Vector3(0.3, 0.0, -0.6)
	await create_timer(1.0).timeout   # 立ち上がりの目の高さが落ち着くまで
	p.camera.fov = 30.0
	_hide_msg(main)
	await _shot(p, "t11_bath_remote_zoom_reference", Vector3(0.3, 0.0, -0.6), room.bath_remote.global_position)
	quit()


func _hide_msg(main: Node) -> void:
	main.hud._message_panel.visible = false
	main.hud._message_time_left = 0.0


func _shot(p, name: String, pos: Vector3, look: Vector3) -> void:
	p.global_position = pos
	await _shot_seated(p, name, look)


func _shot_seated(p, name: String, look: Vector3) -> void:
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
