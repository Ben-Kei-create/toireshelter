extends SceneTree
## TASK-08 の自動検証：姿勢（しゃがむ・座る・浴槽）、トイレを流す、埋め込みの鏡裏収納、照明と床。
## 実行: Godot --headless --path . --script res://tests/pose_test.gd
## 移動はキー入力（Input.action_press）で実際に歩かせて確かめる。実キーボード・マウスの操作確認の代わりにはならない。

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
	var toilet = room.toilet

	# ================================================================ しゃがむ
	player.global_position = Vector3(0.0, 0.0, 0.5)
	await _physics(10)
	var feet_y: float = player.global_position.y
	var walk_dist := await _walk(player, 0.5)
	_check(player.toggle_crouch() and player.pose == Pose.CROUCH, "C でしゃがむ")
	await _seconds(0.8)
	var cap: CapsuleShape3D = player._shape.shape
	_check(is_equal_approx(cap.height, player.CROUCH_BODY_HEIGHT) and is_equal_approx(player._shape.position.y, player.CROUCH_BODY_HEIGHT * 0.5)
			and absf(player.camera.position.y - player.CROUCH_EYE_HEIGHT) < 0.01,
			"しゃがむと体の高さ %.2fm・目の高さ %.2fm になる" % [cap.height, player.camera.position.y])
	_check(absf(player.global_position.y - feet_y) < 0.01, "しゃがんでも足元の高さは変わらず、床に沈まない（%.3f → %.3f）" % [feet_y, player.global_position.y])
	var crouch_dist := await _walk(player, 0.5)
	_check(crouch_dist < walk_dist * 0.6 and crouch_dist > 0.1, "しゃがむと移動が遅い（0.5秒で %.2fm → %.2fm）" % [walk_dist, crouch_dist])

	# 実際のキー入力経路：C の押下・解放を2回送って WALK → CROUCH → WALK
	player.toggle_crouch()   # いったん立つ
	await _seconds(0.6)
	_check(player.pose == Pose.WALK, "（準備）立っている")
	await _press_key(KEY_C)
	_check(player.pose == Pose.CROUCH, "C キーの押下・解放1回目でしゃがむ")
	await _seconds(0.6)
	await _press_key(KEY_C)
	_check(player.pose == Pose.WALK and is_equal_approx(cap.height, player.BODY_HEIGHT), "C キーの押下・解放2回目で立つ")
	await _seconds(0.6)
	await _press_key(KEY_C)
	_check(player.pose == Pose.CROUCH, "（準備）もう一度しゃがむ")
	await _seconds(0.6)

	# 目の高さは滑らかに変わる（途中の高さを通る）
	player.toggle_crouch()
	await _physics(2)
	var mid_eye: float = player.camera.position.y
	_check(mid_eye > player.CROUCH_EYE_HEIGHT + 0.02 and mid_eye < player.EYE_HEIGHT - 0.02, "立つときの目の高さは滑らかに変わる（途中 %.2fm）" % mid_eye)
	await _seconds(0.8)

	# 頭上チェック：しゃがんで洗面台の下へ入ると立てない
	player.toggle_crouch()
	await _physics(3)
	var under_sink := Vector3(0.64, 0.0, 0.1)
	_check(player.is_space_free(under_sink, player.CROUCH_BODY_HEIGHT) and not player.is_space_free(under_sink, player.BODY_HEIGHT),
			"洗面台の下は、しゃがんだ体は入り、立った体は入らない")
	player.global_position = under_sink
	await _physics(5)
	main.hud._message_label.text = ""
	await _press_key(KEY_C)
	_check(player.pose == Pose.CROUCH and is_equal_approx(cap.height, player.CROUCH_BODY_HEIGHT)
			and main.hud._message_label.text == main.MESSAGES["no_headroom"],
			"洗面台の下では立ち上がらず、「頭上が狭い」と表示")
	player.global_position = Vector3(0.0, 0.0, 0.5)
	await _physics(5)
	_check(player.toggle_crouch() and player.pose == Pose.WALK and is_equal_approx(cap.height, player.BODY_HEIGHT), "広い場所では立てる")
	await _seconds(0.6)

	# ================================================================ 便器に座る
	player.global_position = Vector3(0.0, 0.0, 0.35)
	_aim(player, Vector3(-0.5, 0.42, 0.0))
	_check(main._action_for(player.get_focused(true)) == "", "蓋が閉じていると「E：座る」は出ない")
	toilet.toggle_lid()
	await _seconds(0.6)
	_aim(player, toilet.seat_pivot.to_global(Vector3(0.335, 0.012, 0.0)))
	var seat_hit = player.get_focused(true)
	_check(main._action_for(seat_hit) == "sit" and main.ACTION_PROMPTS["sit"] in _prompt_text(main), "蓋が開き便座が下りていれば「E：座る」")
	toilet.toggle_seat()
	await _seconds(0.6)
	_check(main._action_for(player.get_focused(true)) != "sit", "便座が上がっていると座れない")
	toilet.toggle_seat()
	await _seconds(0.6)

	main.do_action()
	_check(player.pose == Pose.TRANSITION and toilet.occupied, "座る移動演出が始まる")
	await _seconds(0.2)
	main._pause()
	var paused_pos: Vector3 = player.global_position
	await _seconds(0.3)
	_check(player.global_position.is_equal_approx(paused_pos) and player.pose == Pose.TRANSITION, "移動演出の途中で一時停止すると止まる")
	main._resume()
	await _seconds(0.7)
	_check(player.pose == Pose.SEATED and player.global_position.distance_to(main.SEAT_FEET) < 0.01
			and absf(player.camera.position.y - main.SEAT_EYE) < 0.01 and player._shape.disabled,
			"便器に座る（足元 %s、目の高さ %.2fm）" % [player.global_position, player.camera.position.y])
	var seated_at: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _seconds(0.3)
	Input.action_release("move_forward")
	player.toggle_crouch()
	_check(player.global_position.is_equal_approx(seated_at) and player.pose == Pose.SEATED, "座っている間は歩けず、しゃがめない")
	var lid_before: bool = toilet.lid_open
	toilet.interact("toilet_lid")
	toilet.interact("toilet_seat")
	await _seconds(0.5)
	_check(toilet.lid_open == lid_before and not toilet.seat_up and toilet.get_prompt("toilet_lid") == "", "座っている間は蓋と便座を開閉できない")
	main.hud._message_label.text = ""
	_aim(player, room.get_node("Supplies/PaperHolder").global_position + Vector3(0.12, -0.08, 0.0))   # ロールの手前下（レバーの陰にならない所）
	player.try_interact()
	_check(main.hud._message_label.text == main.MESSAGES["paper_holder_empty"], "座ったまま見回してペーパーホルダーを調べられる")
	_aim(player, toilet.lever_pivot.to_global(Vector3(0.025, 0, 0.03)))
	var lever_hit = player.get_focused(true)
	_check(_id(lever_hit) == "flush_lever" and main._prompt_for(lever_hit) == main.PROMPTS["flush"], "座ったままレバーに照準が届く「水を流す」")
	_check(main._action_for(null) == "stand_up" and main.ACTION_PROMPTS["stand_up"] in _prompt_text(main), "座っている間は「E：立つ」")
	_check(not player.leave_fixed([Vector3(-0.85, 0.0, 0.0)]) and player.pose == Pose.SEATED, "戻る先がふさがっていれば立たない")
	main.do_action()
	await _seconds(0.8)
	_check(player.pose == Pose.WALK and player.global_position.distance_to(main.SEAT_EXITS[0]) < 0.02 and not player._shape.disabled
			and not toilet.occupied and absf(player.camera.position.y - player.EYE_HEIGHT) < 0.01,
			"E で通路側（%s）へ立って戻る" % player.global_position)
	await _physics(10)
	_check(absf(player.global_position.y) < 0.02 and player.is_space_free(player.global_position, player.BODY_HEIGHT),
			"戻った位置は空いていて、床に立っている")

	# ================================================================ 浴槽に入る
	var tub = room.bathtub
	player.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(player, tub.to_global(Vector3(0.3, 0.3, 0.375)))   # 手前の縁
	_check(main._action_for(player.get_focused(true)) == "tub_enter", "浴槽の手前で「E：浴槽に入る」")
	main.do_action()
	await _seconds(0.8)
	var cam: Vector3 = player.camera.global_position
	var tub_local: Vector3 = tub.to_local(cam)
	_check(player.pose == Pose.IN_TUB and player._shape.disabled
			and absf(tub_local.x) < tub.HALF.x - tub.WALL - 0.1 and absf(tub_local.z) < tub.HALF.z - tub.WALL - 0.1
			and cam.y > tub.WATER_MAX_Y + 0.2,
			"浴槽の中に入る（目の位置 %s。内壁から10cm以上、満水の水面より20cm以上上）" % cam)
	Input.action_press("move_forward")
	await _seconds(0.3)
	Input.action_release("move_forward")
	_check(player.pose == Pose.IN_TUB and player.camera.global_position.is_equal_approx(cam), "浴槽の中では歩けない")
	var plug_pos: Vector3 = tub.to_global(tub.DRAIN_POS + Vector3(0, 0.012, 0))
	_aim(player, plug_pos)
	var ph = player.get_focused(true)
	_check(_id(ph) == "bath_plug", "浴槽の中から栓を狙える（%.2fm）" % cam.distance_to(plug_pos))
	_aim(player, tub.faucet.to_global(Vector3(0, -0.03, 0.09)))
	_check(_id(player.get_focused(true)) == "bath_faucet", "浴槽の中から蛇口を操作できる")
	_aim(player, tub.to_global(Vector3(0.0, 0.3, tub.HALF.z - tub.WALL)))   # 手前の内壁（通路からは見えにくい面）
	_check(player.ray.is_colliding() and tub.is_ancestor_of(player.ray.get_collider()), "浴槽の中から手前の内壁が見える")
	tub.level = 1.0
	tub.advance(0.0)
	_check(player.camera.global_position.y > tub.water_y() + 0.2, "満水でも目は水面より上")
	_check(main._action_for(null) == "tub_exit", "浴槽の中では「E：浴槽から出る」")
	main.do_action()
	await _seconds(0.8)
	_check(player.pose == Pose.WALK and player.global_position.distance_to(main.TUB_EXITS[0]) < 0.02 and not player._shape.disabled,
			"E で通路側（%s）へ出る" % player.global_position)
	tub.level = 0.0
	tub.advance(0.0)

	# ================================================================ トイレを流す
	toilet.toggle_tank()
	await _seconds(1.6)
	player.global_position = Vector3(0.0, 0.0, 0.35)
	_aim(player, toilet.lever_pivot.to_global(Vector3(0.025, 0, 0.03)))
	var lv_hit = player.get_focused(true)
	_check(_id(lv_hit) == "flush_lever" and main._prompt_for(lv_hit) == main.PROMPTS["flush"], "レバーを狙うと「水を流す」")
	for i in 5:
		player.try_interact()
	_check(toilet.flushing and main._prompt_for(lv_hit) == "", "流している間の連打は1回だけ受け付け、案内なし")
	var tw: Node3D = toilet.tank_water
	var lowest := 1.0
	var bowl_highest := 0.0
	var swirl_seen := false
	var lever_hit_lid := false
	var paused_once := false
	var t_end := Time.get_ticks_msec() + 9000   # ヘッドレスはフレームが速いので、フレーム数ではなく時間で区切る
	while Time.get_ticks_msec() < t_end:
		await process_frame
		lowest = minf(lowest, tw.position.y)
		bowl_highest = maxf(bowl_highest, toilet.bowl_water.position.y)
		swirl_seen = swirl_seen or toilet.bowl_swirl.visible
		if _aabb(toilet.lever_pivot).intersects(_aabb(toilet.lid_pivot)):
			lever_hit_lid = true
		if not paused_once and tw.position.y < toilet.TANK_WATER_Y - 0.1:
			paused_once = true
			main._pause()
			var y_paused: float = tw.position.y
			await _seconds(0.3)
			_check(is_equal_approx(tw.position.y, y_paused), "流している途中で一時停止すると水位が止まる")
			main._resume()
		if not toilet.flushing:
			break
	_check(lowest < toilet.TANK_WATER_LOW + 0.01 and bowl_highest > toilet.BOWL_WATER_Y + 0.01 and swirl_seen,
			"タンクの水位が下がり（最低 %.2f）、便器の水が渦を巻いて動く" % lowest)
	_check(not toilet.flushing and is_equal_approx(tw.position.y, toilet.TANK_WATER_Y)
			and is_equal_approx(toilet.bowl_water.position.y, toilet.BOWL_WATER_Y) and not toilet.bowl_swirl.visible
			and absf(toilet.lever_pivot.rotation.x) < 0.001 and absf(toilet.flapper.rotation.z) < 0.001,
			"終わると元の水位に戻り、レバーと排水弁も戻る（タンク %.3f／便器 %.3f／渦 %s／レバー %.3f／弁 %.3f／流し中 %s）" % [
			tw.position.y, toilet.bowl_water.position.y, toilet.bowl_swirl.visible, toilet.lever_pivot.rotation.x, toilet.flapper.rotation.z, toilet.flushing])
	_check(not lever_hit_lid, "レバーは開いた便器の蓋とぶつからない")

	# ================================================================ 埋め込みの鏡裏収納
	var cab = room.mirror_cabinet
	var mirror: Node3D = cab.door_pivot.get_node("Mirror")
	var mb := _aabb(mirror)
	_check(absf(mb.position.x - cab.WALL_X) < 0.004, "閉じた鏡面は壁面とほぼ同じ位置（x=%.3f、壁 %.3f）" % [mb.position.x, cab.WALL_X])
	var box_aabb := _aabb(cab.get_node("Box"))
	_check(box_aabb.position.x >= cab.WALL_X - 0.001 and box_aabb.end.x <= cab.BACK_X + 0.001, "収納箱は壁の厚みの中に収まる")
	var opening_center := Vector3(cab.WALL_X + 0.05, (cab.Y_RANGE.x + cab.Y_RANGE.y) * 0.5, (cab.Z_RANGE.x + cab.Z_RANGE.y) * 0.5)
	var wall_hits := []
	for n in ["WallRightLow", "WallRightHigh", "WallRightBack", "WallRightFront"]:
		if _aabb(room.get_node("Shell/" + n)).has_point(opening_center):
			wall_hits.append(n)
	_check(wall_hits.is_empty() and not room.has_node("Shell/WallRight"), "壁のメッシュが収納の開口をふさがない")
	var blocker: StaticBody3D = cab.get_node("BodyBlocker")
	_check(blocker.collision_layer == 16 and (player.collision_mask & 16) != 0 and (player.ray.collision_mask & 16) == 0,
			"開口の前面は体だけを止め、照準のレイは通す")

	# ================================================================ 照明と床
	var env: Environment = room.get_node("WorldEnvironment").environment
	var light: OmniLight3D = room.get_node("RoomLight")
	var floor_c: Color = room.FLOOR_COLOR
	var wall_c: Color = room.WALL_COLOR
	_check(light.light_color.r > light.light_color.b + 0.15 and light.light_energy < 0.85 and env.tonemap_mode != Environment.TONE_MAPPER_LINEAR,
			"照明は電球色で、変更前より弱く、白飛びを抑えるトーンマッピングあり")
	_check(floor_c.get_luminance() < wall_c.get_luminance() and floor_c.s < wall_c.s and floor_c.get_luminance() > 0.45,
			"床は淡いグレージュ（壁より少し暗く、彩度が低い）")

	# ================================================================ 開いた扉・外した蓋・水面が視点と照準を遮らないか
	# ここまででタンクの蓋は開いて壁際に置かれている。鏡の扉も開け、浴槽と洗面台を満水にする
	var cab2 = room.mirror_cabinet
	cab2.toggle()
	await _seconds(0.7)
	var sk = room.sink
	sk.level = 1.0
	sk.advance(0.0)
	tub.level = 1.0
	tub.advance(0.0)
	var blockers := {"開いた鏡の扉": cab2.door_pivot, "外したタンクの蓋": toilet.tank_lid, "浴槽の水面": tub._water, "洗面台の水面": sk._water}
	var toner_pos: Vector3 = cab2.get_node("Items/Toner").global_position + Vector3(0, 0.06, 0)
	# しゃがみ：開いた扉の下をくぐってドライバーを狙える
	player.global_position = Vector3(0.2, 0.0, 0.5)   # 洗面台から離れた所（ここなら立ち上がれる）
	player.toggle_crouch()
	await _seconds(0.8)
	_check(_cam_clear(player, blockers), "しゃがみ：カメラが扉・蓋・水面に埋まらない")
	_aim(player, room.get_node("BathBucket").global_position + Vector3(0, 0.05, 0))
	_check(_id(player.get_focused(true)) == "bath_bucket", "しゃがみ：開いた扉の下から床の風呂桶を狙える")
	_check(player.toggle_crouch() and player.pose == Pose.WALK, "しゃがみから立ち上がる")
	await _seconds(0.8)
	# 立ち：開いた扉の向こうの中の物、満水の洗面台の栓
	player.global_position = Vector3(0.25, 0.0, 0.1)
	_aim(player, toner_pos)
	_check(_id(player.get_focused(true)) == "toner", "立ち：開いた扉に遮られず中の化粧水を狙える")
	_aim(player, sk.to_global(sk.DRAIN_POS + Vector3(0, 0.008, 0)))
	var sp_f = player.get_focused(true)
	_check(_id(sp_f) == "sink_plug", "立ち：満水の洗面台でも水面越しに栓を狙える（当たり：%s）" % (player.ray.get_collider().get_path() if player.ray.is_colliding() else "なし"))
	# 着座：レバーとタンクの中、開いた収納の中
	player.global_position = Vector3(0.0, 0.0, 0.35)
	_aim(player, toilet.seat_pivot.to_global(Vector3(0.335, 0.012, 0.0)))
	main.do_action()
	await _seconds(0.8)
	_check(player.pose == Pose.SEATED and _cam_clear(player, blockers), "着座：カメラが扉・蓋・水面に埋まらない")
	_aim(player, toilet.lever_pivot.to_global(Vector3(0.025, 0, 0.03)))
	_check(_id(player.get_focused(true)) == "flush_lever", "着座：タンクの蓋を外していてもレバーを狙える")
	_aim(player, toner_pos)
	var seated_toner := _id(player.get_focused(true))
	_check(seated_toner == "toner" or seated_toner == "", "着座：開いた鏡の扉が中の物への照準を遮らない（%s。遠ければ届かないだけ）" % (seated_toner if seated_toner != "" else "距離外"))
	main.do_action()
	await _seconds(0.8)
	# 浴槽内（満水）：栓・蛇口、外した蓋に遮られない
	player.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(player, tub.to_global(Vector3(0.3, 0.3, 0.375)))
	main.do_action()
	await _seconds(0.8)
	_check(player.pose == Pose.IN_TUB and _cam_clear(player, blockers), "浴槽内（満水）：カメラが水面・蓋・扉に埋まらない")
	_aim(player, tub.to_global(tub.DRAIN_POS + Vector3(0, 0.012, 0)))
	_check(_id(player.get_focused(true)) == "bath_plug", "浴槽内（満水）：水面越しに栓を狙える")
	_aim(player, tub.faucet.to_global(Vector3(0, -0.03, 0.09)))
	_check(_id(player.get_focused(true)) == "bath_faucet", "浴槽内：蛇口を狙える")
	main.do_action()
	await _seconds(0.8)

	# ================================================================ 再プレイ
	# 座ったまま再プレイする（蓋はここまで開いたまま）
	player.global_position = Vector3(0.0, 0.0, 0.35)
	_aim(player, toilet.seat_pivot.to_global(Vector3(0.335, 0.012, 0.0)))
	main.do_action()
	await _seconds(0.8)
	_check(player.pose == Pose.SEATED and toilet.tank_open and room.mirror_cabinet.is_open, "（再プレイ前）座っていて、タンクの蓋と鏡の扉が開いている")
	main._retry()
	await _frames(10)
	var m2 := current_scene
	var p2 = m2.player
	_check(m2 != main and p2.pose == Pose.WALK and p2.global_position.distance_to(m2.room.spawn_position) < 0.06
			and absf(p2.camera.position.y - p2.EYE_HEIGHT) < 0.01 and not p2._shape.disabled
			and not m2.room.toilet.occupied and not m2.room.toilet.flushing
			and is_equal_approx(m2.room.toilet.tank_water.position.y, m2.room.toilet.TANK_WATER_Y),
			"再プレイで立った初期位置・初期設備に戻る")
	var t2 = m2.room.toilet
	var c2 = m2.room.mirror_cabinet
	_check(not t2.tank_open and not t2.tank_busy and t2.tank_lid.position.is_equal_approx(t2.TANK_LID_CLOSED) and t2.tank_lid.rotation.is_equal_approx(Vector3.ZERO)
			and not c2.is_open and not c2.busy and absf(c2.door_pivot.rotation.y) < 0.001,
			"タンクの蓋と鏡の扉を開いたまま再プレイしても、両方閉じた初期状態に戻る")

	print("POSE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## カメラの位置が、どの遮りそうな物（メッシュの外形）の中にも入っていないか。
func _cam_clear(player: Node3D, blockers: Dictionary) -> bool:
	var cam: Vector3 = player.camera.global_position
	for k in blockers:
		var node: Node = blockers[k]
		if node is Node3D and (node as Node3D).is_visible_in_tree() and _aabb(node).grow(0.03).has_point(cam):
			print("    カメラが %s の中：%s" % [k, cam])
			return false
	return true


## 実際のキー入力（押下と解放）を送る。Input → ビューポート → _unhandled_input の経路を通る。
func _press_key(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


## move_forward を duration 秒押して、水平に進んだ距離を返す。
func _walk(player: Node3D, duration: float) -> float:
	player.rotation.y = 0.0
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _seconds(duration)
	Input.action_release("move_forward")
	await _physics(2)
	var moved: Vector3 = player.global_position - start
	player.global_position = start
	await _physics(3)
	return Vector2(moved.x, moved.z).length()


func _prompt_text(main: Node) -> String:
	main._process(0.0)
	return main.hud._prompt_label.text


func _aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	var list: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		list.append(node)
	for mi in list:
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first and node is CollisionObject3D:
		for cs in node.find_children("*", "CollisionShape3D", true, false):
			var sh := cs.shape as BoxShape3D
			var b := AABB(-sh.size * 0.5, sh.size)
			b = cs.global_transform * b
			box = b if first else box.merge(b)
			first = false
	return box


func _id(target: Object) -> String:
	if target == null:
		return ""
	return String(target.get_meta("interact_id", ""))


func _aim(player: Node3D, point: Vector3) -> void:
	var eye: Vector3 = player.camera.global_position
	var d := point - eye
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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(t: float) -> void:
	await create_timer(t).timeout
