extends SceneTree
## エレベーターの箱の中・1 階の入口・路地・自動販売機の確認画像。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_elevator_entrance.gd
## [名前, 立つ位置, 見る点, 座標系]  座標系："car"＝箱の原点から／"ent"＝入口のローカル（180度回して置いてある）／"world"＝世界の座標
const VIEWS := [
	["elev_door", Vector3(0.0, 0.0, -0.45), Vector3(0.2, 1.1, 0.67), "car"],
	["elev_panel", Vector3(-0.1, 0.0, -0.15), Vector3(-0.46, 1.35, 0.67), "car"],
	["elev_inside", Vector3(-0.5, 0.0, -0.55), Vector3(0.3, 1.2, 0.5), "car"],
	["ent_approach", Vector3(0.0, 0.0, 1.2), Vector3(0.0, 1.6, -1.6), "ent"],
	["ent_arch", Vector3(0.0, 0.0, -0.4), Vector3(0.0, 1.5, -1.6), "ent"],
	["ent_lobby", Vector3(0.0, 0.0, -2.0), Vector3(-0.6, 1.4, -4.5), "ent"],
	["ent_up", Vector3(0.2, 0.0, -4.0), Vector3(-0.5, 3.4, -6.5), "ent"],
	["ent_end", Vector3(0.0, 0.0, -6.2), Vector3(0.0, 1.3, -9.3), "ent"],
	["corr_elevator", Vector3(-1.85, 0.0, 3.6), Vector3(-1.85, 1.2, 6.4), "world"],
	["alley_balcony_view", Vector3(2.6, 0.0, -1.9), Vector3(2.6, -9.0, -2.6), "world"],
	["alley_walk", Vector3(-0.9, -13.6, -2.7), Vector3(2.6, -12.2, -1.6), "world"],
	["alley_out", Vector3(-1.85, -13.6, 1.5), Vector3(-1.85, -12.2, -3.0), "world"],
	["alley_vending", Vector3(2.6, -13.6, -3.4), Vector3(2.6, -12.4, -1.7), "world"],
	["alley_entrance", Vector3(-1.85, -13.6, -4.1), Vector3(-1.85, -12.2, -1.3), "world"],
]


func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	main.hud._message_panel.visible = false
	main.set_process(false)
	var p = main.player
	p.set_physics_process(false)
	for v in VIEWS:
		var pos: Vector3 = v[1]
		var target: Vector3 = v[2]
		match v[3]:
			"car":
				pos += main.room.PREVIEW_CAR_POS
				target += main.room.PREVIEW_CAR_POS
			"ent":
				var o: Vector3 = main.room.ENTRANCE_POS
				pos = o + Vector3(-pos.x, pos.y, -pos.z)
				target = o + Vector3(-target.x, target.y, -target.z)
		p.global_position = pos
		var d: Vector3 = target - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(v[0] + ".png"))
	quit()
