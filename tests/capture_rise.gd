extends SceneTree
## 浴室が上がったあとの確認画像：中から見たドアの跡、ホール側から見た柱と小さな扉。画角 80°。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_rise.gd
const H := 2.2   # room.gd の RISE_H
const VIEWS := [
	["rise_door_in", Vector3(0.0, H, 0.2), Vector3(0.0, H + 1.0, 2.0)],
	["rise_door_down", Vector3(0.0, H, 0.7), Vector3(0.0, 0.0, 2.0)],
	["rise_hall_up", Vector3(0.3, 0.0, 2.2), Vector3(0.3, 2.4, 1.2)],
	["rise_hall_hatch", Vector3(0.6, 0.0, 2.3), Vector3(0.45, 0.5, 1.3)],
	["rise_inside", Vector3(0.4, H, 0.7), Vector3(-0.5, H + 1.7, -0.7)],
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
	main.room.mirror_cabinet.pull_lever_visual(true)
	main.room.rise_unit(p, true)
	for i in 5:
		await process_frame
	for v in VIEWS:
		p.global_position = v[1]
		var d: Vector3 = v[2] - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(v[0] + ".png"))
	quit()
