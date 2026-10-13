extends SceneTree
## 水槽・冷蔵庫と卵・コンロ・ラジオ・壁掛け時計・足音の素材・隣の音・響きの自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/life_test.gd
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
	# --- 水槽
	var aq = apt.aquarium
	check(aq != null and aq.fish.size() == 8, "水槽に魚が8匹（メダカ7＋アロワナ1）")
	check(main.PROMPTS[aq.get_prompt("aquarium")] == "左クリック：えさをやる" and aq.get_node("Collision").get_meta("fixture") == aq, "水槽はえさをやれる")
	var medaka_ok := true
	var arowana_ok := true
	var med_z := []
	var arowana_y := 0.0
	var moved := {}
	var start := {}
	for f in aq.fish:
		start[f.node.name] = f.node.position
	for step in 1200:   # 20 秒ぶん
		await physics_frame
		for f in aq.fish:
			var p: Vector3 = f.node.position
			if f.kind == "medaka":
				if p.z < 0.06 or p.z > 0.16 or p.y > 1.0:
					medaka_ok = false
				med_z.append(p.z)
			else:
				if p.y < 0.95:
					arowana_ok = false
				arowana_y = p.y
	for f in aq.fish:
		moved[f.node.name] = (f.node.position - start[f.node.name]).length()
	check(medaka_ok, "メダカは手前のガラスのそば（z 0.06〜0.16）の、水面より下を泳ぐ")
	check(arowana_ok and arowana_y > 0.95, "アロワナは水面近くの上のほうを泳ぐ（y %.2f）" % arowana_y)
	check(moved.values().all(func(d): return d > 0.02), "魚は自動で動いている")
	check(aq.interact("aquarium") == "aquarium_fed" and aq.feed_left > 9.0, "えさをやれる")
	check(aq.interact("aquarium") == "aquarium_full", "続けてはあげられない")
	for step in 360:
		await physics_frame
	var top := 0
	for f in aq.fish:
		if f.node.position.y > 0.95:
			top += 1
	check(top >= 6, "えさのあいだ魚は水面に集まる（%d匹）" % top)
	# --- 冷蔵庫と卵
	var k = apt.kitchen
	check(k.eggs_held == 0 and not k.lower_open, "最初は卵を持っておらず、冷蔵庫は閉まっている")
	check(k.get_node("EggArea0").collision_layer == 0, "閉まっているあいだ卵は狙えない")
	check(k.interact("fridge_lower") == "fridge_lower_opened" and k.lower_open, "冷蔵室を開けられる")
	check(k.get_node("EggArea0").collision_layer == 2, "開けると卵が狙える")
	check(main.PROMPTS.has(k.get_prompt("fridge_egg_0")) and main.MESSAGES.has("egg_taken"), "卵の案内と文章")
	check(k.interact("fridge_egg_0") == "egg_taken" and k.eggs_held == 1 and not k.get_node("Egg0").visible, "卵を取ると、パックから1個減る")
	check(k.format_message("egg_taken", main.MESSAGES["egg_taken"]).contains("1個") and k.format_message("egg_taken", main.MESSAGES["egg_taken"]).contains("残り5個"), "文章に持っている数と残りが入る")
	k.interact("fridge_egg_1")
	k.interact("fridge_egg_2")
	check(k.interact("fridge_egg_3") == "egg_hands_full" and k.eggs_held == 3, "卵は3つまで")
	check(k.interact("fridge_upper") == "fridge_upper_opened" and k.interact("fridge_inside") == "fridge_inside", "冷凍室も開く。中を調べられる")
	k.interact("fridge_lower")
	k.interact("fridge_upper")
	check(not k.lower_open and not k.upper_open and k.get_node("EggArea4").collision_layer == 0, "閉めると中身は狙えない")
	# --- コンロで目玉焼き
	check(main.PROMPTS[k.get_prompt("kitchen_stove")] == "左クリック：コンロに火をつける" and not k.flame_on, "コンロは最初火が消えている")
	check(k.interact("kitchen_stove") == "stove_on" and k.flame_on and k._flame.visible, "火がつく（炎が見える）")
	check(main.PROMPTS[k.get_prompt("kitchen_stove")] == "左クリック：卵を割って焼く", "卵を持っていれば「卵を割って焼く」")
	check(k.interact("kitchen_stove") == "stove_crack" and k.pan_state == "raw" and k.eggs_held == 2 and k._egg_white.visible, "卵を割ってフライパンに落とす")
	check(k.interact("kitchen_stove") == "stove_wait", "焼けるまで待つ")
	for i in int(k.COOK_TIME * 60 + 30):
		k._process(1.0 / 60.0)
	check(k.pan_state == "cooked", "約6秒で焼き上がる")
	check(k.interact("kitchen_stove") == "stove_eat_1" and k.pan_state == "empty" and k.eggs_eaten == 1, "食べられる")
	k.interact("kitchen_stove")   # 2個目を割る
	for i in int(k.BURN_TIME * 60 + 30):
		k._process(1.0 / 60.0)
	check(k.pan_state == "burnt" and main.PROMPTS[k.get_prompt("kitchen_stove")] == "左クリック：こげた卵を捨てる", "放っておくとこげる")
	check(k.interact("kitchen_stove") == "stove_burnt_clear" and k.pan_state == "empty", "こげた卵を捨てられる")
	k.eggs_held = 0
	check(k.interact("kitchen_stove") == "stove_off" and not k.flame_on and not k._flame.visible, "火を止められる")
	for key in ["stove_on", "stove_off", "stove_crack", "stove_wait", "stove_eat_1", "stove_eat_2", "stove_eat_3", "stove_burnt_clear", "fridge_closed", "aquarium_fed", "aquarium_full"]:
		check(main.MESSAGES.has(key), "%s の文章" % key)
	# 冷蔵庫の箱は体だけを止め、照準は通す
	check(k.get_node("FridgeBlock").collision_layer == 16, "冷蔵庫の箱は体だけを止める層（照準は扉・中身に届く）")
	# --- ラジオ
	var radio = apt.radio
	check(radio.channel == -1 and main.PROMPTS[radio.get_prompt("radio")] == "左クリック：ラジオをつける", "ラジオは最初消えている")
	var keys := []
	for i in 5:
		keys.append(radio.interact("radio"))
	check(keys == ["radio_ch1", "radio_ch2", "radio_ch3", "radio_ch4", "radio_off"] and radio.channel == -1, "つける→チャンネル4つ→消す の順に切り替わる")
	for key in keys:
		check(main.MESSAGES.has(key), "%s の文章" % key)
	radio.interact("radio")
	check(radio.get_node("Sound").playing and radio.get_node("Sound").stream.get_length() > 7.5 and radio.get_node("Sound").bus == "Ambient", "ラジオから音が鳴る（8秒の繰り返し）")
	radio.interact("radio")
	radio.interact("radio")
	radio.interact("radio")
	radio.interact("radio")
	# --- 壁掛け時計
	var clk = apt.wall_clock
	var now := Time.get_datetime_dict_from_system()
	await process_frame
	var min_deg: float = rad_to_deg(clk.minute_hand.rotation.z) / 6.0
	check(absf(fposmod(min_deg, 60.0) - now.minute) < 1.6 or absf(fposmod(min_deg, 60.0) - now.minute) > 58.4, "分針が今の分を指している（%d分）" % now.minute)
	var hour_deg: float = rad_to_deg(clk.hour_hand.rotation.z) / 30.0
	check(absf(fposmod(hour_deg, 12.0) - (now.hour % 12 + now.minute / 60.0)) < 0.1, "短針が今の時を指している")
	check(clk.get_node("TickSound").bus == "Ambient" and main.MESSAGES.has("wall_clock") and clk.time_text().contains("時"), "秒ごとのカチッという音と、調べると時刻が出る")
	# --- 足音の素材
	check(main._surface_at(Vector3(0.0, 0, 0.0)) == "tile", "浴室はタイルの足音")
	check(main._surface_at(Vector3(0.0, 0, 1.9)) == "wood", "ホールは床（木）の足音")
	check(main._surface_at(Vector3(2.6, 0, 0.78)) == "rug", "じゅうたんの上は静かな足音")
	check(main._surface_at(Vector3(4.3, 0, 1.3)) == "hollow", "床下の蓋の上は空洞の音")
	apt.cellar.set_open(true, false)
	check(main._surface_at(Vector3(4.3, 0, 1.3)) != "hollow", "蓋を開けるとその音はしない")
	apt.cellar.set_open(false, false)
	check(main._surface_at(Vector3(4.9, 0, 0.0)) == "wood", "ふつうの床は木の足音")
	check(player.STEP_SOUNDS.keys().size() == 6 and player.STEP_SOUNDS["rug"][2] < player.STEP_SOUNDS["wood"][2], "素材ごとに足音の音量・高さが違う")
	# --- 響き
	main.region = "bath"
	main._space_key = ""
	main._update_space()
	var sfx_i := AudioServer.get_bus_index("SFX")
	var rv: AudioEffectReverb = AudioServer.get_bus_effect(sfx_i, 0)
	check(rv.wet > 0.25, "浴室は響く（wet %.2f）" % rv.wet)
	main.region = "room"
	main._update_space()
	check(rv.wet < 0.1, "自室はあまり響かない（wet %.2f）" % rv.wet)
	player.pose = player.Pose.KOTATSU_IN
	main._update_space()
	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(sfx_i, 1)
	check(lp.cutoff_hz < 1500.0, "こたつの中では音がこもる（%d Hz）" % int(lp.cutoff_hz))
	player.pose = player.Pose.WALK
	main._update_space()
	check(lp.cutoff_hz > 15000.0, "出ると元に戻る")
	# --- 隣の部屋の音
	var amb = main.room.get_node("AmbientSound")
	for kind in ["thump", "pipe", "voices", "door"]:
		amb.play_neighbor(kind)
		check(amb.last_neighbor == kind and amb.get_node("Neighbor").stream.get_length() > 0.3 and amb.get_node("Neighbor").bus == "Ambient", "隣の音 %s" % kind)
	# --- ティッシュ・湯のみ
	check(main.TISSUE_SHEETS == 12, "ティッシュは12枚")
	var cup_area = apt.small_props.get_node("TableItems/Cup/Area_cup")
	main.play_time = 10.0
	main._on_interact_requested(cup_area)
	check(apt.small_props._steam[0].visible, "はじめは湯のみから湯気が出ている")
	print("life_test: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
