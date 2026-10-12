extends SceneTree
## TASK-13：鏡の留め具をドライバーで外す。
## 実行: Godot --headless --path . --script res://tests/mirror_test.gd
## F・1〜3 は Input.parse_input_event で実際の入力経路を通す。クリックは try_interact()。

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
	var cab = room.mirror_cabinet
	var lock: Node3D = cab.door_pivot.get_node("Lock")
	var lock_pt: Vector3 = lock.global_position + Vector3(-0.006, 0, 0)
	var door_pt: Vector3 = cab.door_pivot.to_global(Vector3(-0.02, 0.25, 0.22))
	var stand := Vector3(0.25, 0.0, 0.1)

	# 施錠中：クリックでは開かない
	player.global_position = stand
	_aim(player, lock_pt)
	var hit = player.get_focused(true)
	_check(_id(hit) == "mirror_lock", "右端の留め具を狙える（扉より手前の判定）")
	main.hud._message_label.text = ""
	player.try_interact()
	await _seconds(0.6)
	_check(cab.locked and not cab.is_open and main.hud._message_label.text == "鏡の扉は開かない。右端に溝付きの留め具がある。",
			"施錠中にクリック：「右端に溝付きの留め具がある」、開かない")

	# 未取得：F を押しても何も選ばれていない
	await _key(KEY_F)
	_check(cab.locked, "持ち物なしで F：解錠しない")

	# 別アイテム（予備ロール）では解錠しない
	player.global_position = Vector3(-0.4, 0.0, 0.6)
	_aim(player, room.supplies.get_node("SupplyShelf/SpareRoll").global_position + Vector3(0, 0.06, 0))
	player.try_interact()
	player.global_position = stand
	_aim(player, lock_pt)
	_check(main.selected_item() == "spare_roll" and main._use_prompt(player.get_focused(true)) == "", "予備ロールを選んでいるときは留め具に F の案内が出ない")
	await _key(KEY_F)
	_check(cab.locked and main.hud._message_label.text == main.MESSAGES["cannot_use"] and main.inventory.has("spare_roll"),
			"予備ロールで F：「ここでは使えない」、解錠しない、消費しない")

	# ドライバーは鏡を開ける前に手に入る（洗面台の下の床）
	player.global_position = Vector3(0.0, 0.0, 0.3)
	_aim(player, room.driver_node.global_position + Vector3(0, 0.02, 0))
	player.try_interact()
	_check(main.inventory.has("driver") and cab.locked, "鏡が施錠されたままでも、洗面台の下のドライバーを拾える")

	# ドライバーを選んで留め具を狙う
	player.global_position = stand
	_aim(player, lock_pt)
	await _key([KEY_1, KEY_2, KEY_3][main.inventory.find("driver")])   # ドライバーの枠の番号キー
	_check(main.selected_item() == "driver" and main._use_prompt(player.get_focused(true)) == "F：ドライバーで留め具を外す",
			"ドライバーを選んで右端を狙うと「F：ドライバーで留め具を外す」")
	# 連打
	for i in 3:
		await _key(KEY_F)
	_check(not cab.locked and main.hud._message_label.text == main.MESSAGES["cabinet_unlocked"] and main.inventory.has("driver"),
			"F で解錠「留め具を外した。鏡の扉が開けられる。」。ドライバーは消費しない")
	_check(not cab.is_open, "解錠しても扉は勝手に開かない（連打の F で開閉されない）")
	await _seconds(0.5)
	_check(is_equal_approx(lock.rotation.x, deg_to_rad(90.0)), "留め具の溝が縦に回る")
	main.hud._message_label.text = ""
	await _key(KEY_F)
	_check(main.hud._message_label.text == main.MESSAGES["cannot_use"], "解錠後にもう一度 F：「ここでは使えない」")

	# 解錠後は従来のクリックで開閉
	_aim(player, door_pt)
	_check(main._prompt_for(player.get_focused(true)) == main.PROMPTS["cabinet_open"], "解錠後に鏡を狙うと「鏡の扉を開ける」")
	player.try_interact()
	await _seconds(0.2)
	main._pause()
	var r: float = cab.door_pivot.rotation.y
	await _seconds(0.3)
	_check(is_equal_approx(cab.door_pivot.rotation.y, r) and cab.busy, "開く途中で一時停止すると止まる")
	main._resume()
	await _seconds(0.6)
	_check(cab.is_open, "開く")
	_aim(player, cab.get_node("Items/Toner").global_position + Vector3(0, 0.06, 0))
	main.hud._message_label.text = ""
	player.try_interact()
	_check(main.hud._message_label.text == main.MESSAGES["toner"], "中の化粧水を調べられる")
	_aim(player, cab.door_pivot.to_global(Vector3(-0.02, 0.25, 0.22)))   # 開いた扉の位置
	player.try_interact()
	await _seconds(0.6)
	_check(not cab.is_open, "閉じる")

	# 扉を狙って使った場合も解錠できる（再プレイ後に確認）
	main._retry()
	for i in 10:
		await process_frame
	var m2 := current_scene
	var c2 = m2.room.mirror_cabinet
	_check(c2.locked and not c2.is_open and is_zero_approx(c2.door_pivot.get_node("Lock").rotation.x), "再プレイで施錠に戻る")
	var p2 = m2.player
	p2.global_position = Vector3(0.0, 0.0, 0.3)
	_aim(p2, m2.room.driver_node.global_position + Vector3(0, 0.02, 0))
	p2.try_interact()
	p2.global_position = stand
	_aim(p2, c2.door_pivot.to_global(Vector3(-0.02, 0.25, 0.22)))
	_check(m2._use_prompt(p2.get_focused(true)) == "F：ドライバーで留め具を外す", "扉を狙っても「F：ドライバーで留め具を外す」")
	await _key(KEY_F)
	_check(not c2.locked, "扉を狙って F でも解錠できる")

	print("MIRROR TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _key(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


func _id(target: Object) -> String:
	if target == null:
		return ""
	return String(target.get_meta("interact_id", ""))


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


func _seconds(t: float) -> void:
	await create_timer(t).timeout
