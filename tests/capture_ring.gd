extends SceneTree
## ベランダ（と廊下）から、全方向を斜め下に見回した確認画像。地面・建物の下に透けて空が見える所がないか。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 POS=ベランダ|廊下 Godot --path . --script res://tests/capture_ring.gd
func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(960, 540)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	main.hud._message_panel.visible = false
	main.hud.visible = false
	main.set_process(false)
	var p = main.player
	p.set_physics_process(false)
	main.room.sky_clock.set_time(0.0)
	var pos := Vector3(2.5, 0, -1.9) if OS.get_environment("POS") != "corridor" else Vector3(-2.1, 0, 2.0)
	p.global_position = pos
	var k := 0
	for pitch in [-12.0, -32.0, -58.0]:
		for yaw in range(0, 360, 30):
			p.rotation.y = deg_to_rad(yaw)
			p.camera.rotation.x = deg_to_rad(pitch)
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(OS.get_environment("SHOT_PREFIX") + "%02d_%d_%03d.png" % [k, int(-pitch), yaw]))
			k += 1
	quit()
