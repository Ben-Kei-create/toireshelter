extends SceneTree
## シャンデリア：部屋への収まり（回転を含む実メッシュ）と、電球を実際の照準とクリックで外せること。
## - 収まり：回転で描く形（高さごとの最大半径）を実頂点から求め、壁・天井・まわりの設備・最大の目の高さ・
##   風呂桶に乗った頭との余裕を測る。
## - 電球：目の高さ 170cm で、中央・下端・斜めから、カメラのレイで狙い、Input.parse_input_event の
##   左クリックで外す（操作関数の直接呼び出しは使わない）。F ではめ直す。色の切り替え・再読み込みも確かめる。
## 実行: Godot --headless --path . --script res://tests/chandelier_test.gd
## 実際のマウスの掴み（キャプチャ）も通すなら GUI で: TOIRE_NO_TITLE=1 Godot --path . --script res://tests/chandelier_test.gd

const MARGIN := 0.10        # 壁・設備との最小の余裕（m）
const EYE_MARGIN := 0.05    # 最大の目の高さ（歩きの揺れ込み）との最小の余裕（m）
const HEAD_MARGIN := 0.15   # 風呂桶に乗った目の位置との最小の余裕（m）
const BAND := 0.02

var _failures := 0


func _initialize() -> void:
	_run()


func _fresh() -> Node:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var m := current_scene
	m.credits_enabled = false
	m.ride_speed = 20.0
	m.progress.enabled = false   # GUI で実行しても、保存を書かない（再読み込みで続きが読まれないように）
	return m


