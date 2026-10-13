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
	main._descend()
	await create_timer(4.0).timeout
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
	await create_timer(4.0).timeout
	check(player.global_position.distance_to(b.STAIR_EXIT) < 0.4, "階段を上がって部屋に戻る")
	# --- レコード
	var rp = apt.record_player
	check(rp.get_node_or_null("RecordDisplay") != null and rp.get_node("RecordDiscArea").get_meta("interact_id") == "record_disc", "壁にレコード盤が飾ってある")
	check(main.PROMPTS[rp.get_prompt("record_player")] == "左クリック：調べる", "盤がないと「調べる」")
	check(rp.interact("record_player") == "record_empty", "空のターンテーブルを調べる")
	main._on_interact_requested(rp.get_node("RecordDiscArea"))
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
	# --- 当たり判定の衝突
	check(player.is_space_free(Vector3(1.9, 0.0, 0.62), 1.6), "プレーヤーの手前は歩ける")
	print("failures: %d" % failures)
	quit(1 if failures > 0 else 0)
