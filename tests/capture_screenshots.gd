extends SceneTree
## 確認用スクリーンショットを撮る（ウィンドウ表示が必要。--headless では撮れない）。
## 実行: Godot --path . --script res://tests/capture_screenshots.gd
## 保存先: 環境変数 SHOT_DIR（なければ res://docs/screenshots/latest）

const VIEWS := [
	# [ファイル名, プレイヤー位置, 注視点]
	["room_overview", Vector3(0.45, 0.0, 0.95), Vector3(-0.3, 0.9, -1.2)],
	["vent_from_floor", Vector3(0.0, 0.0, 0.75), Vector3(-0.72, 2.2, -1.02)],
	["vent_closeup", Vector3(-0.45, 0.0, -0.25), Vector3(-0.72, 2.2, -1.02)],
	["wall_seams_and_caulk", Vector3(-0.3, 0.0, 0.9), Vector3(0.9, 0.3, -0.6)],
	["front_wall_and_door", Vector3(0.0, 0.0, -0.2), Vector3(0.0, 0.9, 1.2)],
	["door_poster", Vector3(-0.03, 0.0, 0.55), Vector3(-0.03, 1.4, 1.2)],
	["bath_powder", Vector3(-0.2, 0.0, 0.1), Vector3(-0.8, 1.0, -0.08)],
	["bath_powder_closeup", Vector3(-0.45, 0.0, -0.05), Vector3(-0.8, 1.0, -0.08)],
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


func _aim(player: Node3D, point: Vector3) -> void:
	var eye: Vector3 = player.global_position + Vector3(0.0, player.EYE_HEIGHT, 0.0)
	var d := point - eye
	player.rotation.y = atan2(-d.x, -d.z)
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-85.0), deg_to_rad(85.0))
	player._pitch = pitch
	player.camera.rotation.x = pitch
