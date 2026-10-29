extends SceneTree
## 段階 1b：換気口は、物理的に届かないといけない。背が最大（170 cm）なら背伸びで届く（小ネタ）。
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
	# --- 風呂桶は調べるだけ（足場にはならない）。拾えない
	player.leave_fixed(main.TUB_EXITS)
	await _seconds(1.2)
	player.global_position = Vector3(0.2, 0.0, -0.1)
	_aim(player, room.get_node("BathBucket").global_position + Vector3(0, 0.1, 0))
	player.try_interact()
	_check(not main.inventory.has("bucket") and room.get_node("BathBucket").visible and not room.bucket_in_tub, "風呂桶は調べるだけ。拾えず、元の場所にある")
	# --- 背が最大（170 cm）なら、浴槽の中からも届く
	main._on_eye_height_changed(1.7)
	feet = main._tub_feet()
	player.enter_fixed(Pose.IN_TUB, feet, main.TUB_YAW, main._tub_eye())
	await _seconds(1.0)
	_aim(player, vent_pos)
	await physics_frame
	await physics_frame
	_check(main._action_for(player.get_focused(true)) == "vent_enter", "背が最大なら浴槽の中から「E：換気口へ入る」")
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
