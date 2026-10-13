extends SceneTree
## 押入れの麻雀牌・レコードプレーヤーと壁の盤・麻雀の画面・冷蔵庫の棚・地下室の確認画像（画角 80°）。
## 実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_mahjong.gd
var main
var p


func _initialize() -> void:
	_run()


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _look(pos: Vector3, at: Vector3) -> void:
	p.global_position = pos
	var d: Vector3 = at - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _shot(name: String, frames := 6) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name + ".png"))


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
	_look(Vector3(2.9, 0, 0.62), Vector3(1.4, 0.8, 0.5))
	await _shot("record_player")
	_look(Vector3(2.2, 0, 0.1), Vector3(1.4, 0.3, 0.3))
	await _shot("record_disc_leaning")
	apt.closet.interact("fusuma")
	await create_timer(1.0).timeout
	_look(Vector3(4.3, 0, 0.3), Vector3(3.95, 1.45, -0.8))
	await _shot("mahjong_box")
	main._on_interact_requested(apt.closet.mahjong_box.get_node("MahjongArea"))
	_look(Vector3(2.9, 0, 0.62), Vector3(1.4, 0.8, 0.5))
	main._on_interact_requested(apt.record_player.get_node("RecordDiscArea"))
	main.hud.show_item_zoom(main._item_models["mahjong"], "麻雀牌", "x")
	await _shot("zoom_mahjong")
	main.hud.show_item_zoom(main._item_models["record_disc"], "レコード盤", "x")
	await _shot("zoom_disc")
	main.hud.show_item_zoom(null, "", "")
	_look(Vector3(2.6, 0, 0.62), Vector3(1.5, 0.7, 0.62))
	main.select_item(main.inventory.find("record_disc"))
	main._on_interact_requested(apt.record_player.get_node("RecordPlayerArea"))
	await _shot("record_playing")
	# 麻雀
	p.pose = p.Pose.KOTATSU_IN
	main.select_item(main.inventory.find("mahjong"))
	main.use_selected()
	await _shot("mahjong_start")
	main._mahjong_input(_key(KEY_LEFT))
	main._mahjong_input(_key(KEY_LEFT))
	await _shot("mahjong_select")
	var gm = main.mahjong
	gm.hand = [0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 27]
	gm.wall[gm.wall_pos] = 27
	main.mj_cursor = 13
	gm.discard(13)
	await _shot("mahjong_result")
	main._stop_mahjong()
	p.pose = p.Pose.WALK
	# 冷蔵庫の棚と地下
	apt.cellar.set_open(true, false)
	apt.kitchen.interact("fridge_lower")
	await create_timer(0.9).timeout
	for id in apt.cellar.FOODS.keys():
		apt.cellar.interact(id)
		main._on_interact_requested(apt.kitchen.get_node("InsideArea"))
	_look(Vector3(4.85, 0, 1.2), Vector3(5.1, 1.0, 1.9))
	await _shot("fridge_shelf")
	_look(Vector3(4.3, 0, 0.62), Vector3(4.0, -1.0, 1.4))
	await _shot("stairs_top")
	_look(Vector3(4.3, 0, 0.55), Vector3(3.6, -1.2, 1.3))
	await _shot("stairs_hole")
	main._descend()
	await create_timer(0.4).timeout
	await _shot("stairs_fading")
	await create_timer(1.6).timeout
	await _shot("stairs_bottom")
	_look(Vector3(1.95, -2.1, 1.3), Vector3(1.35, -1.2, 1.3))
	await _shot("basement_letter")
	main._open_reader("手紙", main.BASEMENT_LETTER, null, Color(0.95, 0.9, 0.78))
	await _shot("letter_reader")
	main._close_reader()
	main._ascend()
	await create_timer(2.0).timeout
	await _shot("stairs_up_exit")
	quit()
