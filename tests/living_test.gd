extends SceneTree
## 空模様・トイレの電球とスイッチ・遮光カーテン・こたつ・エアコン・扇風機・勉強机の自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/living_test.gd
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s   %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var room = main.room
	var apt = room.apartment
	var player = main.player
	# --- 空模様（プレイ時間）
	var clk = room.sky_clock
	clk.set_time(0.0)
	check(is_equal_approx(clk.weights.x, 1.0) and clk.weights.y == 0.0, "開始直後は昼の空")
	clk.set_time(210.0)
	check(clk.weights.x > 0.05 and clk.weights.y > 0.05 and is_equal_approx(clk.weights.x + clk.weights.y + clk.weights.z, 1.0), "昼から夕焼けへ混ざっていく（合計 1）")
	clk.set_time(360.0)
	check(is_equal_approx(clk.weights.y, 1.0), "6分ごろは夕焼け")
	clk.set_time(700.0)
	check(is_equal_approx(clk.weights.z, 1.0) and clk.daylight < 0.4, "10分すぎは夕暮れ（窓の光は弱い）")
	check(room.get_node("WorldEnvironment").environment.background_mode == Environment.BG_SKY, "背景は空の絵")
	var t0: float = main.play_time
	await create_timer(0.5).timeout
	check(main.play_time > t0, "プレイ時間が進む")
	main.play_time = 0.0
	# --- トイレの電気（部屋のスイッチ）
	var sw = room.light_switch
	check(sw != null and sw.position.x < 1.1 and sw.position.z > 1.0 and sw.position.z < 1.5, "スイッチは自室の左の壁（浴室の外）にある")
	check(room.get_node("Toilet").get_children().filter(func(c): return c.has_meta("interact_id") and String(c.get_meta("interact_id")) == "bath_light_switch").is_empty(), "浴室の中にスイッチはない")
	check(room.bath_light_on and room.bath_light.light_energy > 0.4 and main.PROMPTS[sw.get_prompt("")] == "左クリック：トイレの電気を消す", "最初は点いていて、「電気を消す」")
	var keys := []
	keys.append(sw.interact(""))
	check(not room.bath_light_on and room.bath_light.light_energy == 0.0 and keys[0] == "bath_light_off", "消すと真っ暗（電球の光が 0）")
	check(main.PROMPTS[sw.get_prompt("")] == "左クリック：トイレの電気をつける", "消えているときは「電気をつける」")
	for k in 3:
		keys.append(sw.interact(""))   # つける
		keys.append(sw.interact(""))   # 消す
	check(not room.bath_purple and room.bath_light_cycles == 3, "消してつけ直す 3 回では、まだ紫にならない")
	keys.append(sw.interact(""))       # 4 回目のつけ直し
	check(room.bath_purple and keys[-1] == "bath_light_purple", "4 回目につけ直すと紫色になる")
	await create_timer(1.0).timeout
	check(room.bath_light.light_color.b > room.bath_light.light_color.g and room.bath_light.light_energy > 0.5, "紫色の光（青み・赤みが緑より強い）で点いている")
	sw.interact("")
	check(sw.interact("") == "bath_light_on_purple" and room.bath_purple, "そのあとはずっと紫のまま")
	for k in ["bath_light_off", "bath_light_on", "bath_light_purple", "bath_light_on_purple"]:
		check(main.MESSAGES.has(k), "%s の文章がある" % k)
	# --- 遮光カーテン
	check(apt.curtain_closed and apt.get_prompt("curtain") == "curtain_open", "遮光カーテンは最初閉まっていて、「カーテンを開ける」")
	var dark: float = apt.window_light.light_energy
	apt.toggle_curtain()
	await create_timer(1.1).timeout
	check(not apt.curtain_closed and apt.curtain.scale.x < 0.3 and apt.get_prompt("curtain") == "curtain_close", "開けるとカーテンが寄る")
	clk.set_time(0.0)
	await create_timer(0.3).timeout
	check(apt.window_light.light_energy > dark + 0.5, "開けると窓から昼の光が差す（%.2f → %.2f）" % [dark, apt.window_light.light_energy])
	apt.toggle_curtain()
	await create_timer(1.1).timeout
	check(apt.curtain_closed and apt.window_light.light_energy < 0.3, "閉めると光はほぼ消える")
	# --- エアコン・扇風機
	check(not apt.aircon.is_on and apt.aircon.interact("") == "aircon_on" and apt.aircon.is_on, "エアコンをつけられる")
	check(apt.aircon.interact("") == "aircon_off" and not apt.aircon.is_on, "エアコンを止められる")
	check(apt.fan.interact("") == "fan_on" and apt.fan.is_on, "扇風機をつけられる")
	var rot0: float = apt.fan.get_node("Head/Blades").rotation.z
	await create_timer(0.5).timeout
	check(absf(apt.fan.get_node("Head/Blades").rotation.z - rot0) > 0.5, "羽根がまわる")
	apt.fan.interact("")
	for k in ["aircon_on", "aircon_off", "fan_on", "fan_off", "kotatsu_look", "kotatsu_inside"]:
		check(main.MESSAGES.has(k), "%s の文章がある" % k)
	# --- こたつ：立って狙う → E で座る → こたつに入る → 出る → 立つ
	var K = preload("res://scripts/kotatsu.gd")
	var seat: Dictionary = K.SEATS[0]
	player.global_position = Vector3(2.6, 0.05, -0.65)
	player.rotation.y = PI   # +z を向く（こたつ）
	player._pitch = 0.0
	player.camera.rotation.x = -0.8
	for i in 4:
		await physics_frame
	var tgt = player.get_focused(true)
	check(tgt != null and String(tgt.get_meta("interact_id", "")) == "kotatsu", "こたつを狙える")
	check(main._action_for(tgt) == "kotatsu_sit", "「E：こたつに座る」")
	main.do_action()
	await create_timer(1.0).timeout
	check(player.pose == player.Pose.KOTATSU_SEAT and main.kotatsu_seat == 0, "こたつに座れる（北の座布団）")
	check(player.global_position.distance_to(seat.feet) < 0.05 and absf(player.camera.position.y - K.EYE_SEATED) < 0.05, "座布団の上、目の高さ 0.85m")
	player.rotation.y = PI
	player.camera.rotation.x = -0.9
	for i in 4:
		await physics_frame
	tgt = player.get_focused(true)
	check(tgt != null and String(tgt.get_meta("interact_id", "")) == "kotatsu" and main._prompt_for(tgt) == main.PROMPTS["kotatsu_enter"], "座ってこたつを狙うと「こたつに入る」")
	main._on_interact_requested(tgt)
	await create_timer(1.0).timeout
	check(player.pose == player.Pose.KOTATSU_IN and absf(player.camera.position.y - K.EYE_INSIDE) < 0.05, "こたつの中に入れる（低い目の高さ）")
	check(main._action_for(null) == "kotatsu_out", "中では「E：こたつから出る」")
	main.do_action()
	await create_timer(1.0).timeout
	check(player.pose == player.Pose.KOTATSU_SEAT, "出ると座った姿勢に戻る")
	check(main._action_for(null) == "kotatsu_stand", "座っていると「E：立つ」")
	main.do_action()
	await create_timer(1.0).timeout
	check(player.pose == player.Pose.WALK and player.is_walking(), "立てる（歩ける姿勢に戻る）")
	# 西の座布団（カセットの台側）が近い位置
	check(K.nearest_seat(Vector3(1.7, 0.05, 1.0)) == 1 and K.nearest_seat(Vector3(2.6, 0.05, -0.5)) == 0, "立つ位置に近い座布団が選ばれる（北・西）")
	for seat_i in K.SEATS.size():
		var exits_ok := false
		for e in K.SEATS[seat_i].exits:
			if player.is_space_free(e, 1.6):
				exits_ok = true
		check(exits_ok, "座布団 %d から立てる位置が空いている" % seat_i)
	# --- 勉強机
	var desk: Node3D = apt.get_node("StudyDesk")
	check(desk != null and desk.get_node("Top").position.y < 0.7, "小さな勉強机がある（高さ 0.6m）")
	# 通路：出入口からこたつ・窓・クレーンゲーム・本棚の前まで体が通れる
	var pts := [Vector3(1.0, 0.0, 1.78), Vector3(1.8, 0.0, 1.78), Vector3(1.8, 0.0, 1.0), Vector3(1.8, 0.0, 0.3), Vector3(2.0, 0.0, 0.05), Vector3(2.3, 0.0, 0.03), Vector3(2.5, 0.0, -0.6), Vector3(2.5, 0.0, -0.9)]
	var blocked := []
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var n := int(a.distance_to(b) / 0.05)
		for i in n + 1:
			var p := a.lerp(b, float(i) / maxi(n, 1))
			if not player.is_space_free(p, 1.4):
				blocked.append(p)
	check(blocked.is_empty(), "出入口 → こたつの脇 → 窓の前まで体が通れる（ぶつかる点 %d）%s" % [blocked.size(), str(blocked.slice(0, 3))])
	print("LIVING TEST: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)
