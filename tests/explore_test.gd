extends SceneTree
## TASK-09 の自動検証：隠し場所4か所の見え方、タオル、持ち物（拾う・選ぶ・使う・拡大）、ペーパーホルダーの交換、初期化。
## 実行: Godot --headless --path . --script res://tests/explore_test.gd
## キー（1/2・F・Q・ホイール）は Input.parse_input_event で実際の入力経路を通す。
## クリックは try_interact()（ヘッドレスではマウスを捕捉できないため）。実キーボード・マウスの確認の代わりにはならない。

const Pose := preload("res://scripts/player.gd").Pose

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(10)
	var main := current_scene
	var player = main.player
	var room = main.room
	var tub = room.bathtub
	var sup = room.supplies
	var towel = room.towel
	var toilet = room.toilet

	var tub_note: Vector3 = tub.to_global(tub.NOTE_POS - Vector3(0, 0, 0.002))
	var shelf_note: Vector3 = sup.SHELF_NOTE_POS - Vector3(0, 0.002, 0)
	var tank_note: Vector3 = sup.TANK_NOTE_POS + Vector3(0.002, 0, 0)
	var scratch: Vector3 = towel.to_global(Vector3(0.002, -0.27, -0.09))

	# ================================================================ 隠し場所：通路のどこに立っても見えない
	var spots := [["tub_note", tub_note], ["shelf_note", shelf_note], ["tank_note", tank_note], ["towel_scratch", scratch]]
	var aisle := []
	for x in [-0.2, 0.0, 0.2, 0.4]:
		for z in [-0.15, 0.1, 0.35, 0.6, 0.9]:
			if player.is_space_free(Vector3(x, 0, z), player.BODY_HEIGHT):
				aisle.append(Vector3(x, 0, z))
	for sp in spots:
		var seen := []
		for pos in aisle:
			player.global_position = pos
			_aim(player, sp[1])
			if _id(player.get_focused(true)) == sp[0]:
				seen.append(pos)
		_check(seen.is_empty(), "%s：通路の立ち位置 %d か所のどこからも見えない%s" % [sp[0], aisle.size(), "" if seen.is_empty() else "（見えた：%s）" % str(seen)])

	# ================================================================ 1：浴槽内の紙
	_check(tub_note.y - tub.NOTE_SIZE.y * 0.5 > tub.to_global(Vector3(0, tub.WATER_MAX_Y, 0)).y, "浴槽の紙は満水の水面より上")
	player.global_position = Vector3(0.3, 0.0, -0.2)
	player.toggle_crouch()
	await _seconds(0.8)
	_aim(player, tub_note)
	_check(_id(player.get_focused(true)) != "tub_note", "通路でしゃがんでも、縁に遮られて浴槽の紙は見えない")
	player.toggle_crouch()
	await _seconds(0.8)
	_aim(player, tub.to_global(Vector3(0.3, 0.3, 0.375)))
	main.do_action()
	await _seconds(0.8)
	tub.level = 1.0
	tub.advance(0.0)
	main.hud._message_label.text = ""
	_aim(player, tub_note)
	player.try_interact()
	_check(player.pose == Pose.IN_TUB and main.hud._message_label.text == main.MESSAGES["tub_note"], "浴槽に入ると（満水でも）紙を読める")
	main.do_action()
	await _seconds(0.8)
	tub.level = 0.0
	tub.advance(0.0)

	# ================================================================ 3：棚の裏の紙（座ると見える）
	toilet.toggle_lid()
	await _seconds(0.6)
	player.global_position = Vector3(0.0, 0.0, 0.35)
	_aim(player, toilet.seat_pivot.to_global(Vector3(0.335, 0.012, 0.0)))
	main.do_action()
	await _seconds(0.8)
	main.hud._message_label.text = ""
	_aim(player, shelf_note)
	player.try_interact()
	_check(player.pose == Pose.SEATED and main.hud._message_label.text == main.MESSAGES["shelf_note"], "座って見上げると棚の裏の紙を読める")
	main.do_action()
	await _seconds(0.8)

	# ================================================================ 4：タンクの下の紙（しゃがむと見える）
	# 便器の蓋が開いていると、立った蓋が視線をさえぎる（入口寄りからだけ見える）
	player.global_position = Vector3(-0.25, 0.0, 0.8)
	player.toggle_crouch()
	await _seconds(0.8)
	_aim(player, tank_note)
	_check(_id(player.get_focused(true)) == "tank_note", "便器の蓋が開いていても、しゃがんで入口寄りから覗けばタンクの下の紙が見える")
	toilet.toggle_lid()
	await _seconds(0.6)
	player.global_position = Vector3(-0.05, 0.0, 0.45)
	await _seconds(0.2)
	main.hud._message_label.text = ""
	_aim(player, tank_note)
	player.try_interact()
	_check(player.pose == Pose.CROUCH and main.hud._message_label.text == main.MESSAGES["tank_note"], "蓋を閉じてしゃがみ、通路から覗くとタンクの下の紙を読める")
	player.toggle_crouch()
	await _seconds(0.8)

	# ================================================================ 2：タオルの裏の傷
	player.global_position = Vector3(0.0, 0.0, 0.7)
	_aim(player, scratch)
	var hit = player.get_focused(true)
	_check(_id(hit) == "towel" and main._prompt_for(hit) == main.PROMPTS["towel_slide"], "タオル越しには傷を調べられず、タオルに「ずらす」と出る")
	for i in 4:
		player.try_interact()
	_check(towel.slid and towel.busy, "タオルの連打は1回だけ受け付ける")
	await _seconds(0.15)
	main._pause()
	var z_paused: float = towel.cloth.position.z
	await _seconds(0.3)
	_check(is_equal_approx(towel.cloth.position.z, z_paused) and towel.busy, "タオルを動かす途中で一時停止すると止まる")
	main._resume()
	await _seconds(0.6)
	main.hud._message_label.text = ""
	_aim(player, scratch)
	player.try_interact()
	_check(not towel.busy and main.hud._message_label.text == main.MESSAGES["towel_scratch"], "ずらすと裏の傷を調べられる")
	_check(not main.inventory.has("towel"), "タオルは所持品にならない")
	_aim(player, towel.to_global(Vector3(0.08, -0.2, 0.12)))
	_check(main._prompt_for(player.get_focused(true)) == main.PROMPTS["towel_back"], "ずらしたタオルを狙うと「戻す」")
	player.try_interact()
	_aim(player, scratch)
	_check(_id(player.get_focused(true)) == "towel", "戻し始めた時点で傷はタオルに隠れる")
	await _seconds(0.6)

	# ================================================================ 持ち物：拾う・選ぶ
	_check(main.inventory.is_empty() and main.selected == -1, "初期状態：所持品なし")
	player.global_position = Vector3(0.0, 0.0, 0.3)
	_aim(player, room.driver_node.global_position + Vector3(0, 0.02, 0))
	player.try_interact()
	player.global_position = Vector3(-0.4, 0.0, 0.6)
	var roll_node: Node3D = sup.get_node("SupplyShelf/SpareRoll")
	var roll_area: Area3D = roll_node.get_node("SpareRollArea")
	_aim(player, roll_node.global_position + Vector3(0, 0.06, 0))
	_check(main._prompt_for(player.get_focused(true)) == main.PROMPT_PICKUP, "棚の予備ロールに「拾う」")
	player.try_interact()
	_check(main.inventory == ["driver", "spare_roll"] and main.selected == 1, "ドライバーと予備ロールを拾う（最後に拾った物が選択される）")
	main._on_interact_requested(roll_area)
	_check(main.inventory.size() == 2 and _id(player.get_focused(true)) != "spare_roll", "同じ物は重複して取れず、棚の予備ロールは照準から消える")
	await _key(KEY_1)
	_check(main.selected == 0 and main.selected_item() == "driver", "1 キーでドライバーを選ぶ")
	_check(_slot_selected(main.hud, 0) and not _slot_selected(main.hud, 1), "選択中の枠が強調され、名前が出る（%s）" % main.hud._slot_labels[0].text)
	await _key(KEY_2)
	_check(main.selected_item() == "spare_roll", "2 キーで予備ロールを選ぶ")
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_check(main.selected_item() == "driver", "ホイールで選択が切り替わる（下：次へ、端で一周）")
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	_check(main.selected_item() == "spare_roll", "ホイール上で前へ")

	# ================================================================ 拡大表示
	await _key(KEY_Q)
	_check(main.hud.is_zoom_open() and main.hud._zoom_name.text == "予備ロール" and main.hud._zoom_pivot.get_child_count() == 1, "Q で選んだ持ち物を拡大表示（3Dモデル付き）")
	await _key(KEY_1)
	_check(main.hud.is_zoom_open() and main.hud._zoom_name.text == "ドライバー", "拡大表示中に選択を変えると表示も変わる")
	await _key(KEY_Q)
	_check(not main.hud.is_zoom_open(), "もう一度 Q で閉じる")
	await _key(KEY_Q)
	main._pause()
	_check(not main.hud.is_zoom_open(), "一時停止すると拡大表示は閉じる")
	main._resume()

	# ================================================================ ペーパーホルダー：カバーと交換
	player.global_position = Vector3(-0.2, 0.0, 0.75)
	var holder_target: Vector3 = sup.get_node("PaperHolder").global_position + Vector3(0.08, -0.02, 0.0)
	_aim(player, holder_target)
	await _key(KEY_2)
	_check(main._use_prompt(player.get_focused(true)) == "F：予備ロールを使う", "予備ロールを選んでホルダーを狙うと「F：予備ロールを使う」")
	await _key(KEY_F)
	_check(main.hud._message_label.text == main.MESSAGES["cover_closed"] and main.inventory.has("spare_roll") and not sup.has_paper,
			"カバーが閉じていると「先にカバーを開けよう。」。予備ロールは消費しない")
	await _key(KEY_1)
	await _key(KEY_F)
	_check(main.hud._message_label.text == main.MESSAGES["cannot_use"] and main.inventory.has("driver"), "ホルダーにドライバーを使うと「ここでは使えない」。消費しない")
	var cover_target: Vector3 = sup.cover_pivot.to_global(Vector3(0.05, 0.003, 0.0))
	_aim(player, cover_target)
	_check(main._prompt_for(player.get_focused(true)) == main.PROMPTS["cover_open"], "カバーを狙うと「カバーを開ける」")
	player.try_interact()
	await _seconds(0.1)
	main._pause()
	var cov_paused: float = sup.cover_pivot.rotation.z
	await _seconds(0.3)
	_check(is_equal_approx(sup.cover_pivot.rotation.z, cov_paused) and sup.holder_busy, "カバーの開閉の途中で一時停止すると止まる")
	main._resume()
	await _seconds(0.4)
	_check(sup.cover_open and is_equal_approx(rad_to_deg(sup.cover_pivot.rotation.z), sup.COVER_OPEN_DEG), "カバーが開く")
	await _key(KEY_2)
	_aim(player, holder_target)
	main._pause()
	await _key(KEY_F)
	_check(main.inventory.has("spare_roll") and not sup.has_paper, "一時停止中は F が効かない")
	main._resume()
	for i in 3:   # 連打
		await _key(KEY_F)
	_check(not main.inventory.has("spare_roll") and sup.has_paper and sup.holder_busy and main.inventory == ["driver"],
			"F で交換が始まり、予備ロールを1回だけ消費する（連打しても二重消費なし）")
	await _seconds(0.8)
	var roll_vis: Node3D = sup.get_node("PaperHolder/Roll")
	_check(roll_vis.visible and roll_vis.scale.is_equal_approx(Vector3.ONE) and not sup.get_node("PaperHolder/CoreOnly").visible
			and sup.get_node("CoreDish/Core").visible, "新しいロールが付き、外した芯は小皿に置かれる")
	main.hud._message_label.text = ""
	_aim(player, holder_target)
	player.try_interact()
	_check(main.hud._message_label.text == main.MESSAGES["paper_holder"], "交換後のホルダーは「いつものトイレットペーパー」")
	await _key(KEY_F)
	_check(main.inventory == ["driver"], "交換後に F を押しても持ち物は減らない")

	# ================================================================ 移動演出中は使えない
	player.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(player, tub.to_global(Vector3(0.3, 0.3, 0.375)))
	main.do_action()
	main.hud._message_label.text = ""
	await _key(KEY_F)
	_check(player.pose == Pose.TRANSITION and main.hud._message_label.text == "", "移動演出中は F が効かない")
	await _seconds(0.8)
	main.do_action()
	await _seconds(0.8)

	# ================================================================ 再プレイ
	towel.toggle()
	await _seconds(0.6)
	main._retry()
	await _frames(10)
	var m2 := current_scene
	var s2 = m2.room.supplies
	_check(m2 != main and m2.inventory.is_empty() and m2.selected == -1 and not m2.has_driver, "再プレイで所持品なし")
	_check(not s2.spare_roll_taken and s2.get_node("SupplyShelf/SpareRoll").visible, "予備ロールは棚に戻る")
	_check(not s2.has_paper and not s2.cover_open and s2.get_node("PaperHolder/CoreOnly").visible
			and not s2.get_node("PaperHolder/Roll").visible and not s2.get_node("CoreDish/Core").visible,
			"ホルダーは芯だけ・カバー閉、小皿は空に戻る")
	_check(not m2.room.towel.slid and is_zero_approx(m2.room.towel.cloth.position.z), "タオルは元の位置に戻る")

	print("EXPLORE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _slot_selected(hud: Node, i: int) -> bool:
	var style := hud._slot_panels[i].get_theme_stylebox("panel") as StyleBoxFlat
	return style.border_width_left > 0


func _key(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


func _wheel(button: MouseButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(t: float) -> void:
	await create_timer(t).timeout
