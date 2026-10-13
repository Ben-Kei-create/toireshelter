extends SceneTree
## 麻雀牌の画像・ジャケットの確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_images3.gd
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
	_look(Vector3(2.5, 0.0, 0.62), Vector3(1.4, 0.2, 0.9))
	await _shot("jackets")
	p.pose = p.Pose.KOTATSU_IN
	m.inventory.append("mahjong")
	m.select_item(0)
	m.use_selected()
	await _shot("mahjong_tiles")
	var gm = m.mahjong
	gm.hand = [0, 1, 2, 12, 13, 14, 20, 21, 22, 27, 27, 31, 31]
	gm.wall[gm.wall_pos] = 5
	gm.discard(13)
	m.mj_cursor = 4
	await _shot("mahjong_tiles2")
	quit()