func _run() -> void:
	var main = await _fresh()
	var room = main.room
	var player = main.player
	_check_fit(main, room, player)
	await _check_bulb(main, room, player)
	# 再読み込み（「もう一度」と同じ再読み込み。保存は消さない）
	reload_current_scene()
	for i in 10:
		await process_frame
	main = current_scene
	main.progress.enabled = false
	room = main.room
	_check(room.bulb_present and not room.bath_purple and room.bath_light.light_energy > 0.4, "再読み込みで、電球ははまっていて、白い灯り")
	_check(_area_offset(room) < 0.01, "再読み込み後も、判定は電球の位置（ずれ %.3f m）" % _area_offset(room))
	print("CHANDELIER TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- 収まり

func _check_fit(main, room, player) -> void:
	var fx: Node3D = room.get_node("BathBulb")
	var axis := fx.global_position
	# 吊り元のまわりに回る形：高さ（ワールド y）ごとの、軸からの最大半径
	var bands := {}
	var ymin := INF
	var ymax := -INF
	for mi in fx.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf: Transform3D = m.global_transform
		for s in m.mesh.get_surface_count():
			for v in (m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var p: Vector3 = xf * v
				var b := int(floor(p.y / BAND))
				bands[b] = maxf(bands.get(b, 0.0), Vector2(p.x - axis.x, p.z - axis.z).length())
				ymin = minf(ymin, p.y)
				ymax = maxf(ymax, p.y)
	var rmax := 0.0
	for b in bands:
		rmax = maxf(rmax, bands[b])
	_check(rmax > 0.7, "豪華さを保つ：直径 %.2f m（1.4 m 超）" % (rmax * 2.0))
	_check(ymax <= room.ROOM_H + 0.01, "天井から上へ突き抜けない（上端 %.3f m、天井 %.2f m）" % [ymax, room.ROOM_H])
	var eye_top: float = player.EYE_HEIGHT_MAX + player.BOB_WALK
	_check(ymin - eye_top >= EYE_MARGIN, "最大の目の高さ（170cm＋揺れ）の上に余裕：下端 %.3f m、余裕 %.3f m" % [ymin, ymin - eye_top])
	# 壁と設備（天井より下で、吊り元から 1.3m 以内の見た目）。回転で描く形との水平の距離を測る
	var worst := INF
	var worst_name := ""
	for mi in room.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if fx.is_ancestor_of(m) or not m.is_visible_in_tree() or m.mesh == null:
			continue
		var a: AABB = m.global_transform * m.get_aabb()
		if a.end.y < ymin or a.position.y > room.ROOM_H - 0.01:
			continue
		var dx := maxf(0.0, maxf(a.position.x - axis.x, axis.x - a.end.x))
		var dz := maxf(0.0, maxf(a.position.z - axis.z, axis.z - a.end.z))
		var d := Vector2(dx, dz).length()
		if d > 1.3:
			continue
		var r := 0.0
		for b in range(int(floor(maxf(a.position.y, ymin) / BAND)), int(floor(minf(a.end.y, ymax) / BAND)) + 1):
			r = maxf(r, bands.get(b, 0.0))
		if d - r < worst:
			worst = d - r
			worst_name = str(room.get_path_to(m))
	_check(worst >= MARGIN, "回っても壁・設備に入らない：最小の余裕 %.3f m（%s）" % [worst, worst_name])
	var wall_x: float = room.ROOM_W * 0.5 - absf(axis.x) - rmax
	var wall_z: float = room.ROOM_D * 0.5 - absf(axis.z) - rmax
	_check(minf(wall_x, wall_z) >= MARGIN, "左右の壁まで %.3f m、入口の壁まで %.3f m" % [wall_x, wall_z])
	# 浴槽に逆さの風呂桶を置き、その上に立った目（最大の目の高さ）
	var feet: Vector3 = room.bathtub.to_global(main.TUB_FEET_LOCAL) + Vector3(0.0, room.BUCKET_H, 0.0)
	var head := feet + Vector3(0.0, player.EYE_HEIGHT_MAX - 0.05, 0.0)
	var hd := Vector2(head.x - axis.x, head.z - axis.z).length()
	var hr := 0.0
	for b in range(int(floor((head.y - HEAD_MARGIN) / BAND)), int(floor((head.y + HEAD_MARGIN) / BAND)) + 1):
		hr = maxf(hr, bands.get(b, 0.0))
	_check(hd - hr >= HEAD_MARGIN, "風呂桶に乗った頭（目 %.2f m）から離れている：余裕 %.3f m" % [head.y, hd - hr])
	print("    （寸法）吊り元 %s、半径 %.3f m、下端 %.3f m" % [axis, rmax, ymin])


# ---------------------------------------------------------------- 電球

func _check_bulb(main, room, player) -> void:
	_check(_area_offset(room) < 0.01, "電球の判定は、見えている電球の真ん中（ずれ %.3f m）" % _area_offset(room))
	player.head_bob = false
	player.set_eye_height(player.EYE_HEIGHT_MAX)
	var bulb: MeshInstance3D = room._bulb_node
	var bb: AABB = bulb.global_transform * bulb.get_aabb()
	var c := bb.get_center()
	# 立つ位置は電球の真下からの水平のずれ（入口側の通路）。下端は、Codex の再現手順と同じ 0.65 m 手前から
	var foot := Vector3(c.x, 0.0, c.z)
	var shots := [
		["中央", foot + Vector3(0.0, 0.0, 0.7), c],
		["下端", foot + Vector3(0.0, 0.0, 0.65), Vector3(c.x, bb.position.y + 0.005, c.z)],
		["斜め", foot + Vector3(0.38, 0.0, 0.65), c + Vector3(bb.size.x * 0.45, -bb.size.y * 0.3, 0.0)],
	]
	for shot in shots:
		var label: String = shot[0]
		await _stand(player, shot[1])
		_check(absf(player.camera.global_position.y - player.EYE_HEIGHT_MAX) < 0.02, "%s：目の高さ 170cm（%.3f m）" % [label, player.camera.global_position.y])
		player.look_at_point(shot[2])
		await _physics()
		_check(player.get_focused(true) == room.bulb_area, "%s：照準が電球に届く" % label)
		await _click()
		var removed: bool = not room.bulb_present and main.inventory.has("chandelier_bulb") and room.bath_light.light_energy == 0.0
		_check(removed, "%s：左クリックで電球が外れ、灯りが消える" % label)
		# F ではめ直す（持ち物で電球を選び、シャンデリアを狙う）
		main.select_item(main.inventory.find("chandelier_bulb"))
		player.look_at_point(shot[2])
		await _physics()
		await _key(KEY_F)
		_check(removed and room.bulb_present and not main.inventory.has("chandelier_bulb") and room.bath_light.light_energy > 0.4, "%s：F で電球をはめ直すと、また明るい" % label)
	# 色の切り替え（消してつける 4 回で青）と、外す・はめるの組み合わせ
	for i in room.PURPLE_AFTER:
		room.set_bath_light(false)
		room.set_bath_light(true)
	_check(room.bath_purple and room.bath_light.light_color == room.PURPLE_LIGHT_COLOR and room._bulb_mat.emission == room.PURPLE_LIGHT_COLOR, "スイッチを 4 回入れ直すと、青い光")
	await _stand(player, foot + Vector3(0.0, 0.0, 0.7))
	player.look_at_point(c)
	await _physics()
	await _click()
	var removed_blue: bool = not room.bulb_present and room.bath_light.light_energy == 0.0
	_check(removed_blue, "青いときも、電球を外すと消える")
	main.select_item(main.inventory.find("chandelier_bulb"))
	player.look_at_point(c)
	await _physics()
	await _key(KEY_F)
	_check(removed_blue and room.bulb_present and room.bath_purple and room.bath_light.light_energy > 0.4 and room.bath_light.light_color == room.PURPLE_LIGHT_COLOR, "はめ直すと、青い光のまま明るい")


## 電球の判定の中心と、見えている電球の中心の距離
func _area_offset(room) -> float:
	var bulb: MeshInstance3D = room._bulb_node
	var center: Vector3 = bulb.global_transform * bulb.get_aabb().get_center()
	var cs := room.bulb_area.find_children("*", "CollisionShape3D", true, false)[0] as CollisionShape3D
	return cs.global_position.distance_to(center)


func _stand(player, feet: Vector3) -> void:
	# GUI で実行したとき、ウィンドウからフォーカスが外れると自動で一時停止するので、戻してから進める
	var main = current_scene
	if main.paused:
		main._resume()
	player.global_position = feet
	player.velocity = Vector3.ZERO
	for i in 90:
		await physics_frame
		if absf(player.camera.global_position.y - (feet.y + player.eye_height)) < 0.005:
			break


func _physics() -> void:
	for i in 3:
		await physics_frame


func _click() -> void:
	if current_scene.paused:
		current_scene._resume()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


func _key(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
