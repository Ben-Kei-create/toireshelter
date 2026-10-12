extends SceneTree
## TASK-08 の確認画像：着座・浴槽内・しゃがみ・埋め込み収納・トイレを流す途中（ウィンドウ表示が必要）。
## 実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_poses.gd

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
	main.hud._message_panel.visible = false
	main.hud._message_time_left = 0.0

	# しゃがみ：洗面台の下とドライバーを近くから
	p.global_position = Vector3(0.3, 0.0, 0.45)
	p.toggle_crouch()
	await create_timer(1.0).timeout
	await _shot(p, "pose_crouch_under_sink", Vector3(0.62, 0.05, 0.05))
	p.toggle_crouch()
	await create_timer(1.0).timeout

	# 埋め込み収納（閉じた状態・開いた状態）
	p.global_position = Vector3(0.1, 0.0, 0.35)
	await _shot(p, "cabinet_embedded_closed", Vector3(0.9, 1.5, 0.1))
	room.mirror_cabinet.toggle()
	await create_timer(0.7).timeout
	p.global_position = Vector3(0.2, 0.0, 0.3)
	await _shot(p, "cabinet_embedded_open", Vector3(0.92, 1.5, 0.1))
	room.mirror_cabinet.toggle()
	await create_timer(0.7).timeout

	# 着座：座ってから前（洗面台側）と、振り返ってレバー
	room.toilet.toggle_lid()
	await create_timer(0.6).timeout
	p.global_position = Vector3(0.0, 0.0, 0.35)
	_aim(p, room.toilet.seat_pivot.to_global(Vector3(0.335, 0.012, 0.0)))
	main.do_action()
	await create_timer(0.9).timeout
	await _shot(p, "pose_seated_front", Vector3(0.9, 0.9, 0.2))
	await _shot(p, "pose_seated_look_back", Vector3(-0.68, 0.86, 0.2))
	main.do_action()
	await create_timer(0.9).timeout

	# 浴槽内：栓と排水口、手前の内壁
	p.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(p, room.bathtub.to_global(Vector3(0.3, 0.3, 0.375)))
	main.do_action()
	await create_timer(0.9).timeout
	await _shot(p, "pose_in_tub_drain", room.bathtub.to_global(Vector3(0.62, 0.1, 0.0)))
	await _shot(p, "pose_in_tub_front_wall", room.bathtub.to_global(Vector3(0.0, 0.25, 0.375)))
	main.do_action()
	await create_timer(0.9).timeout

	# トイレを流す途中（タンクの蓋を開けて、水位が下がったところ）
	room.toilet.toggle_tank()
	await create_timer(1.6).timeout
	p.global_position = Vector3(-0.35, 0.0, 0.45)
	room.toilet.flush()
	await create_timer(1.0).timeout
	await _shot(p, "flush_tank_draining", Vector3(-0.8, 0.55, -0.02))
	await create_timer(1.3).timeout
	await _shot(p, "flush_tank_refilling", Vector3(-0.8, 0.55, -0.02))
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
