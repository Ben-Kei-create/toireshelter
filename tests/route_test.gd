extends SceneTree
## TASK-10 の自動検証：正規ルート（浴槽 → 換気口 → 換気経路 → ベランダ → 窓 → 自室）と、誤クリアの防止・一時停止・再プレイ。
## 実行: Godot --headless --path . --script res://tests/route_test.gd
## 経路内とベランダは W キー（Input.action_press）で実際に歩かせ、壁・床・手すりの当たり判定を通す。
## E・C は Input.parse_input_event で実際の入力経路を通す。実キーボード・マウスの確認の代わりにはならない。

const Pose := preload("res://scripts/player.gd").Pose
const Ext := preload("res://scripts/exterior.gd")
const Apt := preload("res://scripts/apartment.gd")

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

	# ---------------------------------------------------------------- 空間の寸法と接続
	var b: AABB = Ext.BALCONY
	_check(is_equal_approx(b.size.x, 2.4) and is_equal_approx(b.size.z, 0.8), "ベランダは幅2.4m・奥行き0.8m")
	_check(absf(Ext.OPPOSITE_Z - b.position.z) > 2.0 and absf(Ext.OPPOSITE_Z - b.position.z) < 3.0, "向かいの建物は手すりから約2〜3m（%.2fm）" % absf(Ext.OPPOSITE_Z - b.position.z))
	_check(Ext.BALCONY_LANDING.distance_to(Vector3((Apt.WINDOW_X.x + Apt.WINDOW_X.y) * 0.5, 0, b.end.z)) < 1.2, "着地点から窓まで数歩（1.2m以内）")
	var bath_box := AABB(Vector3(-0.9, 0, -1.2), Vector3(1.8, 2.2, 2.4))
	_check(not bath_box.intersects(Apt.ROOM) and not bath_box.intersects(b) and not Apt.ROOM.intersects(b), "浴室・自室・ベランダの空間が重ならない")

	# ---------------------------------------------------------------- 誤クリアの防止
	_check(not main.cleared and main.region == "bath", "開始時は浴室・未クリア")
	# ドアを直していなくても、位置だけ自室に置いてもクリアしない（直前の区画が浴室）
	var start: Vector3 = player.global_position
	player.global_position = Vector3(2.5, 0.0, 0.5)
	await _physics(4)
	_check(not main.cleared and main.region == "room", "経路を通らず位置だけ自室に移してもクリアにならない")
	player.global_position = start
	await _physics(4)

	# ---------------------------------------------------------------- カーテンを閉めて開け直してから進む
	room.shower_curtain.toggle()
	await _seconds(0.6)
	_check(room.shower_curtain.closed, "（準備）カーテンを閉めた")
	room.shower_curtain.toggle()
	await _seconds(0.6)
	_check(not room.shower_curtain.closed, "（準備）カーテンを開け直した")

	# ---------------------------------------------------------------- 風呂桶を逆さにして浴槽に置く（足場）
	player.global_position = Vector3(0.2, 0.0, -0.1)
	_aim(player, room.get_node("BathBucket").global_position + Vector3(0, 0.1, 0))
	player.try_interact()
	_check(main.inventory.has("bucket"), "（準備）風呂桶を拾った")
	main.select_item(main.inventory.find("bucket"))
	player.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(player, tub.to_global(Vector3(0.3, 0.3, 0.375)))
	main.use_selected()
	_check(room.bucket_in_tub and not main.inventory.has("bucket"), "（準備）風呂桶を逆さにして浴槽に置いた")

	# ---------------------------------------------------------------- 換気口へ入る（浴槽から）
	player.global_position = Vector3(0.3, 0.0, -0.2)
	_aim(player, tub.to_global(Vector3(0.3, 0.3, 0.375)))
	await _key(KEY_E)
	await _seconds(0.8)
	_check(player.pose == Pose.IN_TUB, "浴槽に入る")
	var vent_pos := Vector3(-0.72, 2.18, -1.02)
	_aim(player, vent_pos)
	var vh = player.get_focused(true)
	_check(main._action_for(vh) == "vent_enter" and main.ACTION_PROMPTS["vent_enter"] in _prompt(main), "浴槽から換気口を狙うと「E：換気口へ入る」")
	player.global_position = Vector3.ZERO   # （立った状態では出ないことの確認用に一時的に戻す）
	player.global_position = main._tub_feet()
	await _key(KEY_E)
	_check(player.pose == Pose.TRANSITION and room.vent_open, "格子が開き、移動演出が始まる")
	await _seconds(0.25)
	main._pause()
	var pp: Vector3 = player.global_position
	await _seconds(0.3)
	_check(player.global_position.is_equal_approx(pp) and player.pose == Pose.TRANSITION, "換気口へ入る途中で一時停止すると止まる")
	main._resume()
	await _seconds(1.0)
	_check(player.pose == Pose.DUCT and main.region == "duct" and absf(player.camera.position.y - player.DUCT_EYE_HEIGHT) < 0.01
			and not player._shape.disabled, "換気経路に入る（低い姿勢、体の当たり判定あり）")

	# ---------------------------------------------------------------- 換気経路の中
	await _key(KEY_C)
	_check(player.pose == Pose.DUCT, "経路の中では C で立ち上がれない")
	_check(main._action_for(null) == "duct_back", "入口付近では「E：浴室へ戻る」")
	# 入口から浴室へ戻って、もう一度入る
	await _key(KEY_E)
	await _seconds(1.1)
	_check(player.pose == Pose.IN_TUB and main.region == "bath", "入口から浴槽へ戻れる（pose=%d region=%s pos=%s）" % [player.pose, main.region, player.global_position])
	_aim(player, vent_pos)
	await _key(KEY_E)
	await _seconds(1.1)
	_check(player.pose == Pose.DUCT, "もう一度換気経路へ入る")
	# 横の管を +x へ這う（壁・床をすり抜けない）
	var y0: float = player.global_position.y
	player.rotation.y = -PI * 0.5   # +x を向く
	await _hold("move_forward", 4.5)
	var p1: Vector3 = player.global_position
	_check(p1.x > 1.7 and p1.x < Ext.DUCT_A.end.x and p1.z > Ext.DUCT_A.position.z and p1.z < Ext.DUCT_A.end.z
			and absf(p1.y - y0) < 0.05, "横の管を這って曲がり角まで行ける（%s）。端の壁で止まり、床に沈まない" % p1)
	await _hold("move_left", 1.0)   # 横（-z の壁）へ押しつけても抜けない
	_check(player.global_position.z > Ext.DUCT_A.position.z - 0.01 or player.global_position.x > Ext.DUCT_B.position.x, "管の壁をすり抜けない")
	# 角を曲がって出口（-z）へ（位置は動かさず、向きだけ変えて這う）
	player.rotation.y = 0.0   # -z を向く
	await _hold("move_forward", 2.5)
	var p2: Vector3 = player.global_position
	_check(p2.z > Ext.DUCT_B.position.z - 0.02 and p2.z < Ext.DUCT_EXIT_EDGE_Z and absf(p2.y - y0) < 0.05,
			"出口側の管を進み、外壁の出口の手前で止まる（落ちない。z=%.2f）" % p2.z)
	_check(main._action_for(null) == "balcony_down" and main.ACTION_PROMPTS["balcony_down"] in _prompt(main), "出口で「E：ベランダへ降りる」")
	_check(not main.cleared, "（経路の中ではクリアしない）")

	# ---------------------------------------------------------------- ベランダへ降りる
	await _key(KEY_E)
	await _seconds(0.3)
	main._pause()
	pp = player.global_position
	await _seconds(0.3)
	_check(player.global_position.is_equal_approx(pp), "降りる途中で一時停止すると止まる")
	main._resume()
	await _seconds(0.7)
	await _physics(5)
	_check(player.pose == Pose.WALK and main.region == "balcony" and main.route_duct and absf(player.global_position.y) < 0.03
			and not main.cleared, "ベランダの空いた床に着地（%s）。ベランダ到着だけではクリアしない" % player.global_position)
	# 手すりを越えられない
	var land: Vector3 = player.global_position
	player.rotation.y = 0.0
	await _hold("move_forward", 1.5)
	_check(player.global_position.z > b.position.z, "手すりを越えて外へ出られない（z=%.2f）" % player.global_position.z)
	# 閉じた窓とカーテン越しには、部屋の中（本棚）が見えない
	player.global_position = Vector3(2.5, 0.0, -1.7)
	await _physics(2)
	var shelf_pt := Vector3(3.8, 1.2, 0.5)
	var vis_space = player.get_world_3d().direct_space_state
	var cam_pos: Vector3 = player.camera.global_position
	_check(_mesh_between(room.apartment.curtain, cam_pos, shelf_pt), "閉じたカーテンが部屋の中への視線をさえぎる")
	# 閉じた窓は通れない
	player.global_position = Vector3(2.15, 0.0, -1.6)
	await _physics(3)
	player.rotation.y = PI   # +z（自室）を向く
	await _hold("move_forward", 1.0)
	_check(player.global_position.z < -1.3 and main.region == "balcony", "閉じた窓は通れない")
	# 窓を開ける
	_aim(player, Vector3(2.15, 1.0, -1.25))
	var wh = player.get_focused(true)
	_check(_id(wh) == "window" and main._prompt_for(wh) == main.PROMPTS["window_open"], "窓を狙うと「窓を開ける」")
	player.try_interact()
	await _seconds(0.7)
	_check(room.apartment.window_open and room.apartment.curtain_closed and room.apartment.curtain.scale.x > 0.99, "窓が開いても、遮光カーテンは別に閉まったまま（部屋の中から開け閉めする）")
	# 自室へ歩いて入る → 正規クリア
	player.rotation.y = PI
	player._pitch = 0.0
	player.camera.rotation.x = 0.0
	await _hold("move_forward", 1.5)
	_check(not main.cleared and main.region == "room", "窓から自室へ入ってもクリアにならない")
	# 自室からホール → 玄関ドアを開けて廊下へ出ると、正規ルートの脱出
	for target in [Vector3(1.5, 0.05, 1.85), Vector3(0.0, 0.05, 1.85)]:
		for i in 400:
			player.velocity = Vector3.ZERO
			player.global_position = player.global_position.move_toward(target, 0.03)
			await physics_frame
			if player.global_position.distance_to(target) < 0.01:
				break
	_check(not main.cleared and main.region == "hall", "ホールに着いてもクリアにならない")
	main.room.front_door.interact("front_door")
	await _seconds(1.1)
	for i in 400:
		player.velocity = Vector3.ZERO
		player.global_position = player.global_position.move_toward(Vector3(-1.7, 0.05, 1.85), 0.03)
		await physics_frame
		if main.cleared:
			break
	_check(main.cleared and main.clear_route == "legit"
			and (main.hud._clear_menu.get_node("Center/Box").get_child(0) as Label).text == "正規ルートで脱出",
			"玄関ドアから廊下へ出ると「正規ルートで脱出」でクリア")

	# ---------------------------------------------------------------- 再プレイ
	main._retry()
	await _frames(10)
	var m2 := current_scene
	var p2n = m2.player
	_check(m2 != main and not m2.cleared and not m2.route_duct and m2.clear_route == "" and p2n.pose == Pose.WALK
			and p2n.global_position.distance_to(m2.room.spawn_position) < 0.06 and not m2.room.vent_open
			and not m2.room.apartment.window_open, "再プレイで浴室の初期位置・格子と窓は閉・経路の記録なし")

	print("ROUTE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## from から to への線分が node のメッシュの外形を通るか（見た目の遮蔽の目安）。
func _mesh_between(node: Node3D, from: Vector3, to: Vector3) -> bool:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.grow(0.01).intersects_segment(from, to) != null:
			return true
	return false


func _hold(action: String, seconds: float, stop: Callable = Callable()) -> void:
	Input.action_press(action)
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await physics_frame
		if stop.is_valid() and stop.call():
			break
	Input.action_release(action)
	await physics_frame


func _prompt(main: Node) -> String:
	main._process(0.0)
	return main.hud._prompt_label.text


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(t: float) -> void:
	await create_timer(t).timeout
