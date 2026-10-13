extends SceneTree
## 一人麻雀・床下の食べ物を冷蔵庫へ運ぶ→地下の階段と手紙・レコードプレーヤー（古いジャズ）の自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/mahjong_basement_test.gd
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s   %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func get_root_paused(main: Node) -> bool:
	return main.get_tree().paused


func paused_now(main: Node) -> bool:
	return main.get_tree().paused


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var apt = main.room.apartment
	var player = main.player
	var MJ = main.MahjongGame
	# --- 麻雀の判定
	var c := func(tiles: Array) -> Array:
		var out := []
		out.resize(34)
		out.fill(0)
		for t in tiles:
			out[t] += 1
		return out
	check(MJ.is_win(c.call([0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 27, 27])), "四面子一雀頭の和了")
	check(MJ.is_win(c.call([0, 0, 2, 2, 4, 4, 9, 9, 11, 11, 20, 20, 30, 30])), "七対子の和了")
	check(MJ.is_win(c.call([0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33, 33])), "国士無双の和了")
	check(not MJ.is_win(c.call([0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 15, 27, 27])), "揃っていない手は和了でない")
	var g = MJ.new(7)
	g.start()
	check(g.state in ["playing", "won"] and g.hand.size() == 13, "配牌は13枚")
	g.hand = [0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 27]
	check(g.waits() == [27], "単騎待ちを数えられる")
	g.hand = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24]
	check(g.waits().is_empty(), "待ちなしの手")
	var n := 0
	var g2 = MJ.new(11)
	g2.start()
	while g2.state == "playing" and n < 200:
		g2.discard(13)
		n += 1
	check(g2.state in ["won", "exhausted"] and n <= MJ.MAX_DRAWS, "最後まで打つと和了か流局になる（%d打）" % n)
	check(MJ.tile_name(0) == "一萬" and MJ.tile_name(27) == "東" and MJ.tile_name(33) == "中", "牌の名前")
	# --- 押入れの麻雀牌
	var closet = apt.closet
	var box: Node3D = closet.mahjong_box
	check(box != null and box.get_node("MahjongArea").get_meta("interact_id") == "mahjong", "押入れのふとんの上に麻雀牌のケースがある")
	check(main.PROMPTS.has("record_set") and main.MESSAGES.has("mahjong") and main.ITEMS.has("mahjong"), "麻雀牌の文章・持ち物")
	main._on_interact_requested(box.get_node("MahjongArea"))
	check(main.inventory.has("mahjong") and closet.mahjong_box == null, "拾うと持ち物に入り、押入れからなくなる")
	main.select_item(main.inventory.find("mahjong"))
	main.use_selected()
	check(not main.mj_playing, "こたつの外では麻雀を打てない")
	player.pose = player.Pose.KOTATSU_IN
	main.use_selected()
	check(main.mj_playing and not player.controls_enabled and main.hud.is_mahjong_open(), "こたつの中で F を押すと一人麻雀が始まる")
	await process_frame
	check(main.mahjong.state == "playing" or main.mahjong.state == "won", "局が始まっている")
	if main.mahjong.state == "playing":
		var before: int = main.mahjong.discards.size()
		main._mahjong_input(_key(KEY_LEFT))
		check(main.mj_cursor == 12, "←で牌を選ぶ")
		main._mahjong_input(_key(KEY_ENTER))
		check(main.mahjong.discards.size() == before + 1, "Enter で切れる")
	# 連打：切った回数だけ捨て牌が増える
	var d0: int = main.mahjong.discards.size()
	var n_clicks := 0
	while main.mahjong.state == "playing" and n_clicks < 6:
		main._mahjong_input(_key(KEY_SPACE))
		n_clicks += 1
	check(main.mahjong.discards.size() == d0 + n_clicks, "切る操作の連打で二重に切れない（%d回→%d枚）" % [n_clicks, main.mahjong.discards.size() - d0])
	var pos0: Vector3 = player.global_position
	player.velocity = Vector3.ZERO
	check(not player.controls_enabled, "麻雀中は歩けない・視点も動かない（操作を止めている）")
	await process_frame
	check(player.global_position.distance_to(pos0) < 0.01, "麻雀中に体が動かない")
	main._mahjong_input(_key(KEY_ESCAPE))
	check(not main.mj_playing and player.controls_enabled and not main.hud.is_mahjong_open(), "Esc でやめる（操作が戻る）")
	player.pose = player.Pose.WALK
	# --- 床下の食べ物を冷蔵庫へ
	var cel = apt.cellar
	var k = apt.kitchen
	check(not apt.basement.visible and not cel.stairs_open, "最初は地下の階段がない")
	cel.set_open(true, false)
	k.interact("fridge_lower")
	await create_timer(0.8).timeout
	var inside: Area3D = k.get_node("InsideArea")
	var ids: Array = cel.FOODS.keys()
	check(ids.size() == 7, "運ぶ食べ物は7つ")
	for i in ids.size():
		var id: String = ids[i]
		check(cel.interact(id) == "cellar_carry_taken", "%s を持つ" % id)
		main._process(0.0)
		check(main.hud._carry_label.visible, "運んでいる表示が出る")
		if i == 0:
			main.select_item(-1)
			main._pause()
			main._on_interact_requested(inside)
			check(cel.stored.is_empty() and cel.carrying_id == id, "一時停止中は入れられない（持ったまま）")
			main._resume()
			check(cel.interact("cellar_can_1") == "cellar_carry_full" and cel.carrying_id == id, "持ったまま別の物は持てない")
			main.use_selected()
		main._on_interact_requested(inside)
		check(cel.stored.size() == i + 1 and cel.carrying_id.is_empty(), "冷蔵庫に入れた（%d/7）" % (i + 1))
	check(cel.stairs_open and apt.basement.visible, "全部入れると階段が現れる")
	check(main.PROMPTS[cel.get_prompt("cellar_stairs")] == "左クリック：地下へ降りる", "階段の案内")
	var left_stuff := 0
	for id in ids:
		if k.food_nodes[id].visible:
			left_stuff += 1
	check(left_stuff == 7, "冷蔵庫の棚に7つ並んだ")
	# --- 降りて手紙を読み、戻る
	# 食べ物の二重カウント・連打
	var stored_n: int = cel.stored.size()
	cel.carrying_id = "cellar_can_0"
	check(cel.food_stored() == stored_n, "すでに入れた物は二度数えない")
	cel.carrying_id = ""
	check(cel.food_stored() == stored_n, "何も持たずに入れても数えない")
	player.global_position = Vector3(4.3, 0.0, 0.62)   # 階段の手前（実際に降りる位置。穴の北）
	await physics_frame
	var start_pos: Vector3 = player.global_position
	main._descend()
	main._descend()   # 連打しても二重に動かない
	var fade_at_jump := -1.0
	var inside_floor := false
	for f in 600:
		await physics_frame
		if fade_at_jump < 0.0 and player.global_position.distance_to(start_pos) > 0.5:
			fade_at_jump = main.hud.fade_alpha()   # 位置が移った瞬間の暗さ
		if player.pose == player.Pose.TRANSITION and player.global_position.distance_to(start_pos) > 0.05 and player.global_position.distance_to(apt.basement.FEET) > 0.05:
			inside_floor = true   # 途中の（床の中の）位置を通っていないか
		if player.pose != player.Pose.TRANSITION and fade_at_jump >= 0.0:
			break
	check(fade_at_jump >= 0.95 and not inside_floor, "階段では、真っ暗になってから移る（移った瞬間の暗さ %.2f）。途中で床の中を通らない" % fade_at_jump)
	for f in 60:
		await physics_frame
	check(main.hud.fade_alpha() < 0.2 and player.controls_enabled and player.pose == player.Pose.WALK, "着いたら明るくなり、操作が戻る")
	var b = apt.basement
	check(player.pose == player.Pose.WALK and player.global_position.distance_to(b.FEET) < 0.4, "階段を降りて地下に着く")
	check(player.is_space_free(b.FEET, 1.6), "地下の足元に体が収まる")
	var letter: Node = b.get_node("Letter").get_node_or_null("LetterArea")
	if letter == null:
		for a in b.find_children("*", "Area3D", true, false):
			if a.get_meta("interact_id", "") == "basement_letter":
				letter = a
	check(letter != null, "地下に手紙が1枚ある")
	main._on_interact_requested(letter)
	check(main.reading, "手紙を読める")
	main._close_reader()
	main._ascend()
	for f in 300:
		await physics_frame
		if player.pose == player.Pose.WALK and player.global_position.distance_to(b.STAIR_EXIT) < 0.05:
			break
	for f in 80:
		await physics_frame
	check(player.is_space_free(player.global_position, 1.6), "上がった先で壁や床に埋まらない")
	check(player.global_position.distance_to(b.STAIR_EXIT) < 0.4, "階段を上がって部屋に戻る")
	# --- レコード
	var rp = apt.record_player
	check(rp.get_node_or_null("RecordDisplay") != null and rp.get_node("RecordDiscArea").get_meta("interact_id") == "record_disc", "壁にレコード盤が飾ってある")
	check(main.PROMPTS[rp.get_prompt("record_player")] == "左クリック：調べる", "盤がないと「調べる」")
	check(rp.interact("record_player") == "record_empty", "空のターンテーブルを調べる")
	# 配置：盤の額は壁のカセット棚（x 1.14）に重ならず、拾う前後とも棚や机を狙える
	var space2: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var aim_ids := func(at: Vector3) -> String:
		var eye := Vector3(2.4, 1.5, at.z)
		var q := PhysicsRayQueryParameters3D.create(eye, eye + (at - eye).normalized() * 3.0, player.ray.collision_mask)
		q.collide_with_areas = true
		var h: Dictionary = space2.intersect_ray(q)
		return String(h.collider.get_meta("interact_id", "")) if h.has("collider") else "なし"
	var shelf_pts := [Vector3(1.14, 1.45, 0.62), Vector3(1.14, 1.8, 0.62), Vector3(1.14, 1.2, 0.3), Vector3(1.14, 1.6, 1.0)]
	var before := []
	for pt in shelf_pts:
		before.append(aim_ids.call(pt))
	check(not before.has("record_disc"), "盤の額はカセット棚の前に出ていない（狙い先 %s）" % str(before))
	var rd: Node3D = rp.get_node("RecordDisplay")
	check(rd.global_position.y < 0.4 and rd.global_position.x < 1.45, "盤は床の低い棚に立て掛けてある")
	main._on_interact_requested(rp.get_node("RecordDiscArea"))
	var after := []
	for pt in shelf_pts:
		after.append(aim_ids.call(pt))
	check(after == before, "盤を拾う前後で、棚などの狙える物が変わらない")
	check(main.inventory.has("record_disc") and rp.display_taken, "壁のレコード盤を外して持てる")
	main.select_item(main.inventory.find("record_disc"))
	main._process(0.0)
	check(main.PROMPTS[rp.get_prompt("record_player")] == "左クリック：レコード盤をのせる", "盤を持つと「のせる」")
	var t0 := Time.get_ticks_msec()
	main._on_interact_requested(rp.get_node("RecordPlayerArea"))
	var made := Time.get_ticks_msec() - t0
	check(rp.loaded and rp.playing and not main.inventory.has("record_disc"), "盤をのせると回り出し、持ち物から消える（ジャズの生成 %d ms）" % made)
	check(rp._player.stream != null and rp._player.stream.get_length() > 15.0 and rp._player.playing, "ジャズが流れている（%.1f 秒の輪）" % rp._player.stream.get_length())
	check(main.PROMPTS[rp.get_prompt("record_player")] == "左クリック：針を上げる", "流れている間は「針を上げる」")
	check(rp.interact("record_player") == "record_stopped" and not rp.playing, "針を上げると止まる")
	check(rp.interact("record_player") == "record_started" and rp.playing, "もう一度針を落とすと流れる")
	for key in ["record_set", "record_empty", "record_stopped", "record_started", "mj_start", "mj_quit", "mj_need_kotatsu", "record_disc"]:
		check(main.MESSAGES.has(key), "%s の文章" % key)
	# --- 音：ラジオと同時、一時停止・再開、再プレイ
	main.room.apartment.radio.interact("radio")
	check(main.room.apartment.radio._player.playing and rp._player.playing, "ラジオと同時に鳴らせる")
	main._pause()
	check(get_root_paused(main), "一時停止中はツリーが止まり、音も止まる")
	main._resume()
	check(not paused_now(main) and rp._player.playing, "再開後も流れている")
	rp.interact("record_player")
	check(not rp._player.playing and not rp.playing, "針を上げると完全に止まる")
	rp.interact("record_player")
	check(rp._player.playing, "針を下げるとまた流れる")
	check(rp._gen_task == -1 and rp._wave_cache != null, "ジャズは別スレッドで事前生成済み")
	# --- 麻雀の結果画面（和了・流局）
	player.pose = player.Pose.KOTATSU_IN
	main.select_item(main.inventory.find("mahjong"))
	main.use_selected()
	var gm = main.mahjong
	gm.hand = [0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 27]
	gm.wall[gm.wall_pos] = 27
	gm.discard(13)
	check(gm.state == "won" and gm.yaku.size() > 0 and gm.points > 0, "和了：役 %s・%d点" % [str(gm.yaku), gm.points])
	main._process(0.0)
	check(main.hud._mj_status.text.contains("簡易採点"), "結果画面に「簡易採点」と出る（符・翻の計算なし）")
	var wins0: int = gm.wins
	main._mahjong_input(_key(KEY_SPACE))
	check(gm.state == "playing" and gm.games == 3 and gm.wins == wins0 and gm.total_points >= gm.points - 0, "続行：もう一局始まる")
	gm.draws = gm.MAX_DRAWS
	gm.discard(13)
	check(gm.state == "exhausted", "山が尽きると流局")
	main._mahjong_input(_key(KEY_ESCAPE))
	check(not main.mj_playing and player.controls_enabled, "終了して操作が戻る")
	player.pose = player.Pose.WALK
	# --- 当たり判定の衝突
	check(player.is_space_free(Vector3(1.9, 0.0, 0.62), 1.6), "プレーヤーの手前は歩ける")
	print("failures: %d" % failures)
	quit(1 if failures > 0 else 0)
