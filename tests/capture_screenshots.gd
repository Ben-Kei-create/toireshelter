extends SceneTree
## 確認用スクリーンショットを撮る（ウィンドウ表示が必要。--headless では撮れない）。
## 実行: Godot --path . --script res://tests/capture_screenshots.gd
## 保存先: 環境変数 SHOT_DIR（なければ res://docs/screenshots/latest）

const VIEWS := [
	# [ファイル名, プレイヤー位置, 注視点, 撮影前に切り替える状態（省略可）]
	["room_overview", Vector3(0.45, 0.0, 0.95), Vector3(-0.3, 0.9, -1.2)],
	["vent_from_floor", Vector3(0.0, 0.0, 0.75), Vector3(-0.72, 2.2, -1.02)],
	["vent_closeup", Vector3(-0.45, 0.0, -0.25), Vector3(-0.72, 2.2, -1.02)],
	["wall_seams_and_caulk", Vector3(-0.3, 0.0, 0.9), Vector3(0.9, 0.3, -0.6)],
	["front_wall_and_door", Vector3(0.0, 0.0, -0.2), Vector3(0.0, 0.9, 1.2)],
	["door_poster", Vector3(-0.03, 0.0, 0.55), Vector3(-0.03, 1.4, 1.2)],
	["bath_powder", Vector3(-0.2, 0.0, 0.1), Vector3(-0.8, 1.0, -0.08)],
	["bath_powder_closeup", Vector3(-0.45, 0.0, -0.05), Vector3(-0.8, 1.0, -0.08)],
	# TASK-06（状態を切り替える前に撮る）
	["t6_room_overview", Vector3(0.45, 0.0, 0.95), Vector3(-0.45, 0.85, -0.2)],
	["t6_supply_shelf", Vector3(-0.3, 0.0, 0.55), Vector3(-0.83, 1.42, 0.0)],
	["t6_cleaning_stand", Vector3(-0.15, 0.0, 0.45), Vector3(-0.8, 0.2, 1.06)],
	["t6_paper_holder", Vector3(-0.2, 0.0, 0.75), Vector3(-0.83, 0.68, 0.30)],
	["t6_vent_sticker", Vector3(-0.4, 0.0, -0.2), Vector3(-0.6, 2.2, -1.02)],
	["t5_room_overview", Vector3(0.45, 0.0, 0.95), Vector3(-0.3, 0.6, -1.0)],
	["t5_sink_area", Vector3(-0.1, 0.0, 0.2), Vector3(0.8, 0.85, 0.1), "sink_water"],
	["t5_sink_trap_low_reference", Vector3(0.25, 0.0, 0.75), Vector3(0.75, 0.45, 0.1), "low_camera"],
	["t5_toilet_lid_open", Vector3(-0.05, 0.0, 0.3), Vector3(-0.5, 0.3, 0.0), "toilet_open"],
	["t5_toilet_seat_up", Vector3(-0.05, 0.0, 0.35), Vector3(-0.55, 0.45, 0.0), "toilet_seat_up"],
	["t5_tub_filling", Vector3(0.3, 0.0, -0.1), Vector3(0.5, 0.3, -0.9), "tub_filling"],
	["t5_tub_drained", Vector3(0.45, 0.0, -0.15), Vector3(0.62, 0.1, -0.88), "tub_drained"],
	["t5_towel_and_floor_drain", Vector3(0.35, 0.0, 0.0), Vector3(-0.6, 0.6, 0.5)],
	["t7_tank_inside", Vector3(-0.2, 0.0, 0.35), Vector3(-0.8, 0.8, 0.0), "tank_open"],
	["t7_tank_lid_parked", Vector3(0.0, 0.0, -0.2), Vector3(-0.85, 0.3, -0.3)],
	["t7_sink_filled", Vector3(0.2, 0.0, 0.15), Vector3(0.7, 0.8, 0.1), "sink_filled"],
	["t7_mirror_cabinet_open", Vector3(0.2, 0.0, 0.3), Vector3(0.86, 1.45, 0.1), "cabinet_open"],
	["t7_room_overview", Vector3(0.45, 0.0, 0.95), Vector3(-0.3, 0.9, -0.6)],
	["door_open", Vector3(0.0, 0.0, 0.2), Vector3(0.0, 1.2, 2.4)],
	["door_open_poster_from_corridor", Vector3(0.35, 0.0, 2.6), Vector3(-0.35, 1.4, 1.6)],
]


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://docs/screenshots/latest")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	var player = main.player
	main.hud._message_panel.visible = false
	main.hud._message_time_left = 0.0
	for v in VIEWS:
		if String(v[0]).begins_with("door_open") and not main.door_open:
			main.room.exit_area.monitoring = false   # 撮影で廊下に立ってもクリアにしない
			main.door_open = true
			main.room.open_door()
			await create_timer(1.5).timeout
		player.camera.position.y = player.EYE_HEIGHT
		if v.size() > 3:
			await _apply_state(main, player, v[3])
		player.global_position = v[1]
		_aim(player, v[2])
		for i in 8:
			await process_frame
		if v[0] == "vent_from_floor":
			player.try_interact()   # 調べたときのメッセージも写す
			for i in 4:
				await process_frame
		await RenderingServer.frame_post_draw
		var path: String = out.path_join(v[0] + ".png")
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
		main.hud._message_panel.visible = false
		main.hud._message_time_left = 0.0
	quit()


func _apply_state(main: Node, player: Node3D, state: String) -> void:
	var room = main.room
	match state:
		"sink_water":
			room.sink_faucet.set_on(true)
		"low_camera":   # 参考：ゲーム内ではしゃがめないので、カメラだけ床から 0.6m に下げる
			player.camera.position.y = 0.6
		"toilet_open":
			room.toilet.toggle_lid()
			await create_timer(0.6).timeout
		"toilet_seat_up":
			room.toilet.toggle_seat()
			await create_timer(0.6).timeout
		"tub_filling":
			room.bathtub.faucet.set_on(true)
			room.bathtub.advance(18.0)
		"tank_open":
			room.toilet.toggle_tank()
			await create_timer(1.6).timeout
		"sink_filled":
			room.sink.faucet.set_on(true)
			room.sink.set_plug(true)
			room.sink.level = 0.65
			room.sink.advance(0.0)
		"cabinet_open":
			room.mirror_cabinet.toggle()
			await create_timer(0.7).timeout
		"tub_drained":
			room.bathtub.faucet.set_on(false)
			room.bathtub.set_plug(false)
			room.bathtub.advance(60.0)


func _aim(player: Node3D, point: Vector3) -> void:
	var eye: Vector3 = player.camera.global_position
	var d := point - eye
	player.rotation.y = atan2(-d.x, -d.z)
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-85.0), deg_to_rad(85.0))
	player._pitch = pitch
	player.camera.rotation.x = pitch
