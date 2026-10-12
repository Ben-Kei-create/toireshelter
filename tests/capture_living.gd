extends SceneTree
## 空模様・こたつ・エアコン・扇風機・小さな勉強机・遮光カーテン・トイレの電球の確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 SHOT_PREFIX=接頭辞 Godot --path . --script res://tests/capture_living.gd
var main
var p


func _initialize() -> void:
	_run()


func _look(pos: Vector3, at: Vector3) -> void:
	p.global_position = pos
	var d: Vector3 = at - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _shot(name: String, frames := 6) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(OS.get_environment("SHOT_PREFIX") + name + ".png"))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	main = current_scene
	main.hud._message_panel.visible = false
	p = main.player
	p.set_physics_process(false)
	var apt = main.room.apartment
	var clock = main.room.sky_clock
	# 部屋の全景（カーテンは閉まっている）
	_look(Vector3(1.4, 0, 1.8), Vector3(2.8, 0.6, 0.2))
	await _shot("room_curtain_closed")
	apt.toggle_curtain()
	await create_timer(1.2).timeout
	# 空：5階の廊下から西を見る（街並みの上の空）
	_look(Vector3(-2.1, 0, 1.5), Vector3(-20.0, 6.0, 3.0))
	main.set_process(false)
	for t in [0.0, 200.0, 360.0, 500.0, 700.0]:
		clock.set_time(t)
		await _shot("sky_%03d" % int(t), 4)
	_look(Vector3(-2.1, 0, 3.0), Vector3(-20.0, 14.0, -12.0))
	clock.set_time(700.0)
	await _shot("sky_high_dusk", 4)
	_look(Vector3(1.4, 0, 1.8), Vector3(2.8, 0.6, 0.2))
	clock.set_time(0.0)
	await _shot("room_day")
	clock.set_time(700.0)
	await _shot("room_dusk")
	apt.aircon.interact("aircon")
	apt.fan.interact("fan")
	await create_timer(2.5).timeout
	_look(Vector3(2.6, 0, 1.75), Vector3(2.6, 2.2, 0.78))
	await _shot("aircon_on")
	_look(Vector3(2.5, 0, -0.2), Vector3(3.0, 0.8, -0.85))
	await _shot("fan_on")
	_look(Vector3(1.8, 0, 1.78), Vector3(1.2, 0.5, 1.3))
	await _shot("study_desk")
	# こたつに座る・入る
	var K = preload("res://scripts/kotatsu.gd")
	var seat = K.SEATS[0]
	p.global_position = seat.feet
	p.rotation.y = seat.yaw
	p.camera.position.y = K.EYE_SEATED
	p.camera.rotation.x = -0.45
	p.pose = p.Pose.KOTATSU_SEAT
	await _shot("kotatsu_seated")
	var ins = seat.inside
	p.global_position = ins
	p.camera.position.y = K.EYE_INSIDE
	p.camera.rotation.x = -0.15
	p.pose = p.Pose.KOTATSU_IN
	await _shot("kotatsu_inside")
	p.pose = p.Pose.WALK
	p.camera.position.y = 1.5
	# トイレの電球：消す・つける・紫
	var room = main.room
	_look(Vector3(0.0, 0, 0.8), Vector3(0.15, 1.8, 0.35))
	await _shot("bath_light_on")
	room.set_bath_light(false)
	await _shot("bath_light_off")
	for i in 4:
		room.set_bath_light(true)
		await create_timer(0.8).timeout
		if i < 3:
			room.set_bath_light(false)
	await _shot("bath_light_purple")
	_look(Vector3(1.9, 0, 1.2), Vector3(1.0, 1.25, 1.3))
	await _shot("light_switch")
	quit()
