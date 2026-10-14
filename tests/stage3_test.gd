extends SceneTree
## 段階 3 の検証：窓の鍵（釣りで必ず出る）→ マッチ棒＋木の棒の松明 → 暗い部屋（電気の物は使えない）→ カーテンを開けて松明を捨てる（月明かり）
## → ふすま → 壊れたドアノブ → 小さな扉（ドアノブで開く）→ ヒューズ → ベランダのブレーカー（ドライバーで蓋・ヒューズで電気）→ 電気がつき、松明の火が消える。保存と復元も。
## 実行: Godot --headless --path . --script res://tests/stage3_test.gd

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
	# 浴室がせり上がったあとの状態を作る（停電・窓は施錠・はしごを下ろした）
	room.rise_unit(player, true)
	room.exterior.lower_ladder(room.exterior.DUCT_FLOOR + room.rise_offset, true)
	await process_frame
	_check(not room.power_on and apt.window_locked and room.exterior.ladder_down, "せり上がったあと：停電・窓は施錠・はしごが下りている")

	# ---------------------------------------------------------------- 窓の鍵
	player.global_position = Vector3(2.5, 0.0, -1.7)
	var win_area: Node = apt.window_panel.get_node("WindowArea")
	main._on_interact_requested(win_area)
	_check(main.hud._message_label.text == main.STAGE3["window_locked"] and not apt.window_open, "ベランダから窓を開けようとすると「鍵がかかっている」")
	# ---------------------------------------------------------------- 釣り：マッチ棒 → 部屋の鍵 が、数回で必ず出る
	main.fishing.has_rod = true
	var casts := 0
	while not main.inventory.has("match_stick") and casts < 8:
		main.fishing._land(main.fishing._pick())
		casts += 1
	_check(main.inventory.has("match_stick") and casts <= 4, "釣りで、マッチ棒が数回（%d 回）で必ず出る" % casts)
	casts = 0
	while not main.inventory.has("room_key") and casts < 8:
		main.fishing._land(main.fishing._pick())
		casts += 1
	_check(main.inventory.has("room_key") and casts <= 4, "つづけて、部屋の鍵も数回（%d 回）で必ず出る" % casts)
	var again := 0
	for i in 12:
		var pk: Array = main.fishing._pick()
		if pk.size() > 4 and pk[4] == "story":
			again += 1
	_check(again == 0, "取れた物は、二度と釣れない（お話の物の重複なし）")

	# ---------------------------------------------------------------- 松明を作る
	main.add_item("wood_stick")
	main.select_item(main.inventory.find("wood_stick"))
	main.use_selected()
	_check(main.inventory.has("torch") and not main.inventory.has("wood_stick") and not main.inventory.has("match_stick") and main.selected_item() == "torch",
			"木の棒とマッチ棒で松明ができ、手に持つ")
	await process_frame
	_check(main._torch_light != null and main._torch_light.visible, "松明を持つと、手元が明るくなる")

	# ---------------------------------------------------------------- 窓の鍵を開けて部屋へ
	main.select_item(main.inventory.find("room_key"))
	_aim(player, win_area.global_position)
	await physics_frame
	await physics_frame
	main.use_selected()
	_check(not apt.window_locked and main.hud._message_label.text == main.STAGE3["window_unlocked"], "部屋の鍵を窓に使うと、鍵が開く")
	main._on_interact_requested(win_area)
	await create_timer(0.7).timeout
	_check(apt.window_open, "窓を開けられる")

	# ---------------------------------------------------------------- 暗い部屋：電気の物は使えない
	player.global_position = Vector3(2.5, 0.0, 0.5)
	await physics_frame
	await physics_frame
	var tv: Node = apt.find_child("TvArea", true, false)
	if tv == null:
		tv = Node.new()
		tv.set_meta("interact_id", "tv_play")
	main._on_interact_requested(tv)
	_check(main.hud._message_label.text == main.POWER_DEAD["tv_play"], "停電中、テレビは使えず、説明だけが出る")
	var kt := Node.new()
	kt.set_meta("interact_id", "kotatsu")
	main._on_interact_requested(kt)
	_check(main.hud._message_label.text == main.POWER_DEAD["kotatsu"], "停電中、こたつは使えない（「暖かくない」）")

	# ---------------------------------------------------------------- カーテンを開ける：月明かりと、松明を捨てる
	var amb0: float = room.sky_clock.ambient_scale
	apt.toggle_curtain()
	await create_timer(2.6).timeout
	_check(not main.inventory.has("torch") and main.thrown_torch != null and main.thrown_torch.burning, "カーテンを開けると、松明を窓の外へ捨てる（燃え続ける）")
	_check(room.sky_clock.ambient_scale > amb0 + 0.02, "月明かりが差す（環境光 %.3f → %.3f）" % [amb0, room.sky_clock.ambient_scale])

	# ---------------------------------------------------------------- ふすま → ドアノブ → 小さな扉 → ヒューズ
	var fus = apt.hall_fusuma
	_check(not fus.open, "ホールと部屋の境のふすまは、はじめ閉まっている")
	player.global_position = Vector3(1.6, 0.0, 1.85)
	player.rotation.y = PI * 0.5
	Input.action_press("move_forward")
	await create_timer(0.8).timeout
	Input.action_release("move_forward")
	_check(player.global_position.x > 1.2, "閉まっていると、通れない（x=%.2f）" % player.global_position.x)
	fus.interact("hall_fusuma")
	await create_timer(0.9).timeout
	_check(fus.open, "クリックで、ふすまが開く")
	player.global_position = Vector3(1.6, 0.0, 1.85)
	player.rotation.y = PI * 0.5
	Input.action_press("move_forward")
	await create_timer(1.3).timeout
	Input.action_release("move_forward")
	_check(player.global_position.x < 0.9, "開けると、ホールへ通れる（x=%.2f）" % player.global_position.x)
	var knob_area: Node = room.knob_node.get_node("DoorKnobArea")
	main._on_interact_requested(knob_area)
	_check(main.inventory.has("door_knob") and room.knob_taken, "ホールの床の壊れたドアノブを拾う")
	main.select_item(main.inventory.find("door_knob"))
	var hatch: Node3D = room.get_node("FuseHatch")
	player.global_position = Vector3(hatch.global_position.x, 0.0, hatch.global_position.z + 0.9)
	_aim(player, hatch.global_position)
	await physics_frame
	await physics_frame
	var ht = player.get_focused(true)
	_check(ht != null and String(ht.get_meta("interact_id", "")) == "fuse_hatch", "小さな扉を狙える")
	main.use_selected()
	await create_timer(0.9).timeout
	_check(room.hatch_open and not main.inventory.has("door_knob"), "ドアノブを使うと、小さな扉が開く")
	var fuse_area: Node = room.get_node("FuseHatch/Fuse/FuseArea")
	main._on_interact_requested(fuse_area)
	_check(main.inventory.has("fuse") and room.fuse_taken, "中のヒューズを拾う")

	# ---------------------------------------------------------------- ブレーカー：蓋 → ヒューズ → 電気
	var br = room.exterior.breaker
	var br_area: Node = br.get_node("BreakerArea")
	player.global_position = Vector3(1.9, 0.0, -1.75)
	_aim(player, br.global_position)
	await physics_frame
	await physics_frame
	main._on_interact_requested(br_area)
	_check(main.hud._message_label.text == main.STAGE3["breaker_closed"], "ブレーカーを調べると「ねじがひとつ。ドライバーが使えそうだ」")
	main.select_item(main.inventory.find("fuse"))
	main.use_selected()
	_check(not br.fuse_in and main.hud._message_label.text == main.STAGE3["breaker_cover_first"], "蓋が閉まったままでは、ヒューズは差せない")
	main.add_item("driver")
	main.select_item(main.inventory.find("driver"))
	main.use_selected()
	await create_timer(1.6).timeout
	_check(br.cover_open and main.inventory.has("driver"), "ドライバーでねじを回すと蓋が開く（ドライバーは減らない）")
	main._on_interact_requested(br_area)
	_check(main.hud._message_label.text == main.STAGE3["breaker_no_fuse"], "蓋を開けたあとは「ヒューズがない」")
	main.select_item(main.inventory.find("fuse"))
	main.use_selected()
	await create_timer(1.8).timeout
	_check(br.fuse_in and room.power_on and main.power_restored and not main.inventory.has("fuse"), "ヒューズを差すと、部屋の電気がつく")
	_check(not main.thrown_torch.burning, "ベランダの松明の火が消える")
	_check(main.progress.chapter == 3, "第4幕へ進む（%s）" % main.progress.chapter_name())
	main._on_interact_requested(tv)
	_check(main.hud._message_label.text != main.POWER_DEAD["tv_play"], "電気が戻ると、テレビなどが使える")

	# ---------------------------------------------------------------- 保存して、新しい画面で復元
	var snap: Dictionary = main.progress.snapshot()
	var st: Dictionary = snap.get("stage3", {})
	_check(bool(st.get("power_restored")) and bool(st.get("breaker_fuse")) and bool(st.get("hatch_open")) and bool(st.get("fuse_taken")) and bool(st.get("knob_taken")) and bool(st.get("fusuma_open")) and not bool(st.get("window_locked", true)), "保存に、段階 3 の進み具合が入る")
	var json_text := JSON.stringify(snap)
	var back: Dictionary = JSON.parse_string(json_text)
	main = await _fresh()
	main.progress.apply(back)
	await process_frame
	var r2 = main.room
	_check(r2.power_on and main.power_restored and r2.exterior.breaker.fuse_in and r2.hatch_open and r2.fuse_taken and r2.knob_taken and r2.apartment.hall_fusuma.open and not r2.apartment.window_locked,
			"新しい画面に復元すると、同じ状態になる")
	print("STAGE3 TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _aim(player: Node3D, point: Vector3) -> void:
	var d: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	player._pitch = pitch
	player.camera.rotation.x = pitch


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
