extends SceneTree
## ヘッドレス自動検証（実キーボード・マウスの操作確認の代わりにはならない）。
## 実行: Godot --headless --path . --script res://tests/smoke_test.gd
## 照準判定・取得→修理→脱出→再プレイ・一時停止/再開を、スクリプトから直接呼び出して確認する。

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(10)
	var main := current_scene
	var player = main.player
	var room = main.room
	var driver_pos: Vector3 = room.driver_node.global_position

	# --- 照準：対象から視点を外して即クリック（物理フレームを挟まない）
	player.global_position = Vector3(0.2, 0.0, 0.3)
	await _frames(3)
	_aim(player, driver_pos)
	await physics_frame
	await physics_frame
	_check(player.get_focused() != null, "照準を合わせると表示用の判定にドライバーが入る")
	_aim(player, driver_pos + Vector3(-1.5, 1.2, 0.0))   # 視点を外す
	_check(player.get_focused() != null, "（再現）視点変更直後は表示用キャッシュが古い対象を返す")
	player.try_interact()
	_check(not main.has_driver, "視点を外した直後のクリックでは拾わない")

	# --- 壁越しの遮断：右の壁の外から狙う
	var saved: Vector3 = player.global_position
	player.global_position = Vector3(1.25, 0.0, 0.05)
	_aim(player, driver_pos)
	player.try_interact()
	_check(not main.has_driver, "壁越しには拾えない")
	player.global_position = saved

	# --- 換気口：初期位置（床）から見上げて調べられる。通常の距離 1.8m より遠い
	var vent_body: Node3D = room.get_node("Vent/Collision")
	var vent_pos: Vector3 = vent_body.global_position + Vector3(0.0, -0.02, 0.0)
	player.global_position = room.spawn_position
	_aim(player, vent_pos)
	var vent_dist: float = player.camera.global_position.distance_to(vent_pos)
	player.try_interact()
	_check(main.hud._message_label.text == main.MESSAGES["vent"] and vent_dist > player.INTERACT_RANGE,
			"初期位置から換気口を調べられる（距離 %.2fm）" % vent_dist)

	# --- 換気口：天井の上からは天井に遮られる
	main.hud._message_label.text = ""
	player.global_position = vent_body.global_position + Vector3(0.0, 0.0, 0.0)   # 目の高さが天井より上
	_aim(player, vent_pos)
	player.try_interact()
	_check(main.hud._message_label.text == "", "天井越しには換気口を調べられない")

	# --- ほかの対象の操作距離は伸びていない：レイが便器に当たる点が 1.8m より遠い位置から
	player.global_position = Vector3(0.65, 0.0, 1.0)
	_aim(player, Vector3(-0.6, 0.85, 0.0))   # タンク上部
	player.ray.force_raycast_update()
	var toilet_hit: Node = player.ray.get_collider()
	var hit_dist: float = player.ray.global_position.distance_to(player.ray.get_collision_point())
	player.try_interact()
	_check(toilet_hit == room.get_node("Toilet/Collision") and hit_dist > player.INTERACT_RANGE
			and main.hud._message_label.text == "",
			"便器は当たり点が 1.8m より遠いと調べられない（当たり点まで %.2fm）" % hit_dist)
	player.global_position = saved

	# --- ドアの広告：広告を狙うと poster、広告の外側（下）を狙うと従来どおり door
	var msgs: Dictionary = main.MESSAGES
	var poster: Node3D = room.door_pivot.get_node("Visual/Poster")
	player.global_position = Vector3(0.0, 0.0, 0.3)
	main.hud._message_label.text = ""
	_aim(player, poster.global_position)
	player.try_interact()
	_check(main.hud._message_label.text == msgs["poster"], "ドアの広告を調べられる")
	main.hud._message_label.text = ""
	_aim(player, room.door_pivot.global_position + Vector3(0.35, 0.6, 0.0))
	player.try_interact()
	_check(main.hud._message_label.text == msgs["door_locked"], "広告の外側を狙うとドアを調べられる")
	main.hud._message_label.text = ""
	_aim(player, room.door_pivot.global_position + Vector3(0.62, 0.95, 0.0))   # ドアノブ付近
	player.try_interact()
	_check(main.hud._message_label.text == msgs["door_locked"], "ドアノブ付近もドアとして反応する")

	# --- 広告：閉じたドアの外（廊下）からは、ドアに遮られて広告を調べられない
	player.global_position = Vector3(0.0, 0.0, 2.0)
	_aim(player, poster.global_position)
	_check(player.get_focused(true) == room.door_body, "廊下側からは広告ではなくドアに当たる")

	# --- 入浴剤：タンクの上に浮かず、はみ出さずに置かれている
	var powder: Node3D = room.get_node("BathPowder/Visual")
	var pp: Vector3 = powder.global_position
	var r: float = room.LID_RADIUS
	_check(is_equal_approx(pp.y, 0.925) and pp.x - r >= -0.9 and pp.x + r <= -0.7 and pp.z - r >= -0.2 and pp.z + r <= 0.2,
			"入浴剤の容器がタンク上面に収まっている (%s)" % pp)

	# --- 入浴剤を調べられる／壁の外からは調べられない
	var powder_mid := pp + Vector3(0.0, 0.08, 0.0)
	player.global_position = Vector3(0.0, 0.0, 0.3)
	main.hud._message_label.text = ""
	_aim(player, powder_mid)
	player.try_interact()
	_check(main.hud._message_label.text == msgs["bath_powder"], "入浴剤の容器を調べられる")
	player.global_position = Vector3(-1.3, 0.0, -0.08)
	_aim(player, powder_mid)
	var behind = player.get_focused(true)
	_check(behind == null, "左の壁の外からは入浴剤を調べられない")
	player.global_position = saved

	# --- 画像はミップマップ付きで取り込まれている
	_check(room.POSTER_TEX.get_image().has_mipmaps() and room.LABEL_TEX.get_image().has_mipmaps()
			and room.TOWEL_TEX.get_image().has_mipmaps() and room.TOOTHPASTE_TEX.get_image().has_mipmaps()
			and room.supplies.ROLL_WRAP_TEX.get_image().has_mipmaps() and room.supplies.CLEANER_TEX.get_image().has_mipmaps()
			and room.supplies.STICKER_TEX.get_image().has_mipmaps(),
			"画像7枚すべてにミップマップがある")

	# ================================================================ TASK-05 水回り
	var toilet = room.toilet
	var tub = room.bathtub
	var sink_faucet = room.sink_faucet
	_check(not toilet.lid_open and not toilet.seat_up and tub.level == 0.0 and tub.plug_in
			and not tub.faucet.is_on and not sink_faucet.is_on, "初期状態：蓋・便座が閉、浴槽が空、栓あり、蛇口OFF")

	# --- 便器：狙い分けと案内
	player.global_position = Vector3(0.0, 0.0, 0.3)
	_aim(player, toilet.lid_pivot.to_global(Vector3(0.2, 0.02, 0.0)))
	var t_hit = player.get_focused(true)
	_check(_id(t_hit) == "toilet_lid" and main._prompt_for(t_hit) == main.PROMPTS["lid_open"], "閉じた蓋を狙うと「蓋を開ける」")
	for i in 5:   # 連打
		player.try_interact()
	_check(toilet.lid_open and toilet.busy and main._prompt_for(t_hit) == "", "蓋の連打：1回だけ受け付け、動作中は案内を出さない")
	await _seconds(0.6)
	_check(not toilet.busy and is_equal_approx(snappedf(rad_to_deg(toilet.lid_pivot.rotation.z), 0.01), toilet.LID_OPEN_DEG),
			"蓋が %.0f° まで開いて止まる" % toilet.LID_OPEN_DEG)
	_aim(player, toilet.seat_pivot.to_global(Vector3(0.335, 0.012, 0.0)))   # 便座の前側
	t_hit = player.get_focused(true)
	_check(_id(t_hit) == "toilet_seat" and main._prompt_for(t_hit) == main.PROMPTS["seat_up"], "蓋を開けると便座を狙える「便座を上げる」")
	_aim(player, Vector3(-0.5, 0.236, 0.0))   # 便座の穴から便器の中
	_check(_id(player.get_focused(true)) == "toilet", "便座の穴から便器の中を調べられる")
	_aim(player, toilet.seat_pivot.to_global(Vector3(0.335, 0.012, 0.0)))
	player.try_interact()
	await _seconds(0.6)
	_check(toilet.seat_up and is_equal_approx(snappedf(rad_to_deg(toilet.seat_pivot.rotation.z), 0.01), toilet.SEAT_OPEN_DEG), "便座を上げられる")
	# 便座が上がったまま蓋を閉じる：便座が下りきるまで蓋は動かない（突き抜けない）
	toilet.interact("toilet_lid")
	var penetrated := false
	for i in 120:
		await process_frame
		var lid_deg := rad_to_deg(toilet.lid_pivot.rotation.z)
		var seat_deg := rad_to_deg(toilet.seat_pivot.rotation.z)
		if seat_deg > 0.5 and lid_deg < toilet.LID_OPEN_DEG - 0.5:
			penetrated = true
		if not toilet.busy:
			break
	_check(not penetrated and not toilet.lid_open and not toilet.seat_up and not toilet.busy
			and absf(toilet.lid_pivot.rotation.z) < 0.001 and absf(toilet.seat_pivot.rotation.z) < 0.001,
			"便座が上がったまま蓋を閉じると、便座→蓋の順に閉じる（重なりなし）")
	toilet.interact("toilet_seat")   # 蓋が閉じているときに便座の縁を狙った場合
	_check(toilet.lid_open and not toilet.seat_up, "蓋が閉じているときの便座クリックは蓋を開ける")
	await _seconds(0.6)
	toilet.interact("toilet_lid")
	await _seconds(0.6)

	# --- 浴槽：通常の立ち位置（浴槽の前）から蛇口と栓を狙える
	player.global_position = Vector3(0.6, 0.0, -0.2)
	var spout: Vector3 = tub.faucet.to_global(Vector3(0, -0.03, 0.09))
	_aim(player, spout)
	var f_hit = player.get_focused(true)
	_check(_id(f_hit) == "bath_faucet" and main._prompt_for(f_hit) == main.PROMPTS["water_on"], "浴槽の蛇口を狙うと「水を出す」")
	player.try_interact()
	_check(tub.faucet.is_on and absf(tub.faucet.stream_length() - (spout.y - 0.015 - tub.BOTTOM_Y)) < 0.01,
			"蛇口から浴槽の底まで水が流れる（%.2fm）" % tub.faucet.stream_length())
	# 水位 0／25／50／100% で、計算値だけでなく水面メッシュと水流メッシュの実際の位置を確かめる
	for lv in [0.0, 0.25, 0.5, 1.0]:
		tub.level = lv
		tub.advance(0.0)
		tub.faucet._update_stream()
		var water: MeshInstance3D = tub._water
		var expect_y: float = tub.to_global(Vector3(0, lerpf(tub.WATER_MIN_Y, tub.WATER_MAX_Y, lv), 0)).y
		var stream: MeshInstance3D = tub.faucet._stream
		var stream_bottom: float = stream.global_position.y - stream.global_transform.basis.get_scale().y * 0.5
		var floor_y: float = expect_y if lv > 0.0 else tub.to_global(Vector3(0, tub.BOTTOM_Y, 0)).y
		var water_ok: bool = (not water.visible) if lv == 0.0 else (water.visible and absf(water.global_position.y - expect_y) < 0.0005)
		_check(water_ok and stream.visible and absf(stream_bottom - floor_y) < 0.0005
				and water.global_position.y < tub.HALF.y,
				"水位%d%%：水面メッシュ %s、水流の下端 %.3f = %s %.3f" % [int(lv * 100.0),
				("非表示" if not water.visible else "y=%.3f" % water.global_position.y), stream_bottom,
				("水面" if lv > 0.0 else "底"), floor_y])
	tub.level = 0.0
	tub.advance(0.0)
	var plug_pos: Vector3 = tub.to_global(tub.DRAIN_POS + Vector3(0, 0.012, 0))
	_aim(player, plug_pos)
	var p_hit = player.get_focused(true)
	var plug_dist: float = player.camera.global_position.distance_to(plug_pos)
	_check(_id(p_hit) == "bath_plug" and main._prompt_for(p_hit) == main.PROMPTS["plug_pull"] and plug_dist < player.INTERACT_RANGE,
			"浴槽の前から底の栓を狙える（%.2fm、距離の調整なし）" % plug_dist)

	# --- 貯水・排水（時間を進めて計算）
	tub.advance(20.0)
	_check(is_equal_approx(tub.level, 0.5), "給水20秒で半分（満水まで40秒）")
	tub.advance(30.0)
	_check(tub.level == 1.0 and tub.water_y() <= tub.WATER_MAX_Y and tub.WATER_MAX_Y < tub.HALF.y, "満水で止まり、水面は縁より下")
	_check(tub.faucet.stream_length() < spout.y - tub.WATER_MAX_Y, "水流は水面までで止まる")
	tub.faucet.interact("bath_faucet")
	tub.advance(100.0)
	_check(tub.level == 1.0 and not tub.faucet.is_on, "蛇口を止めて栓をしていれば水位を保つ")
	player.try_interact()   # 照準は栓
	_check(not tub.plug_in and main._prompt_for(p_hit) == main.PROMPTS["plug_insert"], "栓を抜くと案内が「栓をする」になる")
	tub.advance(10.0)
	_check(is_equal_approx(tub.level, 0.6), "栓を抜くと水位が下がる（満水から25秒で空）")
	tub.faucet.interact("bath_faucet")
	tub.advance(10.0)
	_check(is_equal_approx(tub.level, 0.6 - 10.0 * (1.0 / 25.0 - 1.0 / 40.0)), "給水と排水を同時に行うと流量差で下がる")
	tub.advance(100.0)
	_check(tub.level == 0.0 and not tub._water.visible, "空になると下限で止まり、水面が消える")
	main.hud._message_label.text = ""
	tub.interact("bathtub")
	_check(tub.interact("bathtub") == "bathtub_wet", "排水後の浴槽は「濡れている」説明になる")

	# --- 一時停止中は給水が止まる
	tub.set_plug(true)
	tub.advance(8.0)
	var before: float = tub.level
	main._pause()
	await _seconds(0.3)
	var paused_level: float = tub.level
	main._resume()
	await _seconds(0.3)
	_check(is_equal_approx(paused_level, before) and tub.level > before, "一時停止中は水位が変わらず、再開すると戻る")

	# --- 浴槽の蛇口：奥の壁の外からは操作できない
	player.global_position = Vector3(0.55, 0.0, -1.6)
	_aim(player, spout)
	_check(_id(player.get_focused(true)) != "bath_faucet", "奥の壁の外からは浴槽の蛇口を操作できない")

	# --- 洗面台の蛇口：水を出す／止める（たまらない）
	player.global_position = Vector3(0.3, 0.0, 0.1)
	_aim(player, sink_faucet.to_global(Vector3(-0.05, 0.11, 0)))
	var s_hit = player.get_focused(true)
	_check(_id(s_hit) == "sink_faucet" and main._prompt_for(s_hit) == main.PROMPTS["water_on"], "洗面台の蛇口を狙うと「水を出す」")
	player.try_interact()
	var s_len: float = sink_faucet.stream_length()
	_check(sink_faucet.is_on and s_len > 0.05 and s_len < 0.15, "洗面台の蛇口から水が流れる（%.2fm）" % s_len)
	await _seconds(0.2)
	_check(is_equal_approx(sink_faucet.stream_length(), s_len), "洗面台の水はたまらず、流れ続ける")
	player.global_position = saved

	# ================================================================ TASK-06 生活用品
	var sup = room.supplies
	var msgs6: Dictionary = main.MESSAGES
	var targets := [
		["paper_holder", Vector3(-0.2, 0, 0.75), Vector3(-0.83, 0.70, 0.30)],
		["spare_roll", Vector3(-0.4, 0, 0.6), Vector3(-0.83, 1.41, 0.09)],
		["toilet_cleaner", Vector3(-0.4, 0, 0.6), Vector3(-0.83, 1.44, -0.09)],
		["plunger", Vector3(-0.2, 0, 0.6), Vector3(-0.80, 0.30, 0.995)],
		["toilet_brush", Vector3(-0.2, 0, 0.6), Vector3(-0.80, 0.30, 1.125)],
	]
	for t in targets:
		main.hud._message_label.text = ""
		player.global_position = t[1]
		_aim(player, t[2])
		player.try_interact()
		_check(main.hud._message_label.text == msgs6[t[0]], "%s を調べられる" % t[0])
	# 点検シール：初期位置の床から（1.8m より遠い）／天井の上からは遮られる
	main.hud._message_label.text = ""
	player.global_position = room.spawn_position
	_aim(player, sup.STICKER_CENTER - Vector3(0, 0.004, 0))
	var st_dist: float = player.camera.global_position.distance_to(sup.STICKER_CENTER)
	player.try_interact()
	_check(main.hud._message_label.text == msgs6["vent_sticker"] and st_dist > player.INTERACT_RANGE and st_dist < sup.STICKER_RANGE,
			"初期位置から点検シールを調べられる（%.2fm）" % st_dist)
	main.hud._message_label.text = ""
	player.global_position = sup.STICKER_CENTER + Vector3(0, -0.6, 0.0)   # 目の高さが天井より上
	_aim(player, sup.STICKER_CENTER - Vector3(0, 0.004, 0))
	player.try_interact()
	_check(main.hud._message_label.text == "", "天井越しには点検シールを調べられない")
	player.global_position = saved

	# ラバーカップとブラシ：持ち手が垂直、台の前端からの距離と両端の余白がそろう、通路を狭めない
	var ph: Node3D = sup.plunger.get_node("Handle")
	var bh: Node3D = sup.brush.get_node("Handle")
	var tray_z0: float = sup.STAND_CENTER.z - sup.STAND_SIZE.z * 0.5
	var tray_z1: float = sup.STAND_CENTER.z + sup.STAND_SIZE.z * 0.5
	_check(ph.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.9999 and bh.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.9999
			and is_equal_approx(sup.plunger.global_position.x, sup.brush.global_position.x)
			and is_equal_approx(sup.plunger.global_position.z - tray_z0, tray_z1 - sup.brush.global_position.z),
			"ラバーカップとブラシの持ち手が垂直で、前端と間隔がそろっている")
	var stand_box := _mesh_aabb(sup.get_node("CleaningStand"))
	_check(stand_box.end.x < -0.35 - 0.25, "収納台はドアの開口と通路にかからない（x ≤ %.2f）" % stand_box.end.x)

	# 実際の寸法で重なりを確認：蓋を開け、便座を上げた状態で
	toilet.toggle_lid()
	await _seconds(0.6)
	toilet.toggle_seat()
	await _seconds(0.6)
	var others := {
		"開いた蓋": toilet.lid_pivot, "上げた便座": toilet.seat_pivot,
		"入浴剤": room.get_node("BathPowder/Visual"), "タオル": room.get_node("TowelBar"),
		"便器本体": toilet.get_node("Visual"), "換気口": room.get_node("Vent/Visual"),
	}
	for name in ["PaperHolder", "SupplyShelf", "CleaningStand", "VentSticker"]:
		var a := _mesh_aabb(sup.get_node(name))
		for ax in 3:   # 接しているだけの面を重なりと数えないよう 1mm 縮める（厚みのない板の軸は除く）
			if a.size[ax] > 0.002:
				a.position[ax] += 0.001
				a.size[ax] -= 0.002
		var hits := []
		for o in others:
			if a.intersects(_mesh_aabb(others[o])):
				hits.append(o)
		_check(hits.is_empty(), "%s は他の物と重ならない%s" % [name, "" if hits.is_empty() else "（重なり：%s）" % ", ".join(hits)])
	toilet.toggle_lid()
	await _seconds(1.0)

	# --- 照準を合わせてクリックすると拾える
	_aim(player, driver_pos)
	player.try_interact()
	_check(main.has_driver, "照準を合わせたクリックで拾える")
	await _frames(2)

	# --- ドア修理
	var door_pos: Vector3 = room.door_pivot.global_position + Vector3(0.35, 0.95, 0.0)
	player.global_position = Vector3(0.0, 0.0, 0.5)
	await _frames(3)
	_aim(player, door_pos)
	player.try_interact()
	_check(main.door_open, "ドライバー所持でドアを直せる")

	# --- 一時停止・再開
	main._pause()
	_check(paused and main.paused, "一時停止でツリーが止まる")
	var menu_size: Vector2 = main.hud._pause_menu.size
	_check(menu_size.x >= 640.0 and menu_size.y >= 360.0, "一時停止メニューが全画面に広がる (%s)" % menu_size)
	main._resume()
	_check(not paused and not main.paused, "再開でツリーが動く")

	# --- 出口通過
	await _seconds(1.4)
	for i in 120:
		player.velocity = Vector3.ZERO
		player.global_position = player.global_position.move_toward(Vector3(0.0, 0.05, 2.4), 0.03)
		await physics_frame
		if main.cleared:
			break
	_check(main.cleared, "廊下に出るとクリアになる")

	# --- 再プレイ
	main._retry()
	await _frames(10)
	var main2 := current_scene
	_check(main2 != main and not main2.has_driver and not main2.door_open and not main2.cleared,
			"「もう一度」で初期状態に戻る")
	_check(main2.room.driver_node != null, "再プレイ後にドライバーが元の位置にある")
	var r2 = main2.room
	_check(not r2.toilet.lid_open and not r2.toilet.seat_up and r2.bathtub.level == 0.0 and r2.bathtub.plug_in
			and not r2.bathtub.faucet.is_on and not r2.sink_faucet.is_on,
			"再プレイで蓋・便座が閉、浴槽が空、栓あり、蛇口OFFに戻る")

	print("SMOKE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## node 以下のすべてのメッシュを覆うワールド座標の箱。
func _mesh_aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	var list: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		list.append(node)
	for mi in list:
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _id(target: Object) -> String:
	if target == null:
		return ""
	return String(target.get_meta("interact_id", ""))


func _aim(player: Node3D, point: Vector3) -> void:
	# マウス操作と同じく、本体の yaw とカメラの pitch を変える
	var eye: Vector3 = player.global_position + Vector3(0.0, player.EYE_HEIGHT, 0.0)
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


func _seconds(t: float) -> void:
	await create_timer(t).timeout
