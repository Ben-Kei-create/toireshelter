extends SceneTree
## 段階 1a：点検レバー → 浴室がせり上がる（ゴゴゴ）→ 扉が壊れる → 木の棒・柱の小さな扉・停電 の回帰テスト。
## 実行: Godot --headless --path . --script res://tests/rise_test.gd（約 12 秒かかる）

var _failures := 0


func _initialize() -> void:
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 8:
		await process_frame
	var main = current_scene
	var room = main.room
	var cab = room.mirror_cabinet
	_check(cab.lever != null and cab.lever_arm != null, "鏡の戸棚の中に、点検レバーがある")
	_check(String(cab.lever.get_node("InspectLeverArea").get_meta("interact_id")) == "inspect_lever", "レバーは調べられる（inspect_lever）")
	_check(not room.risen and room.rise_offset == 0.0 and room.power_on, "はじめは上がっていない・電気がある")
	var toilet_y0: float = room.get_node("Toilet").position.y
	var hall_y0: float = room.get_node("Apartment").position.y
	var duct_y0: float = room.exterior.get_node("Duct").position.y
	var player_y0: float = main.player.global_position.y
	var light0: float = room.get_node("HallLight").light_energy

	main._pull_lever()
	await _wait(2.5)
	_check(room.rising and not room.risen, "引くと、せり上がりはじめる")
	_check(room.rise_offset > 0.05 and room.rise_offset < room.RISE_H, "途中の高さ（%.2f m）" % room.rise_offset)
	_check(not main.player.controls_enabled, "上がっている間は、体を動かせない")
	await _wait(8.0)
	_check(room.risen and not room.rising, "上がりきる")
	_check(is_equal_approx(room.rise_offset, room.RISE_H), "上がった高さは %.1f m" % room.RISE_H)
	_check(is_equal_approx(room.get_node("Toilet").position.y, toilet_y0 + room.RISE_H), "浴室の設備が上がる（便器）")
	_check(is_equal_approx(room.exterior.get_node("Duct").position.y, duct_y0 + room.RISE_H), "換気ダクトも上がる")
	_check(is_equal_approx(room.get_node("Apartment").position.y, hall_y0), "ホール・自室は動かない")
	_check(is_equal_approx(main.player.global_position.y - player_y0, room.RISE_H) or main.player.global_position.y > player_y0 + 0.8, "主人公も一緒に上がる（%.2f → %.2f）" % [player_y0, main.player.global_position.y])
	_check(main.player.controls_enabled, "上がりきると、また動ける")
	_check(cab.lever_pulled and cab.lever_arm.rotation.z > 0.5, "レバーの腕が倒れている")
	_check(not room.door_pivot.visible and room.door_body.collision_layer == 0, "扉が壊れた（見えない・当たり判定もない）")
	_check(room.get_node_or_null("DoorDebris") != null and room.get_node_or_null("BrokenDoor") != null, "破片と、枠に残る板がある")
	_check(room.wood_stick != null and room.wood_stick.visible, "木の棒が落ちている")
	_check(room.get_node_or_null("Pedestal") != null and room.get_node_or_null("FuseHatch") != null, "浴室の下の柱と、小さな扉がある")
	_check(not room.power_on and is_equal_approx(room.get_node("HallLight").light_energy, 0.0) and light0 > 0.0, "停電（ホールの灯りが消える）")
	_check(room.bath_light.light_energy > 0.3 and is_equal_approx(room.bath_light.position.y, 2.05 + room.RISE_H), "浴室の電球は点いたままで、浴室といっしょに上がる")
	for pat in ["ClosetLight", "HeaterLight", "TankLight"]:
		var l := room.apartment.find_child(pat, true, false) as OmniLight3D
		_check(l != null and l.light_energy < 0.01, "家電の明かりも消える（%s）" % pat)
	await _wait(1.5)
	_check(room.sky_clock.ambient_scale <= room.BLACKOUT_AMBIENT + 0.001 and room.sky_clock._env.ambient_light_energy < 0.06, "環境光も落ちて、部屋は真っ暗（環境光 %.3f）" % room.sky_clock._env.ambient_light_energy)
	_check(not room.apartment.hall_ceiling.visible and room.apartment.hall_ceiling_shape.disabled, "ホールの天井が抜ける")
	_check(is_equal_approx(room.exterior.facade_dy, room.RISE_H), "外壁の出口の穴が、上がった高さへ移る")
	_check(room.RISE_H >= 2.0, "上がる高さは %.1f m（天井の高さまで）" % room.RISE_H)
	_check(main.progress.chapter == 1, "第 2 幕になる")
	_check(main.progress.has_note("inspect_lever") and main.progress.has_note("rise_view"), "ノートに書かれる")
	_check(main.progress.discovered.has("unit_rise") and main.progress.discovered.has("inspect_lever"), "発見に数えられる")

	# 出られない：扉のあった開口の前に、体だけを止める板
	var blocker: StaticBody3D = room.get_node("DoorwayBlocker")
	_check(blocker.collision_layer == 16, "開口の前に、体だけを止める板がある")
	main.player.global_position = Vector3(0.0, room.RISE_H + 0.05, 0.95)
	await process_frame
	_check(main.player.test_move(main.player.global_transform, Vector3(0, 0, 0.7)), "開口から外へは出られない")
	# 木の棒を拾う
	main._on_interact_requested(room.wood_stick.get_node("WoodStickArea"))
	_check(main.inventory.has("wood_stick") and not room.wood_stick.visible, "木の棒を拾える")
	# 換気口・ダクトの座標は、上がった高さを足す
	_check(is_equal_approx(main._up(main.VENT_MOUTH).y, main.VENT_MOUTH.y + room.RISE_H), "換気口の座標に、上がった高さが足される")
	# 柱の小さな扉
	main._on_interact_requested(room.get_node("FuseHatch/FuseHatchArea"))
	_check(main.progress.has_note("fuse_hatch"), "小さな扉を調べるとノートに書かれる")
	# 保存して、読み込み直す
	var snap: Dictionary = main.progress.snapshot()
	_check(bool(snap.risen) and bool(snap.stick_taken), "保存に、上がった・棒を拾ったが入る")
	change_scene_to_file("res://scenes/main.tscn")
	for i in 8:
		await process_frame
	var main2 = current_scene
	main2.progress.apply(snap)
	await process_frame
	var r2 = main2.room
	_check(r2.risen and is_equal_approx(r2.rise_offset, r2.RISE_H), "読み込むと、上がった状態になる")
	_check(r2.wood_stick != null and not r2.wood_stick.visible, "拾った棒は、落ちていない")
	_check(not r2.power_on, "停電のまま")
	_check(main2.inventory.has("wood_stick") or snap.inventory.has("wood_stick"), "持ち物に木の棒")
	print("RISE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
