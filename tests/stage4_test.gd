extends SceneTree
## 段階 4 の検証：手かがみ → 宝石（暗い部屋・青いトイレの光・近づく）が割れる → ツルハシ・結晶 → こたつの壁を壊す → 隣の和室（暗い・ライター・掛け軸の高さ 142 cm）
## → 本から栞 3 枚 → 家宝に順に差す → 写真（神の声が黙る）→ はしご・コイン。保存と復元も。
## 実行: Godot --headless --path . --script res://tests/stage4_test.gd

const Pose := preload("res://scripts/player.gd").Pose
var _failures := 0


func _initialize() -> void:
	_run()


func _fresh() -> Node:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var m := current_scene
	m.credits_enabled = false
	return m


func _run() -> void:
	var main = await _fresh()
	var room = main.room
	var apt = room.apartment
	var player = main.player
	room.rise_unit(player, true)
	await process_frame
	_check(not room.power_on and not apt.gem_broken, "せり上がったあと：停電・宝石はまだ割れていない")

	# ---------------------------------------------------------------- 手かがみ
	main._on_interact_requested(room.mirror_cabinet.get_node("Items/HandMirror/HandMirrorArea"))
	_check(main.inventory.has("hand_mirror") and not room.mirror_cabinet.hand_mirror.visible, "戸棚の手かがみを拾う")
	# ---------------------------------------------------------------- 宝石：条件がそろうまで割れない
	player.global_position = Vector3(2.4, 0.0, 1.15)
	room.set_power(true, true)
	main._use_mirror_on_gem()
	_check(main.hud._message_label.text == main.STAGE4["gem_bright"] and not apt.gem_broken, "部屋が明るいと、反射が見えない")
	room.set_power(false, true)
	room.set_bath_light(false)
	main._use_mirror_on_gem()
	_check(main.hud._message_label.text == main.STAGE4["gem_no_light"], "トイレの明かりが消えていると、はね返す光がない")
	room.set_bath_light(true)
	main._use_mirror_on_gem()
	_check(main.hud._message_label.text == main.STAGE4["gem_white"] and not apt.gem_broken, "光が白いと、宝石は反応しない")
	room.bath_purple = true
	player.global_position = Vector3(1.2, 0.0, -0.9)
	main._use_mirror_on_gem()
	_check(main.hud._message_label.text == main.STAGE4["gem_far"] and not apt.gem_broken, "遠すぎると、向きを合わせられない")
	player.global_position = Vector3(2.4, 0.0, 1.15)
	main._use_mirror_on_gem()
	await create_timer(0.8).timeout
	_check(apt.gem_broken and not apt.gem_stone.visible, "暗い部屋で、青い光を近くからはね返すと、宝石が割れる")
	await create_timer(2.6).timeout
	main._on_interact_requested(apt.pickaxe_prop.get_node("PickaxeArea"))
	main._on_interact_requested(apt.crystal_prop.get_node("CrystalArea"))
	_check(main.inventory.has("pickaxe") and main.inventory.has("crystal"), "大きなツルハシと結晶が手に入る")

	# ---------------------------------------------------------------- こたつの壁
	var kot = apt.kotatsu
	var wall_area: Node = kot.get_node("InnerWall/InnerWallArea")
	main._on_interact_requested(wall_area)
	_check(main.hud._message_label.text == main.STAGE4["wall_hard"] and not kot.wall_broken, "素手では壊れない（ツルハシを持つと「硬い」）")
	kot.set_solid(false)
	var wall_world: Vector3 = kot.global_position + kot.WALL_LOCAL
	player.global_position = Vector3(wall_world.x - 0.55, 0.0, wall_world.z)
	var d: Vector3 = (wall_world + Vector3(0, 0.2, 0)) - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	player.camera.rotation.x = player._pitch
	await physics_frame
	await physics_frame
	main.select_item(main.inventory.find("pickaxe"))
	var tw = player.get_focused(true)
	_check(tw != null and String(tw.get_meta("interact_id", "")) == "kotatsu_wall", "こたつの中の壁を狙える")
	main.use_selected()
	_check(kot.wall_broken, "ツルハシで、壁が壊れる")

	# ---------------------------------------------------------------- 隣の和室へ
	var amb0: float = room.sky_clock.ambient_scale
	player.pose = Pose.KOTATSU_IN
	main._enter_washitsu()
	var guard := 0
	while main.washitsu_transit and guard < 600:
		await physics_frame
		guard += 1
	await physics_frame
	await physics_frame
	var wp: Vector3 = room.washitsu.global_position
	_check(main.region == "washitsu" and player.global_position.distance_to(wp) < 3.0, "隣の和室に着く（%s）" % main.region)
	_check(room.sky_clock.ambient_scale <= 0.011 and main.progress.chapter == 3, "真っ暗になり、第4幕になる（環境光 %.3f・%s）" % [room.sky_clock.ambient_scale, main.progress.chapter_name()])
	# ライター（ブレーカー）
	var br = room.exterior.breaker
	br.open_cover()
	main._on_interact_requested(br.get_node("Lighter/LighterArea"))
	_check(main.inventory.has("lighter") and br.lighter_taken, "ブレーカーの蓋の中のライターを拾う")
	main.select_item(main.inventory.find("lighter"))
	await process_frame
	_check(main._torch_light != null and main._torch_light.visible, "ライターを持つと、手元が小さく明るくなる")
	# 掛け軸：高さがぴったり 142 cm のときだけ
	player.set_eye_height(1.5)
	main._look_scroll()
	_check(main.hud._message_label.text == main.STAGE4["scroll_blotch"], "ふだんの高さでは、墨がバラバラ")
	player.set_eye_height(1.42)
	main._look_scroll()
	_check(main.hud._message_label.text == main.STAGE4["scroll_aligned"] and main.progress.discovered.has("scroll_aligned"), "ぴったり 142 cm だと、犬・猿・キジが揃う")
	for i in 40:
		await physics_frame
	var a: float = ((room.washitsu.scroll_overlay.get_node("Animal0") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a
	_check(a > 0.9, "影絵が見える（%.2f）" % a)
	player.set_eye_height(1.5)

	# ---------------------------------------------------------------- 本の栞（3 冊）と家宝
	for t in [["透明な隣人", "bm_dog"], ["影の標本室", "bm_monkey"], ["椅子の渡り鳥", "bm_pheasant"]]:
		main._open_reader(t[0], ["a", "b", "c"], null, Color.WHITE)
		main._reader_page = 2
		main._close_reader()
		_check(main.inventory.has(t[1]), "『%s』を読み終えると、栞が出る（%s）" % [t[0], t[1]])
	main.reading = false
	main._open_reader("石の育て方", ["a", "b", "c"], null, Color.WHITE)
	main._reader_page = 2
	main._close_reader()
	_check(main.inventory.size() >= 3 and not main.inventory.has("bm_x"), "ほかの本には栞はない")
	main._insert_bookmark("bm_monkey")
	_check(main.hud._message_label.text == main.STAGE4["slot_wrong"] and main.inventory.has("bm_monkey") and room.washitsu.slots_filled == 0, "順番がちがうと、入らない（栞は減らない）")
	main._insert_bookmark("bm_dog")
	main._insert_bookmark("bm_monkey")
	main._insert_bookmark("bm_pheasant")
	await create_timer(1.6).timeout
	_check(room.washitsu.slots_filled == 3 and room.washitsu.heirloom_open and not main.inventory.has("bm_dog"), "犬・猿・キジの順に差すと、家宝が開く")
	main._on_interact_requested(room.washitsu.photo_prop.get_node("PhotoArea"))
	_check(main.inventory.has("photo_tkg") and room.washitsu.photo_taken, "写真『おふくろのTKG』を取る")
	await create_timer(5.0).timeout
	_check(main.god_silent and main.hud.voice_silenced, "神の声が黙る")
	main.hud.show_message("ヒント", -1.0, "voice")
	_check(main.hud._message_label.text != "『ヒント』", "黙ったあとは、神の声の文章は出ない")
	_check(main.progress.ask_hint() == "none", "「神の声にきく」も、答えがない")
	# はしごとコイン
	main._on_interact_requested(room.washitsu.ladder_prop.get_node("LadderArea"))
	var coins0: int = main.coin_count
	main._on_interact_requested(room.washitsu.coin_prop.get_node("CoinArea"))
	_check(main.inventory.has("wood_ladder") and main.coin_count == coins0 + 1, "はしごを拾い、暗い隅のコインを 1 枚拾う")

	# ---------------------------------------------------------------- はしご：浴室へ立てかけて（F）、上り下り
	main.select_item(main.inventory.find("wood_ladder"))
	var hatch_node: Node3D = room.get_node("FuseHatch")
	player.global_position = Vector3(hatch_node.global_position.x, 0.0, hatch_node.global_position.z + 0.8)
	var dh: Vector3 = hatch_node.global_position - player.camera.global_position
	player.rotation.y = atan2(-dh.x, -dh.z)
	player._pitch = atan2(dh.y, Vector2(dh.x, dh.z).length())
	player.camera.rotation.x = player._pitch
	await physics_frame
	await physics_frame
	player.pose = Pose.WALK
	main.use_selected()
	_check(room.ladder_placed and not main.inventory.has("wood_ladder"), "はしごを、浮き上がった浴室へ立てかけられる（F）")
	var lad = room.ladder_node.get_node("PlacedLadderArea")
	player.global_position = Vector3(0.0, 0.05, 1.9)
	_check(main._action_for(lad) == "ladder_up" and main.ACTION_PROMPTS["ladder_up"] == "E：はしごで、浴室へ上る", "ホールでは「E：はしごで、浴室へ上る」")
	main._climb_ladder(true)
	guard = 0
	while main.washitsu_transit and guard < 600:
		await physics_frame
		guard += 1
	_check(player.global_position.y > room.rise_offset - 0.1, "はしごを上ると、浮き上がった浴室へ戻れる（y %.2f）" % player.global_position.y)
	main._climb_ladder(false)
	guard = 0
	while main.washitsu_transit and guard < 600:
		await physics_frame
		guard += 1
	_check(player.global_position.y < 0.5, "はしごを下りると、ホールへ戻る（y %.2f）" % player.global_position.y)

	# ---------------------------------------------------------------- こたつの中へ戻る
	main._leave_washitsu()
	guard = 0
	while main.washitsu_transit and guard < 600:
		await physics_frame
		guard += 1
	_check(player.pose == Pose.KOTATSU_IN and absf(room.sky_clock.ambient_scale - amb0) < 0.001, "穴から、こたつの中へ戻る。環境光ももとに戻る")

	# ---------------------------------------------------------------- 保存して、復元
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	var st: Dictionary = snap.get("stage4", {})
	_check(bool(st.get("gem_broken")) and bool(st.get("wall_broken")) and int(st.get("slots")) == 3 and bool(st.get("heirloom_open")) and bool(st.get("photo_taken")) and bool(st.get("god_silent")) and bool(st.get("ladder_taken")) and bool(st.get("coin_taken")) and bool(st.get("lighter_taken")), "保存に、段階 4 の進み具合が入る")
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	var r2 = main.room
	_check(r2.apartment.gem_broken and r2.apartment.kotatsu.wall_broken and r2.washitsu.heirloom_open and r2.washitsu.photo_taken and main.god_silent and r2.washitsu.ladder_taken and r2.washitsu.coin_taken,
			"新しい画面に復元すると、同じ状態になる")
	_check(main.inventory.has("hand_mirror") and main.inventory.has("pickaxe") and main.inventory.has("photo_tkg") and main.progress.snapshot()["stage4"]["ladder_placed"] and main.room.ladder_placed, "持ち物も、立てかけたはしごも戻る")
	# ---------------------------------------------------------------- TKG：ご飯 + 卵 → 冷めた TKG → 電子レンジ → TKG → 食べる
	main = await _fresh()
	main.ride_speed = 20.0
	var k = main.room.apartment.kitchen
	main._give_stage5("rice_pack")   # パックご飯は、つかみ取りの 5 個目の景品
	_check(main.inventory.has("rice_pack"), "パックご飯を持っている")
	main.select_item(main.inventory.find("rice_pack"))
	main.use_selected()
	_check(main.hud._message_label.text == main.STAGE4["need_egg"] and main.inventory.has("rice_pack"), "卵がないと、冷めた TKG は作れない（ご飯は減らない）")
	k.eggs_held = 1
	main.use_selected()
	_check(main.inventory.has("cold_tkg") and not main.inventory.has("rice_pack") and k.eggs_held == 0, "ご飯と卵で、冷めた TKG ができる（卵が 1 つ減る）")
	main.room.set_power(false, true)
	main._heat_tkg()
	_check(main.inventory.has("cold_tkg") and main.hud._message_label.text == main.POWER_DEAD["microwave"], "停電中は、電子レンジが動かない（冷めた TKG は減らない）")
	main.room.set_power(true, true)
	main._heat_tkg()
	await create_timer(1.0).timeout
	_check(main.inventory.has("tkg") and not main.inventory.has("cold_tkg"), "電子レンジでチンすると、TKG ができる")
	main.select_item(main.inventory.find("tkg"))
	main.use_selected()
	_check(not main.inventory.has("tkg") and main.progress.discovered.has("tkg_eaten"), "食べると、ひとこと出て、TKG はなくなる")
	print("STAGE4 TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
