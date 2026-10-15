extends SceneTree
## 冷蔵庫の扉の当たり判定・床下の中身・黒電話の番号・ゲームソフト5本・カレンダー・玄関の靴・視点のゆれの自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/detail_test.gd
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
	var apt = main.room.apartment
	var player = main.player
	# --- 冷蔵庫の扉：開けると体を止める（照準は通す）
	var k = apt.kitchen
	check(player.is_space_free(Vector3(4.85, 0.0, 1.45), 1.6), "扉が閉まっているとき、冷蔵庫の前は歩ける")
	k.interact("fridge_lower")
	await create_timer(0.8).timeout
	check(not player.is_space_free(Vector3(4.85, 0.0, 1.45), 1.6), "冷蔵室の扉を開けると、扉が立ちふさがる（体が通れない）")
	check(k.get_node("Door_lower/DoorBlock").collision_layer == 16, "扉の当たり判定は体だけを止める層（照準は通す）")
	k.interact("fridge_lower")
	await create_timer(0.8).timeout
	check(player.is_space_free(Vector3(4.85, 0.0, 1.45), 1.6), "閉めるとまた通れる")
	# --- 床下の中身（食べ物は食べず、運んで冷蔵庫へ入れる）
	var c = apt.cellar
	c.set_open(true, false)
	check(c.get_node("Item_cellar_can_0").collision_layer == 2 and c.get_node("Item_cellar_potato").collision_layer == 2, "床下を開けると中身ひとつずつが狙える")
	check(c.interact("cellar_can_0") == "cellar_carry_taken" and c.carrying_id == "cellar_can_0" and not c.get_node("CanB0").visible, "缶詰を持つと棚から消える")
	check(c.interact("cellar_can_1") == "cellar_carry_full", "一度にひとつしか運べない")
	check(c.interact("cellar_sack") == "cellar_sack" and c.interact("cellar_goods") == "cellar_goods", "米袋は運べず、調べるだけ")
	for key in ["cellar_carry_taken", "cellar_carry_full", "cellar_sack", "cellar_goods", "fridge_put", "stairs_revealed"]:
		check(main.MESSAGES.has(key), "%s の文章" % key)
	check(main.PROMPTS[c.get_prompt("cellar_can_1")] == "左クリック：持って運ぶ" and main.PROMPTS[c.get_prompt("cellar_sack")] == "左クリック：調べる", "案内「持って運ぶ」「調べる」")
	c.set_open(false, false)
	check(c.get_node("Item_cellar_potato").collision_layer == 0, "閉めると中身の判定は消える")
	c.set_open(true, false)
	check(c.get_node("Item_cellar_can_0").collision_layer == 0, "もう一度開けても、運んだ物の判定は戻らない")
	# --- 黒電話
	var calls := []
	for num in ["117", "177", "110", "119", "0000"]:
		main._phone_number(num)
		calls.append(main.hud._message_label.text)
	check(calls[0].contains("1・1・7") and calls[0].contains("秒を、お知らせします"), "117：いまの時刻を読み上げる")
	check(calls[1].contains("天気") and calls[2].contains("1・1・0") and calls[3].contains("1・1・9") and calls[4].contains("使われておりません"), "177・110・119・でたらめ の番号ごとに変わる")
	main._phone_dial()
	check(main.coding and main.reading, "黒電話を使うと、番号の入力画面が開く")
	main._close_code(false)
	check(not main.INTERACT_SFX.has("phone_black"), "黒電話の音は番号ごとに鳴らす")
	# --- ゲームソフト5本
	var game = apt.tv_game
	check(game.MODES.size() == 5 and game.MODES[4] == "nodisc", "ソフトは5本（4本遊べて、1本は読み込めない）")
	var cases: Array = apt.get_node("TvCorner").find_children("CaseArea", "Area3D", true, false)
	check(cases.size() == 5, "ソフトのケースに5つの判定がある")
	main._on_interact_requested(cases[0])
	check(game.mode == "tetris" and main.hud._message_label.text.contains("FALLING BLOCKS"), "ケースを調べるとそのソフトに入れ替わる")
	game.start()
	var x0: int = game.tt_x
	game.input = Vector2(1, 0)
	for i in 4:
		game.step(0.12)
	check(game.tt_x > x0, "落ちものパズル：D（右）でブロックが動く")
	game.input = Vector2.ZERO
	var rot0: int = game.tt_rot
	game.input = Vector2(0, -1)
	game.step(0.02)
	check(game.tt_rot != rot0 or game.tt_kind == "O", "落ちものパズル：W で回る")
	game.input = Vector2.ZERO
	game.reset_game()
	for ci in 9:
		game.tt_grid[17][ci] = 1
	game.tt_kind = "I"
	game.tt_rot = 1   # 縦
	game.tt_x = 7     # 縦の I は x+2 の列（右端の 9 列目）に入る
	game.tt_y = 10
	game._tt_fall = 0.0
	for i in 40:
		game.step(0.1)
		if game.tt_lines > 0:
			break
	check(game.tt_lines >= 1 and game.score >= 100, "落ちものパズル：1 行そろうと消えて 100 点（lines %d）" % game.tt_lines)
	game.stop()
	main._on_interact_requested(cases[1])
	check(game.mode == "racer" and not game.playing, "レースゲームに入れ替え（デモに戻る）")
	game.start()
	var rx0: float = game.rc_x
	game.input = Vector2(-1, 0)
	for i in 20:
		game.step(1.0 / 60.0)
	check(game.rc_x < rx0 - 20.0, "レース：A（左）でハンドルを切る")
	game.input = Vector2.ZERO
	game.rc_cars = [{"x": game.rc_x, "y": 140.0, "v": 40.0}]
	game._rc_spawn = 10.0
	game.step(0.05)
	check(game.message == "CRASH", "レース：ぶつかるとクラッシュ")
	game.stop()
	main._on_interact_requested(cases[2])
	check(game.mode == "climb" and not game.playing, "樽よけ・はしご登りに入れ替え")
	game.start()
	game.cl_x = float(game.CL_LADDER[0])
	game.input = Vector2(0, -1)
	for i in 80:
		game.step(1.0 / 60.0)
	check(game.cl_level == 1 or game.cl_climbing, "はしご登り：はしごの所で W を押すと登る")
	game.cl_level = 2
	game.cl_climbing = false
	game.cl_x = float(game.CL_LADDER[2])
	game.cl_barrels = []
	game._cl_spawn = 99.0
	game.input = Vector2(0, -1)
	for i in 120:
		game.step(1.0 / 60.0)
		if game.message == "CLEAR":
			break
	check(game.message == "CLEAR", "はしご登り：いちばん上へ着くとクリア")
	game.stop()
	game.start()
	game.cl_barrels = [{"x": game.cl_x, "level": 0, "dir": 1.0}]
	game._cl_spawn = 99.0
	game.step(0.02)
	check(game.message == "GAME OVER", "はしご登り：樽に当たるとゲームオーバー")
	game.stop()
	main._on_interact_requested(cases[3])
	game.start()
	game.dg_x = 160.0
	game.input = Vector2(-1, 0)
	for i in 20:
		game.step(1.0 / 60.0)
	check(game.dg_x < 160.0 - 30.0, "よけゲー：A（左）で動く")
	game.input = Vector2.ZERO
	game.dg_blocks = [{"x": game.dg_x, "y": 150.0, "w": 24.0, "v": 90.0}]
	game._dg_spawn = 10.0
	game.step(0.1)
	check(game.message == "GAME OVER", "よけゲー：当たるとゲームオーバー")
	game.stop()
	for mode_i in 4:
		game.select(mode_i)
		for i in 1800:
			game.step(1.0 / 60.0)
		check(game.score + game.hits >= 0 and not game.playing, "%s のデモは 30 秒走っても止まらない（score %d）" % [game.TITLES[game.mode], game.score])
	main._on_interact_requested(cases[4])
	check(game.mode == "nodisc" and not game.playable(), "5本目は読み込めないディスク")
	main._start_game()
	check(not main.gaming and main.hud._message_label.text.contains("NO DISC"), "読み込めないディスクでは遊べない")
	game.select(0)
	# --- カレンダー
	var cal = apt.calendar
	var now: Dictionary = Time.get_datetime_dict_from_system()
	check(cal.today == now.day and cal.month == now.month and cal.year == now.year, "カレンダーは今日の月・日付")
	var days: int = cal._days_in_month(cal.year, cal.month)
	check(cal.day_labels.size() == days and (cal.day_labels[days - 1] as Label3D).text == str(days), "日付は月末まで（%d 日）" % days)
	check(cal.ring != null and cal.date_text().contains("月") and cal.date_text().contains("曜") == false and cal.date_text().contains("（"), "今日に赤い丸がつき、日付と曜日の文章が出る")
	check(cal._weekday_of(2000, 1, 1) == 6 and cal._days_in_month(2024, 2) == 29 and cal._days_in_month(2025, 2) == 28, "曜日と月の日数の計算（2000/1/1 は土曜、うるう年）")
	main._on_interact_requested(cal.get_node("CalendarArea"))
	check(main.hud._message_label.text.contains("今日は"), "カレンダーを調べると日付が出る")
	# --- 玄関の靴
	var shoes = apt.get_node("Shoes")
	check(shoes != null and shoes.get_node("ShoesArea").get_meta("interact_id") == "shoes" and main.MESSAGES.has("shoes"), "玄関に靴がある（調べられる）")
	check(player.is_space_free(Vector3(-0.5, 0.0, 1.9), 1.6), "靴は体を止めない")
	# --- 視点のゆれ
	check(player.head_bob and player.BOB_WALK <= 0.015, "視点のゆれがある（歩くときは 1.5cm 以下）")
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 0.05, 0.0)
	player.head_bob = true
	player.camera.position.y = player.eye_height
	var lo := 10.0
	var hi := -10.0
	for i in 240:
		await process_frame
		lo = minf(lo, player.camera.position.y)
		hi = maxf(hi, player.camera.position.y)
	check(hi - lo > 0.002 and hi - lo < 0.01, "止まっていても、呼吸でごくわずかにゆれる（%.1f mm）" % ((hi - lo) * 1000.0))
	player.head_bob = false
	for i in 30:
		await process_frame
	var y1: float = player.camera.position.y
	await process_frame
	check(absf(player.camera.position.y - y1) < 0.0005 and absf(player.camera.position.y - player.eye_height) < 0.001, "オフにすると、ゆれない")
	main.hud._bob_check.button_pressed = false
	main.hud._bob_check.button_pressed = true
	check(player.head_bob and main.hud._bob_check.text.contains("オン"), "設定のスイッチでオンに戻せる")
	var cfg := ConfigFile.new()
	check(cfg.load("user://settings.cfg") == OK and cfg.get_value("player", "head_bob") == true, "設定ファイルに保存される")
	print("detail_test: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
