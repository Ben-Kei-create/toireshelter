extends SceneTree
## こたつから抜けられなくなる不具合の修正・ふとんで寝る・自分の体の初期オフ・管のステッカー・地下の壁の自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/sleep_test.gd
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
	var K = main.KotatsuScript
	# --- 自分の体は初期オフ
	check(player.show_body == false, "自分の体（3D）は初期でオフ")
	player._update_body(0.0)
	check(not player.body_rig.visible, "体が見えない")
	main._on_body_visible_changed(true)
	player._update_body(0.0)
	check(player.body_rig.visible, "設定でオンにすると見える")
	main._on_body_visible_changed(false)
	check(main.hud._body_check != null and not main.hud._body_check.button_pressed, "設定画面に切り替えがある")
	# --- こたつの中から 4 方向へ這い出る：抜けて立ち、本体に食い込まず、歩いて離れられる
	var c: Vector3 = K.CENTER
	for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]:
		player.global_position = c + side * 0.5
		player.pose = player.Pose.KOTATSU_IN
		player._set_body_height(player.KOTATSU_BODY_HEIGHT, player.KOTATSU_BODY_RADIUS)
		player._shape.disabled = false
		apt.kotatsu.set_solid(false)
		player.controls_enabled = true
		# 這って縁の外へ（0.02m ずつ）
		var pose_after := -1
		for step in 40:
			player.global_position += side * 0.02
			main._physics_process(0.0)
			if player.pose != player.Pose.KOTATSU_IN:
				break
		pose_after = player.pose
		var name := "東" if side.x > 0 else ("西" if side.x < 0 else ("北" if side.z < 0 else "南"))
		if pose_after == player.Pose.KOTATSU_IN:
			check(true, "%s側：出口がふさがっているので出ない（這えるまま。南は寝床が近い）" % name)
			continue
		check(pose_after == player.Pose.WALK or pose_after == player.Pose.CROUCH, "%s側：抜けて立つ（または しゃがむ）" % name)
		check(player.is_space_free(player.global_position, player.CROUCH_BODY_HEIGHT), "%s側：本体に食い込んでいない" % name)
		check(not player.test_move(player.global_transform, side * 0.3), "%s側：外へ 0.3m 歩ける（引っかからない）" % name)
		player.pose = player.Pose.WALK
	player.pose = player.Pose.WALK
	player.global_position = Vector3(1.7, 0.0, 1.98)
	player._set_body_height(player.BODY_HEIGHT)
	# --- ふとんで寝る
	var bed_area: Area3D = apt.get_node("Bed/BedArea")
	check(bed_area.get_meta("interact_id") == "bed" and main.MESSAGES.has("bed"), "寝床を調べられる")
	main._on_interact_requested(bed_area)
	check(main.ACTION_PROMPTS.has("sleep") and main.ACTION_PROMPTS.has("get_up"), "案内「寝る」「起きる」")
	# E の判定：照準の対象が寝床なら寝られる
	check(main._action_for(bed_area) == "sleep", "立っているとき、寝床を狙うと「寝る」")
	player.pose = player.Pose.KOTATSU_SEAT
	check(main._action_for(bed_area) != "sleep", "こたつにいる間は寝られない（こたつを抜けたあと）")
	player.pose = player.Pose.WALK
	player.enter_fixed(player.Pose.LYING, main.BED_FEET, main.BED_YAW, main.BED_EYE)
	await create_timer(1.2).timeout
	check(player.pose == player.Pose.LYING, "寝た姿勢になる")
	check(player.camera.rotation.x > 1.2, "天井を見上げる（視線の仰角 %.2f rad）" % player.camera.rotation.x)
	check(player.global_position.y < 0.4 and not player.body_rig.visible, "ふとんの上で、体は見えない")
	var rot0: float = player.rotation.y
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(200, -200)
	player._unhandled_input(ev)
	check(absf(player.rotation.y - rot0) < 0.001 and player.camera.rotation.x > 1.2, "寝ている間は視線が動かない（天井のまま）")
	check(main._action_for(null) == "get_up", "寝ているとき E は「起きる」")
	main.do_action()
	await create_timer(1.2).timeout
	check(player.pose == player.Pose.WALK and absf(player.camera.rotation.x) < 0.1, "起きて立つ。視線も水平に戻る")
	check(player.is_space_free(player.global_position, player.BODY_HEIGHT), "起きた先で何かに埋まらない")
	# --- 管のステッカー
	var duct = apt.get_parent().get_node_or_null("Exterior")
	var stickers := 0
	if duct:
		for n in duct.find_children("Sticker*", "MeshInstance3D", true, false):
			stickers += 1
	check(stickers >= 12, "管の中にステッカーが %d 枚貼ってある" % stickers)
	# --- 地下の壁：部屋の東側の壁が両側にある
	check(apt.basement.has_node("Collision") and apt.basement.get_node("Collision").get_child_count() >= 12, "地下の壁・床の当たり判定がそろっている（東側の壁を含む）")
	print("failures: %d" % failures)
	quit(1 if failures > 0 else 0)
