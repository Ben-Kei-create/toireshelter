extends SceneTree
## 結末の検証：部屋を出たらクリア（エンドロール → クリア画面）。百円玉を持って出ると、エレベーター → 1 階の玄関ホール → アーチ →
## 路地 → ベランダの真下の自動販売機 → 真のクリア。身長が足りないと最上段のボタンに届かない。1 階の入口と廊下が上下でそろっていること。
## 実行: Godot --headless --path . --script res://tests/ending_test.gd
## 玄関ホールから路地までは、W キー（Input.action_press）で実際に歩かせ、壁・床・アーチの当たり判定を通す。

const Corridor := preload("res://scripts/corridor.gd")
var _failures := 0


func _initialize() -> void:
	_run()


func _fresh() -> Node:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var m := current_scene
	m.ride_speed = 8.0
	return m


func _to_corridor(main: Node) -> void:
	# 玄関ホールから玄関ドアの外（廊下）へ出た、という移り変わりを作る
	main.player.global_position = Vector3(-0.5, 0.0, 1.85)
	for i in 3:
		await physics_frame
	main.player.global_position = Vector3(-1.6, 0.0, 1.85)
	for i in 3:
		await physics_frame


func _run() -> void:
	# ---------------------------------------------------------------- 百円玉なし：部屋を出たらクリア
	var main = await _fresh()
	main.credits_enabled = false
	await _to_corridor(main)
	_check(main.cleared and main.clear_route == "shortcut", "百円玉なしで部屋を出ると、そこでクリア（%s）" % main.clear_route)
	_check(main.hud._clear_menu.visible, "（エンドロールなし）クリア画面が出る")

	# ---------------------------------------------------------------- エンドロール → クリア画面
	main = await _fresh()
	await _to_corridor(main)
	_check(main.cleared and main.hud.is_credits_playing() and not main.hud._clear_menu.visible, "エンドロールが流れ、クリア画面はまだ出ない")
	await create_timer(2.2).timeout
	main.hud.skip_credits()
	await process_frame
	_check(not main.hud.is_credits_playing() and main.hud._clear_menu.visible, "エンドロールを飛ばすと、クリア画面が出る")

	# ---------------------------------------------------------------- 百円玉あり：クリアにならず、エレベーターへ
	main = await _fresh()
	main.credits_enabled = false
	main.give_yen100()
	_check(main.inventory.has("yen100") and main.item_name("yen100") == "百円玉", "百円玉を持ち物に入れられる")
	await _to_corridor(main)
	_check(not main.cleared and main.region == "corridor", "百円玉を持って部屋を出ても、クリアにならない")
	var corridor = main.room.corridor
	var area: Node = corridor.get_node("Elevator/ElevatorArea")
	_check(String(area.get_meta("interact_id")) == "elevator" and main._prompt_for(area) == "左クリック：エレベーターに乗る", "廊下のエレベーターの扉に「エレベーターに乗る」")
	var car = main.room.get_node("ElevatorCar")
	main._on_interact_requested(area)
	await create_timer(0.45).timeout
	_check(main.riding and main.region == "car", "乗ると、箱の中へ移る（%s）" % main.region)
	while main.riding:
		await physics_frame
	_check(car._floor_label.text == "1", "表示が 5 から 1 へ変わった")
	_check(main.region == "lobby" and main.player.controls_enabled, "1 階の玄関ホールに着き、動ける（%s）" % main.region)
	var p = main.player
	_check(absf(p.global_position.x - (-1.85)) < 0.01 and absf(p.global_position.y - (-13.6)) < 0.2 and p.global_position.z > 4.5, "廊下のエレベーターの真下に着く（%s）" % p.global_position)

	# ---------------------------------------------------------------- 玄関ホール → アーチ → 路地：歩いて出られる
	Input.action_press("move_forward")
	var t := 0.0
	while t < 12.0 and p.global_position.z > -3.5:   # 入口の塀（z -2.9〜-1.3）を越えるところまで、まっすぐ
		await physics_frame
		t += 1.0 / 60.0
	Input.action_release("move_forward")
	_check(main.region == "alley" and p.global_position.z < -3.3, "まっすぐ歩くと、アーチを抜けて路地へ出られる（%.1f 秒、z=%.2f）" % [t, p.global_position.z])
	_check(absf(p.global_position.y - (-13.6)) < 0.25, "1 階の地面の高さを歩いている（y=%.2f）" % p.global_position.y)

	# ---------------------------------------------------------------- 路地を歩いて自動販売機へ（途中の壁・電柱で止まらない）
	var vm: Node3D = main.room.exterior.vending_machine
	_check(vm != null and absf(vm.global_position.x - 2.6) < 0.01 and absf(vm.global_position.y - (-13.6)) < 0.01, "ベランダ（x 1.3〜3.7）の真下に自動販売機がある（x=%.1f）" % vm.global_position.x)
	p.rotation.y = -PI * 0.5   # +x を向く
	Input.action_press("move_forward")
	t = 0.0
	while t < 8.0 and p.global_position.x < 2.2:
		await physics_frame
		t += 1.0 / 60.0
	Input.action_release("move_forward")
	_check(p.global_position.x > 2.0, "路地を東へ歩いて、自動販売機の前まで行ける（x=%.2f z=%.2f）" % [p.global_position.x, p.global_position.z])

	# ---------------------------------------------------------------- 自動販売機：身長が足りない／届く
	p.global_position = Vector3(2.6, -13.55, -3.3)
	p.set_eye_height(1.4)
	_aim(p, vm.global_position + Vector3(0, 1.45, 0))
	await physics_frame
	await physics_frame
	var vt = p.get_focused(true)
	_check(vt != null and String(vt.get_meta("interact_id", "")) == "vending" and main._prompt_for(vt) == "左クリック：自動販売機を使う", "自動販売機を狙うと「自動販売機を使う」")
	main.hud._message_label.text = ""
	main._on_interact_requested(vt)
	_check(main.hud._message_label.text == main.ENDING["vending_far"] and not main.vending_done and main.inventory.has("yen100"), "身長 140 cm では最上段のボタンに届かない。百円玉は減らない")
	p.set_eye_height(1.5)
	main._on_interact_requested(vt)
	await create_timer(0.8).timeout
	_check(main.vending_busy and not main.vending_done and main.inventory.has("yen100"), "購入の演出中は、百円玉はまだ手元にある（途中で保存しても、買い直せる）")
	var mid: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	_check(Array(mid.get("inventory", [])).has("yen100") and not bool(mid.get("vending_done", false)), "演出の途中で保存しても、百円玉は残り、購入は済んでいない")
	var guard := 0
	while not main.cleared and guard < 600:
		await physics_frame
		guard += 1
	_check(main.cleared and main.clear_route == "true" and main.hud._clear_menu.visible and main.vending_done and not main.inventory.has("yen100"), "飲むと「真のクリア」（百円玉は、ここで減る）")
	_check((main.hud._clear_menu.get_node("Center/Box").get_child(0) as Label).text == "真のクリア", "クリア画面の見出し")
	p.set_eye_height(1.5)

	# ---------------------------------------------------------------- 1 階と 5 階が、上下でそろっている
	var ent: Node3D = main.room.get_node("Entrance")
	_check(absf(ent.position.x - (-1.85)) < 0.01 and absf(ent.position.y - (-13.6)) < 0.01 and absf(ent.rotation.y - PI) < 0.001, "1 階の入口は、廊下のエレベーターと同じ x の真下（%s）" % ent.position)
	_check(Corridor.X0 < -1.85 and -1.85 < Corridor.X1, "入口の x は、廊下の幅（x %.1f〜%.1f）の中にある" % [Corridor.X0, Corridor.X1])
	# ---------------------------------------------------------------- 浴室がせり上がっても、1 階の入口・箱は動かない
	main = await _fresh()
	var ent2: Node3D = main.room.get_node("Entrance")
	var car2: Node3D = main.room.get_node("ElevatorCar")
	var e0 := ent2.position
	var c0 := car2.position
	main.room.rise_unit(main.player, true)
	_check(ent2.position.is_equal_approx(e0) and car2.position.is_equal_approx(c0), "浴室がせり上がっても、1 階の入口とエレベーターの箱は動かない")
	print("ENDING TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
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
