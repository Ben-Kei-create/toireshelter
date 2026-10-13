extends SceneTree
## 床のじゅうたん・床下の貯蔵庫・小物（トランプなど）・テレビゲームの自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/props_test.gd
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s   %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _ids(root: Node) -> Array:
	var out := []
	for n in root.find_children("*", "Area3D", true, false):
		if n.has_meta("interact_id"):
			out.append(String(n.get_meta("interact_id")))
	return out


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var apt = main.room.apartment
	var player = main.player
	var cellar = apt.cellar
	# --- じゅうたん
	var rug: Node3D = apt.small_props.get_node("Rug")
	check(rug != null and rug.get_node("Top").mesh is QuadMesh, "じゅうたんが敷いてある")
	check(rug.get_node("Top").material_override.albedo_texture != null, "じゅうたんに模様の絵がある")
	check(main.MESSAGES.has("rug") and "rug" in _ids(apt.small_props), "じゅうたんを調べられる")
	# --- 床下の貯蔵庫
	var floors: Array = apt.get_children().filter(func(c): return String(c.name).begins_with("RoomFloor"))
	check(floors.size() == 4, "床板は穴を避けて4枚に分かれている")
	check(cellar != null and cellar.get_node("Lid") != null and not cellar.is_open, "貯蔵庫の蓋は最初閉まっている")
	check(main.PROMPTS[cellar.get_prompt("cellar")] == "左クリック：床下の蓋を開ける", "閉まっているときは「蓋を開ける」")
	var hole_c: Vector3 = cellar.position
	check(player.is_space_free(hole_c, 1.6) == true, "蓋が閉まっていれば穴の上に立てる（体が床の下に落ちない）")
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(hole_c + Vector3(0, 0.5, 0), hole_c + Vector3(0, -0.4, 0), 1)
	check(not space.intersect_ray(down).is_empty(), "閉まっている蓋は床と同じく足を受ける")
	var key: String = cellar.interact("cellar")
	check(cellar.is_open and key == "cellar_opened" and main.MESSAGES.has(key), "蓋を開けられる")
	cellar.lid.rotation.x = deg_to_rad(cellar.OPEN_ANGLE)
	await process_frame
	await process_frame
	check(space.intersect_ray(down).is_empty(), "開けると穴の下まで床がない")
	var guard := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.6
	guard.shape = cap
	guard.transform = Transform3D(Basis.IDENTITY, hole_c + Vector3(0, 0.82, 0))
	guard.collision_mask = 1 | 16
	check(not space.intersect_shape(guard, 1).is_empty(), "開けた穴の上は体が入れない（落ちない）")
	check(main.PROMPTS[cellar.get_prompt("cellar")] == "左クリック：床下の蓋を閉める" and main.PROMPTS.has(cellar.get_prompt("cellar_goods")), "開けると「閉める」と、中を調べる案内")
	check(cellar.interact("cellar_goods") == "cellar_goods" and main.MESSAGES.has("cellar_goods"), "中の食べ物を調べられる")
	check(cellar.get_node("GoodsArea").collision_layer == 2, "穴の中を調べる判定は、開けているときだけ有効")
	cellar.interact("cellar")
	check(not cellar.is_open and cellar.get_node("GoodsArea").collision_layer == 0 and main.MESSAGES.has("cellar_closed"), "閉めると中の判定は消える")
	# 照準でも蓋を狙える
	player.global_position = hole_c + Vector3(0, 0, 0.9)
	player.rotation = Vector3(0, 0, 0)
	player.camera.rotation.x = deg_to_rad(-50.0)
	await physics_frame
	await physics_frame
	var tgt = player.get_focused(true)
	check(tgt != null and String(tgt.get_meta("interact_id")) == "cellar", "蓋を照準で狙える（手前から見下ろす）")
	# --- 小物
	var ids := _ids(apt.small_props)
	for id in ["cards", "card_box", "dice", "cup", "tv_remote", "tissue", "magazines", "teddy", "rug", "clothes", "dumbbell", "bottle", "bag"]:
		check(id in ids, "小物 %s の調べる判定" % id)
		check(id == "cards" or id == "dice" or id == "tv_remote" or main.MESSAGES.has(id), "小物 %s の文章" % id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 30:
		seen[apt.small_props.script.draw_card(rng)] = true
	check(seen.size() > 10, "トランプは毎回違う札が出る（%d 種）" % seen.size())
	# 小物が大きな家具にめり込まない（足元の点が壁・家具の箱の中でない）
	var bad := []
	for pos_name in ["TissueBox", "Magazines", "SpilledCards"]:
		var n: Node3D = apt.small_props.get_node(pos_name)
		var q := PhysicsPointQueryParameters3D.new()
		q.position = n.global_position + Vector3(0, 0.05, 0)
		q.collision_mask = 1
		if not space.intersect_point(q, 1).is_empty():
			bad.append(pos_name)
	check(bad.is_empty(), "床の小物は家具の中に埋まっていない %s" % [bad])
	check(apt.small_props.get_node("Teddy").position.y > 0.2, "くまは寝床の上に座っている（本棚の表紙を隠さない）")
	var top: Node3D = apt.small_props.get_node("TableItems")
	check(absf(top.global_position.y - 0.40) < 0.01, "こたつの上の小物は天板の高さ")
	# --- テレビゲーム
	var game = apt.tv_game
	check(game != null and not game.playing and apt.tv_on, "テレビはついていて、画面はデモ")
	var vp: SubViewport = apt.get_node("TvViewport")
	check(vp.get_texture() != null and apt.get_node("TvCorner/Tv/Screen").material_override.albedo_texture == vp.get_texture(), "画面はゲームの映像")
	game.step(0.5)
	game.stop()
	for i in 600:
		game.step(1.0 / 60.0)
	check(game.hits > 0 or game.score_left + game.score_right > 0, "デモは勝手に進む（打ち返し %d 回）" % game.hits)
	apt.set_tv_on(false)
	check(not apt.tv_on and apt.get_node("TvCorner/Tv/Screen").material_override.albedo_color.v < 0.1, "電源を切ると画面が黒い")
	apt.set_tv_on(true)
	player.global_position = Vector3(1.5, 0.0, 1.5)
	player.rotation = Vector3.ZERO
	main.gaming = false
	main._on_interact_requested(apt.get_node("TvCorner/Tv/TvArea"))
	check(main.gaming and game.playing and not player.controls_enabled, "テレビを調べるとゲームが始まる（視点は固定）")
	var f: Vector3 = -player.camera.global_transform.basis.z
	var to_tv: Vector3 = (apt.tv_screen_position() - player.camera.global_position).normalized()
	check(f.dot(to_tv) > 0.98, "ゲームを始めると画面のほうを向く")
	game.left_y = 90.0
	game.input = Vector2(0, -1)
	for i in 30:
		game.step(1.0 / 60.0)
	check(game.left_y < 90.0 - 30.0, "上キーでラケットが上へ動く")
	game.input = Vector2(0, 1)
	for i in 60:
		game.step(1.0 / 60.0)
	check(game.left_y > 90.0, "下キーで下へ動く")
	game.input = Vector2.ZERO
	game.score_left = 4
	game.ball = Vector2(game.W + 10.0, 80.0)
	game.vel = Vector2(100.0, 0.0)
	game.step(0.01)
	check(game.message == "YOU WIN", "先に5点とると勝ち")
	game.step(3.0)
	check(game.message == "" and game.score_left == 0, "勝敗のあと自動で最初から")
	main._stop_game()
	check(not main.gaming and player.controls_enabled and not game.playing, "やめると操作が戻る")
	main._on_interact_requested(apt.get_node("TvCorner/Console/ConsoleArea"))
	check(main.gaming, "ゲーム機を調べても始まる")
	main._stop_game()
	main._on_interact_requested(apt.small_props.get_node("TableItems/TvRemote/Area_tv_remote"))
	check(not apt.tv_on, "リモコンでテレビの電源が切れる")
	main._on_interact_requested(apt.small_props.get_node("TableItems/TvRemote/Area_tv_remote"))
	check(apt.tv_on, "もう一度で入る")
	# --- 設定（Esc）：操作説明と身長
	main._pause()
	var menu: Control = main.hud._pause_menu
	check(menu.visible and main.hud._hint_label.text.begins_with("Esc：設定") and not main.hud._hint_label.text.contains("WASD"), "Esc で設定が開く（上端の案内は Esc：設定）")
	check((menu.get_node("Center/Box/Controls") as Label).text.contains("E：") or (menu.get_node("Center/Box/Controls") as Label).text.contains("座る・入る・立つ：E"), "設定に操作説明がある")
	main.hud._height_slider.value = 165.0
	check(is_equal_approx(player.eye_height, 1.65) and is_equal_approx(player._eye_target, 1.65), "身長スライダーで目の高さが変わる（165cm）")
	main.hud._height_slider.value = 100.0
	check(is_equal_approx(player.eye_height, 1.3), "低すぎる値は下限 130cm にそろう")
	main.hud._height_slider.value = 150.0
	var cfg := ConfigFile.new()
	check(cfg.load("user://settings.cfg") == OK and is_equal_approx(float(cfg.get_value("player", "eye_height")), 1.5), "身長は設定ファイルに保存される")
	# 音：バス・音量・オンオフ・保存
	var sfx_i := AudioServer.get_bus_index("SFX")
	var amb_i := AudioServer.get_bus_index("Ambient")
	check(sfx_i > 0 and amb_i > 0 and main.room.get_node("AmbientSound/VentHum").bus == "Ambient" and main.get_node("Sfx").get_child(0).bus == "SFX", "効果音と環境音は別のバス")
	main.hud.audio_controls["master"].value = 50.0
	check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.01, "全体音量スライダーでマスターの音量が変わる")
	main.hud.audio_controls["sfx"].value = 30.0
	check(absf(AudioServer.get_bus_volume_db(sfx_i) - linear_to_db(0.3)) < 0.01, "効果音の音量が変わる")
	main.hud.audio_controls["sfx_on"].button_pressed = false
	check(AudioServer.is_bus_mute(sfx_i) and not AudioServer.is_bus_mute(amb_i), "効果音をオフにすると効果音だけ消える")
	main.hud.audio_controls["ambient_on"].button_pressed = false
	check(AudioServer.is_bus_mute(amb_i), "環境音もオフにできる")
	cfg = ConfigFile.new()
	check(cfg.load("user://settings.cfg") == OK and absf(float(cfg.get_value("audio", "master")) - 0.5) < 0.001 and cfg.get_value("audio", "sfx_on") == false, "音の設定も保存される")
	main.hud.audio_controls["master"].value = 100.0
	main.hud.audio_controls["sfx"].value = 100.0
	main.hud.audio_controls["sfx_on"].button_pressed = true
	main.hud.audio_controls["ambient_on"].button_pressed = true
	check(not AudioServer.is_bus_mute(sfx_i) and not AudioServer.is_bus_mute(amb_i) and AudioServer.get_bus_volume_db(0) > -0.01, "戻すと元の音量")
	main._resume()
	check(not main.paused, "再開できる")
	print("props_test: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
