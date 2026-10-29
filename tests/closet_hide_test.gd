extends SceneTree
## 押入れに閉じこもる：E で入る（襖が左の仕切りをふさいでいても、自分で開けて入り、中から閉める）→ 真っ暗 → E で出る。
## 実行: Godot --headless --path . --script res://tests/closet_hide_test.gd

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
	var cl = main.room.apartment.closet
	var area: Node = cl.get_node("FusumaArea")
	player.global_position = Vector3(4.5, 0.0, 0.1)
	_aim(player, area.global_position)
	await physics_frame
	await physics_frame
	var t = player.get_focused(true)
	_check(t != null and String(t.get_meta("interact_id", "")) == "fusuma", "押入れの襖を狙える")
	_check(main._action_for(t) == "closet_enter" and main.ACTION_PROMPTS["closet_enter"] == "E：押し入れに入る", "「E：押し入れに入る」が出る")
	_check(cl.state == "closed", "はじめは、襖が両方しまっている")
	main.do_action()
	var guard := 0
	while not (main.hud.is_hiding() and player.pose == Pose.CLOSET and not cl.busy) and guard < 900:
		await physics_frame
		guard += 1
	_check(player.pose == Pose.CLOSET and main.closet_hiding, "押入れの中に座る")
	_check(cl.state == "closed" and not cl.busy, "中から襖を閉めた（両方しまる）")
	_check(main.hud.is_hiding(), "真っ暗になる（暗闇の幕と、襖の合わせ目の細い光）")
	var inside: Vector3 = player.global_position
	_check(absf(inside.x - (cl.global_position.x - cl.SLIDE_X)) < 0.05 and inside.z < cl.global_position.z + 0.3 and player.camera.position.y < 1.0,
			"左の仕切りの中で、低い目の高さ（%s、目 %.2f）" % [inside, player.camera.position.y])
	Input.action_press("move_forward")
	await create_timer(0.4).timeout
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(inside) < 0.02, "中では歩けない")
	_check(main._action_for(player.get_focused(true)) == "closet_exit" and main.ACTION_PROMPTS["closet_exit"] == "E：押し入れから出る", "「E：押し入れから出る」が出る")
	main.do_action()
	guard = 0
	while (main.closet_hiding or cl.busy or player.pose != Pose.WALK) and guard < 600:
		await physics_frame
		guard += 1
	_check(player.pose == Pose.WALK and not main.closet_hiding and not main.hud.is_hiding(), "出ると、立って歩ける。暗闇が消える")
	await create_timer(2.2).timeout
	_check(cl.state == "closed" and not cl.busy, "出たあと、襖は両方しまっておく")
	_check(player.global_position.z > cl.global_position.z + 0.3, "押入れの前に出ている（%s）" % player.global_position)
	print("CLOSET HIDE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
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
