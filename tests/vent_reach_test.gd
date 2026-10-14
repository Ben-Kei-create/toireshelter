extends SceneTree
## 段階 1b：換気口は、物理的に届かないといけない。逆さの風呂桶に乗れば届く／背が最大（170 cm）なら背伸びで届く（小ネタ）。
## 実行: Godot --headless --path . --script res://tests/vent_reach_test.gd

const Pose := preload("res://scripts/player.gd").Pose
var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var player = main.player
	var room = main.room
	main._on_eye_height_changed(1.5)
	var vent_pos := Vector3(-0.72, 2.18, -1.02)

	# --- 床から（普通の背）：届かない
	player.global_position = Vector3(-0.3, 0.0, -0.1)
	_aim(player, vent_pos)
	_check(main._action_for(player.get_focused(true)) != "vent_stretch", "普通の背（150 cm）では、床から背伸びしても届かない")
	# --- 浴槽に入っても（桶なし）：届かない
	var feet: Vector3 = main._tub_feet()
	player.enter_fixed(Pose.IN_TUB, feet, main.TUB_YAW, main._tub_eye())
	await _seconds(1.0)
	_aim(player, vent_pos)
	await physics_frame
	await physics_frame
	var t = player.get_focused(true)
	_check(t != null and String(t.get_meta("interact_id", "")) == "vent", "浴槽から換気口を狙える")
	_check(main._action_for(t) == "vent_far", "桶なしでは「E：手を伸ばす」（届かない）")
	main.do_action()
	_check(main.hud._message_label.text == main.MESSAGES["vent_far"] and player.pose == Pose.IN_TUB, "届かない、と言われる。入れない")
	# --- 桶を拾って、浴槽の中から置く：桶の上に乗って、目が上がる
	var y0: float = player.global_position.y
	player.leave_fixed(main.TUB_EXITS)
	await _seconds(1.2)
	player.global_position = Vector3(0.2, 0.0, -0.1)
	_aim(player, room.get_node("BathBucket").global_position + Vector3(0, 0.1, 0))
	player.try_interact()
	_check(main.inventory.has("bucket") and not room.get_node("BathBucket").visible, "風呂桶を拾える（元の場所からなくなる）")
	player.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(player, room.bathtub.to_global(Vector3(0.3, 0.3, 0.375)))
	_check(main._use_prompt(player.get_focused(true)).find("風呂桶") >= 0, "浴槽を狙うと「F：風呂桶を逆さにして浴槽に置く」")
	main.use_selected()
	_check(room.bucket_in_tub and room.bathtub.get_node_or_null("BucketInTub") != null, "逆さの風呂桶が、浴槽の底にある")
	_check(is_equal_approx(main._tub_feet().y - feet.y, room.BUCKET_H), "桶の上では、足元が %.2f m 上がる" % room.BUCKET_H)
	_check(main._tub_eye() > 1.3, "桶の上では立った高さ（目 %.2f m）" % main._tub_eye())
	# --- 桶の上から換気口へ
	player.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(player, room.bathtub.to_global(Vector3(0.3, 0.3, 0.375)))
	main.do_action()   # 浴槽へ（桶の上）
	await _seconds(0.9)
	_check(player.pose == Pose.IN_TUB and player.global_position.y > y0 + 0.25, "桶に乗って浴槽に入る（足元 %.2f m）" % player.global_position.y)
	_aim(player, vent_pos)
	_check(main._action_for(player.get_focused(true)) == "vent_enter", "桶に乗ると「E：換気口へ入る」")
	main.do_action()
	await _seconds(1.8)
	_check(player.pose == Pose.DUCT and room.vent_open, "換気口の中へ入れる")
	print("VENT REACH TEST (part 1): %d failure(s)" % _failures)

	# --- 小ネタ：背が最大なら、床から背伸びして入れる（別のゲームで確かめる）
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	main = current_scene
	player = main.player
	room = main.room
	main._on_eye_height_changed(1.7)
	player.global_position = Vector3(-0.3, 0.0, -0.1)
	await process_frame
	_aim(player, vent_pos)
	var tv = player.get_focused(true)
	_check(tv != null and String(tv.get_meta("interact_id", "")) == "vent", "背が最大のとき、床から換気口を狙える")
	_check(main._action_for(tv) == "vent_stretch" and main.ACTION_PROMPTS["vent_stretch"].find("背伸び") >= 0, "「E：背伸びして換気口へ」が出る（170 cm の小ネタ）")
	main.do_action()
	_check(main.hud._message_label.text == main.MESSAGES["vent_stretch"], "背伸びで届いた、と言われる")
	await _seconds(2.0)
	_check(player.pose == Pose.DUCT and room.vent_open, "桶なしで、換気口の中へ入れる")
	_check(main.progress.discovered.has("vent_stretch"), "発見に数えられる")
	main._on_eye_height_changed(1.5)   # 設定ファイルを元に戻す
	print("VENT REACH TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _aim(player: Node3D, point: Vector3) -> void:
	var d: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	player._pitch = pitch
	player.camera.rotation.x = pitch


func _seconds(t: float) -> void:
	await create_timer(t).timeout


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
