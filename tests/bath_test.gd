extends SceneTree
## TASK-11 の自動検証：入浴剤（ユブロマン）・給湯器の浴室リモコン・トイレの操作パネル。
## 実行: Godot --headless --path . --script res://tests/bath_test.gd
## F・1〜3・E は Input.parse_input_event で実際の入力経路を通す。クリックは try_interact()。
## 水量は advance() で時間を進めて計算（実時間待ちを使わない）。色の演出は実時間で確認。

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
	var remote = room.bath_remote
	var panel = room.toilet_panel
	var toilet = room.toilet

	# ================================================================ 1：ユブロマン
	player.global_position = Vector3(0.0, 0.0, 0.3)
	var powder_node: Node3D = room.get_node("BathPowder")
	_aim(player, room.get_node("BathPowder/Visual").global_position + Vector3(0, 0.08, 0))
	player.try_interact()
	_check(main.inventory.has("bath_powder") and not powder_node.visible and main.selected_item() == "bath_powder", "棚のユブロマンを拾い、選択される")
	main._on_interact_requested(room.get_node("BathPowder/Collision"))
	_check(main.inventory.count("bath_powder") == 1, "重複して取れない")
	# 水が足りない
	player.global_position = Vector3(0.3, 0.0, -0.2)
	var tub_aim: Vector3 = tub.to_global(Vector3(0.3, 0.3, 0.375))
	_aim(player, tub_aim)
	_check(main._use_prompt(player.get_focused(true)) == "F：ユブロマンを使う", "浴槽を狙うと「F：ユブロマンを使う」")
	tub.level = 0.05
	tub.advance(0.0)
	await _key(KEY_F)
	_check(main.hud._message_label.text == main.MESSAGES["powder_need_water"] and not main.powder_used and tub.powder == 0.0,
			"水量10%%未満では「もう少し水をためてから入れよう。」、使用回数は減らない")
	# 成功：粉を入れる演出 → 約2秒でゆず色
	tub.level = 0.4
	tub.advance(0.0)
	var base_col: Color = tub._water_mat.albedo_color
	await _key(KEY_F)
	_check(main.powder_used and tub.powder_busy and main.hud._message_label.text == main.MESSAGES["powder_added"], "F で粉を入れる演出が始まる（容器は投げ込まない）")
	for i in 2:   # 連打
		await _key(KEY_F)
	_check(tub.has_node("PowderGrains") and tub.get_node("PowderGrains").get_child_count() == 10, "粉の粒が水面へ落ちる")
	await _seconds(0.8)
	_check(is_equal_approx(tub.powder, 0.4) and not tub.powder_busy, "連打しても1回分だけ溶ける（powder=%.2f）" % tub.powder)
	main._pause()
	var rv: float = tub.reveal
	await _seconds(0.4)
	_check(is_equal_approx(tub.reveal, rv) and rv < 1.0, "色が変わる途中で一時停止すると止まる（%.2f）" % rv)
	main._resume()
	await _seconds(2.2)
	var yuzu: Color = tub._water_mat.albedo_color
	_check(tub.reveal == 1.0 and yuzu.is_equal_approx(tub.YUZU_COLOR) and not yuzu.is_equal_approx(base_col), "約2秒で淡いゆず色になる")
	_check(main.item_name("bath_powder") == "ユブロマン（空）" and main.hud._slot_labels[main.inventory.find("bath_powder")].text.ends_with("ユブロマン（空）"),
			"使用後は所持品に「ユブロマン（空）」として残る")
	main.hud._message_label.text = ""
	await _key(KEY_F)
	_check(main.hud._message_label.text == main.MESSAGES["powder_empty"] and is_equal_approx(tub.powder, 0.4), "2回目は「もう空っぽだ。」")
	main.hud._message_label.text = ""
	_aim(player, tub_aim)
	player.try_interact()
	_check(main.hud._message_label.text == main.MESSAGES["bathtub_yuzu"], "浴槽を調べると「ゆず色のお湯」")
	# 給水すると薄まる
	tub.faucet.set_on(true)
	tub.advance(16.0)   # +0.4
	_check(is_equal_approx(tub.level, 0.8) and is_equal_approx(tub.concentration(), 0.5)
			and tub._water_mat.albedo_color.is_equal_approx(tub.WATER_COLOR.lerp(tub.YUZU_COLOR, 0.5)), "給水すると濃さが薄まる（0.5）")
	tub.faucet.set_on(false)
	# 給水と排水を同時に行うと、水位は流量差で下がりつつ薄まる（Codex レビュー P2 の回帰テスト）
	tub.faucet.set_on(true)
	tub.set_plug(false)
	var c_before: float = tub.concentration()
	var l_before: float = tub.level
	for i in 60:   # 1秒（1/60 秒ずつ）
		tub.advance(1.0 / 60.0)
	_check(tub.level < l_before and tub.concentration() < c_before - 0.01,
			"同時給排水中も新しい水で薄まる（水位 %.3f→%.3f、濃さ %.3f→%.3f）" % [l_before, tub.level, c_before, tub.concentration()])
	tub.faucet.set_on(false)
	tub.set_plug(true)
	tub.level = 0.8
	tub.powder = 0.4
	tub.advance(0.0)
	# 排水中は色を保ち、空で戻る
	tub.set_plug(false)
	tub.advance(10.0)
	_check(tub.level > 0.0 and is_equal_approx(tub.concentration(), 0.5), "排水中は色（濃さ）を保つ")
	tub.advance(30.0)
	_check(tub.level == 0.0 and tub.powder == 0.0 and tub.reveal == 0.0 and tub._water_mat.albedo_color.is_equal_approx(tub.WATER_COLOR),
			"完全に空になると色が戻る")
	tub.set_plug(true)
	tub.advance(0.0)

	# ================================================================ 2：浴室リモコン
	player.global_position = Vector3(0.4, 0.0, -0.3)
	_aim(player, remote.to_global(Vector3(-0.07, -0.02, 0.016)))
	var b_power = player.get_focused(true)
	_check(_id(b_power) == "remote_power" and main._prompt_for(b_power) == main.PROMPTS["remote_power"], "リモコンの「運転」を狙える")
	_check(remote.status_text() == "" and remote._display.text == "", "初期状態は運転OFF（表示なし）")
	main.hud._message_label.text = ""
	_press(main, player, remote, "remote_auto")
	_check(main.hud._message_label.text == main.MESSAGES["remote_off"] and not tub.auto_filling, "運転OFFでは「ふろ自動」は動かない")
	_press(main, player, remote, "remote_power")
	_check(remote.power and remote._display.text == "40℃" and remote.status_text() == "運転中", "運転ONで 40℃ を表示")
	# 栓が抜けていると拒否
	tub.set_plug(false)
	main.hud._message_label.text = ""
	_press(main, player, remote, "remote_auto")
	_check(main.hud._message_label.text == main.MESSAGES["remote_plug_open"] and not tub.auto_filling, "栓が抜けていると案内を出し、ふろ自動を始めない")
	tub.set_plug(true)
	_press(main, player, remote, "remote_auto")
	_check(tub.auto_filling and tub.is_filling() and not tub.faucet.is_on, "栓をして「ふろ自動」で給水が始まる（手の蛇口は動かない）")
	await _frames(3)
	_check(remote.status_text() == "お湯はり中", "表示「お湯はり中」")
	var l0: float = tub.level
	tub.advance(16.0)
	_check(absf(tub.level - l0 - 0.4) < 0.0001, "ふろ自動の給水は手の蛇口と同じ速さ（16秒で+0.4）")
	# 手の蛇口と併用しても二重に数えない
	tub.faucet.set_on(true)
	l0 = tub.level
	tub.advance(4.0)
	_check(absf(tub.level - l0 - 0.1) < 0.0001, "手の蛇口と同時でも給水は1本分（4秒で+0.1）")
	tub.faucet.set_on(false)
	tub.advance(100.0)
	_check(is_equal_approx(tub.level, tub.AUTO_LEVEL) and not tub.auto_filling and tub.auto_done, "設定水位（%.1f）で自動停止" % tub.AUTO_LEVEL)
	await _frames(3)
	_check(remote.status_text() == "お湯はり完了", "表示「お湯はり完了」")
	tub.advance(30.0)
	_check(is_equal_approx(tub.level, tub.AUTO_LEVEL), "止まったあとは水位を保つ")
	# 途中で停止
	tub.level = 0.3
	tub.advance(0.0)
	_press(main, player, remote, "remote_auto")
	tub.advance(4.0)
	_press(main, player, remote, "remote_stop")
	var lv: float = tub.level
	tub.advance(10.0)
	_check(not tub.auto_filling and is_equal_approx(tub.level, lv), "「停止」で自動給水が止まる")
	# 自動給水中に栓を抜くと止まる
	_press(main, player, remote, "remote_auto")
	tub.set_plug(false)
	_check(not tub.auto_filling, "自動給水中に栓を抜くと止まる")
	tub.set_plug(true)
	# 追い焚き
	tub.level = 0.1
	tub.advance(0.0)
	main.hud._message_label.text = ""
	_press(main, player, remote, "remote_reheat")
	_check(main.hud._message_label.text == main.MESSAGES["remote_need_water"] and not tub.reheating, "水が少ないと追い焚きできない")
	tub.level = 0.6
	tub.advance(0.0)
	_press(main, player, remote, "remote_reheat")
	await _seconds(0.3)
	_check(tub.reheating and tub._swirl.visible and remote.status_text() == "追い焚き中", "追い焚き：作動表示と水面の演出（循環口の渦）")
	# ゆらぎの1周期（約0.7秒）のあいだ水面の高さを集め、幅を見る（2点だけだと同じ値に当たることがある）
	var y_min := 10.0
	var y_max := -10.0
	var t_end := Time.get_ticks_msec() + 800
	while Time.get_ticks_msec() < t_end:
		await process_frame
		y_min = minf(y_min, tub._water.position.y)
		y_max = maxf(y_max, tub._water.position.y)
	_check(y_max - y_min > 0.003, "追い焚き中は水面がゆらぐ（幅 %.4f m）" % (y_max - y_min))
	main._pause()
	var tl: float = tub._reheat_left
	await _seconds(0.3)
	_check(is_equal_approx(tub._reheat_left, tl), "一時停止中は追い焚きの時間も止まる")
	main._resume()
	tub.advance(10.0)
	_check(not tub.reheating and not tub._swirl.visible, "しばらくすると追い焚きは終わる")
	_press(main, player, remote, "remote_auto")
	_press(main, player, remote, "remote_power")
	_check(not remote.power and not tub.auto_filling and not tub.reheating, "運転OFFで自動運転も止まる")
	# 浴槽の中からも押せる
	player.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(player, tub.to_global(Vector3(0.3, 0.3, 0.375)))
	await _key(KEY_E)
	await _seconds(0.8)
	_aim(player, remote.to_global(Vector3(-0.07, -0.02, 0.016)))
	_check(player.pose == Pose.IN_TUB and _id(player.get_focused(true)) == "remote_power", "浴槽の中からリモコンを押せる")
	await _key(KEY_E)
	await _seconds(0.8)

	# ================================================================ 3：トイレの操作パネル
	player.global_position = Vector3(0.0, 0.0, 0.35)
	var rear_pt: Vector3 = panel.to_global(Vector3(-0.044, 0.006, 0.0))
	_aim(player, rear_pt)
	main.hud._message_label.text = ""
	player.try_interact()
	_check(main.hud._message_label.text == main.MESSAGES["washlet_need_sit"] and panel.mode == "", "立ったままではパネルは作動しない")
	toilet.toggle_lid()
	await _seconds(0.6)
	_aim(player, toilet.seat_pivot.to_global(Vector3(0.335, 0.012, 0.0)))
	await _key(KEY_E)
	await _seconds(0.8)
	_check(player.pose == Pose.SEATED, "座る")
	# 着座視点からパネルが見え、ボタンを狙える
	var seen := _id(_aim_get(player, rear_pt))
	_check(seen == "washlet_rear", "座ったまま左下のパネルの「おしり」を狙える")
	var cam_to_panel: Vector3 = (panel.global_position - player.camera.global_position)
	var left: Vector3 = -(Basis(Vector3.UP, main.SEAT_YAW).x)   # 座った向き（+x）から見た左
	var flat := Vector3(cam_to_panel.x, 0.0, cam_to_panel.z).normalized()
	_check(cam_to_panel.y < 0.0 and flat.dot(left) > 0.7, "パネルは座った本人の左下にある")
	player.try_interact()
	_check(panel.mode == "rear" and panel._status.text == "おしり 作動中" and panel._lamps[0].get_theme_stylebox("panel").bg_color != Color(0.3, 0.3, 0.3), "「おしり」でランプと作動表示")
	_aim(player, panel.to_global(Vector3(0.0, 0.006, 0.0)))
	player.try_interact()
	_check(panel.mode == "bidet", "「ビデ」へ切り替え")
	_aim(player, panel.to_global(Vector3(0.044, 0.006, 0.0)))
	player.try_interact()
	_check(panel.mode == "", "「止」で止まる")
	_aim(player, rear_pt)
	player.try_interact()
	# レバーは別に使える
	_aim(player, toilet.lever_pivot.to_global(Vector3(0.025, 0, 0.03)))
	player.try_interact()
	_check(toilet.flushing and panel.mode == "rear", "座ったままタンクのレバーで流せる（パネルとは別）")
	# 立つと自動停止
	await _key(KEY_E)
	_check(panel.mode == "", "立つと操作パネルは止まる")
	await _seconds(0.8)
	_check(player.pose == Pose.WALK, "立った")
	# パネルが壁・便器を突き抜けない
	var pb := _aabb(panel)
	var bowl := AABB(Vector3(-0.7, 0.0, -0.18), Vector3(0.4, 0.4, 0.36))
	_check(pb.position.z > room.bathtub.to_global(Vector3(0, 0, room.bathtub.HALF.z)).z and pb.end.z <= -0.179 and not pb.grow(-0.002).intersects(bowl),
			"パネルは便器と浴槽の間に収まり、どちらにも食い込まない（z %.3f〜%.3f）" % [pb.position.z, pb.end.z])
	# 開いた蓋・便座とぶつからない
	toilet.toggle_seat()
	await _seconds(0.6)
	_check(not pb.intersects(_aabb(toilet.lid_pivot)) and not pb.intersects(_aabb(toilet.seat_pivot)), "開いた蓋・上げた便座とぶつからない")

	# ================================================================ 再プレイ
	main._retry()
	await _frames(10)
	var m2 := current_scene
	var r2 = m2.room
	_check(not r2.bath_powder_taken and r2.get_node("BathPowder").visible and not m2.powder_used and r2.bathtub.powder == 0.0
			and r2.bathtub._water_mat.albedo_color.is_equal_approx(r2.bathtub.WATER_COLOR), "再プレイで容器は棚、未使用、水は通常色")
	_check(not r2.bath_remote.power and not r2.bathtub.auto_filling and not r2.bathtub.reheating and r2.toilet_panel.mode == "",
			"再プレイでリモコンは運転OFF、パネルは停止")

	print("BATH TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## リモコンのボタンを照準で押す（ボタンの判定の中心を狙ってクリック）。
func _press(main: Node, player: Node3D, remote: Node3D, id: String) -> void:
	var area: Area3D = remote.get_node("Button%d" % remote.BUTTONS.find(id))
	var cs: CollisionShape3D = area.get_child(0)
	_aim(player, cs.global_position)
	var f = player.get_focused(true)
	if _id(f) != id:
		print("    （%s を狙えなかった：%s）" % [id, _id(f)])
	player.try_interact()


func _aim_get(player: Node3D, p: Vector3) -> Object:
	_aim(player, p)
	return player.get_focused(true)


func _aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


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
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-85.0), deg_to_rad(85.0))
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
