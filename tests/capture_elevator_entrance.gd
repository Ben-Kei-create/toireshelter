extends SceneTree
## エレベーターの箱の中と、1 階の入口の確認画像。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_elevator_entrance.gd
## [名前, 立つ位置（箱・入口の原点からの相対）, 見る点（同）, 箱(true)/入口(false)/廊下(null：世界の座標のまま)]
const VIEWS := [
	["elev_door", Vector3(0.0, 0.0, -0.45), Vector3(-0.2, 1.1, 0.67), true],
	["elev_panel", Vector3(0.1, 0.0, -0.15), Vector3(0.46, 1.35, 0.67), true],
	["elev_inside", Vector3(0.5, 0.0, -0.55), Vector3(-0.3, 1.2, 0.5), true],
	["ent_approach", Vector3(0.0, 0.0, 1.2), Vector3(0.0, 1.6, -4.0), false],
	["ent_arch", Vector3(0.0, 0.0, -1.2), Vector3(0.0, 1.5, -4.0), false],
	["ent_lobby", Vector3(0.0, 0.0, -4.8), Vector3(-0.6, 1.4, -7.5), false],
	["ent_up", Vector3(0.2, 0.0, -6.0), Vector3(-0.5, 3.4, -7.8), false],
	["ent_end", Vector3(0.0, 0.0, -6.2), Vector3(0.0, 1.3, -9.0), false],
	["corr_elevator", Vector3(-1.85, 0.0, 3.6), Vector3(-1.85, 1.2, 6.4), null],
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
		var origin: Vector3 = Vector3.ZERO if v[3] == null else (main.room.PREVIEW_CAR_POS if v[3] else main.room.PREVIEW_ENTRANCE_POS)
		p.global_position = origin + v[1]
		var target: Vector3 = origin + v[2]
		var d: Vector3 = target - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(v[0] + ".png"))
	quit()
