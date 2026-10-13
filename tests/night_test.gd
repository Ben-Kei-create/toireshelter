extends SceneTree
## タンクのコイン・コイン制のクレーンゲーム・釣れたコイン・ベランダの置き物・24時のインターホン・扉の内側（のぞき穴・ミニポスト）の自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/night_test.gd
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s   %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var apt = main.room.apartment
	var toilet = main.room.toilet
	var ufo = apt.ufo_catcher
	# --- タンクのコイン
	check(toilet.coin_root.visible and toilet.coin_area.collision_layer == 0, "コインはタンクの底にあり、蓋が閉まっているあいだは狙えない")
	check(toilet.coin_root.position.y > 0.8 and toilet.coin_root.position.y < 0.9 and toilet.coin_root.position.x > -0.9 and toilet.coin_root.position.x < -0.7, "コインはタンクの中の浮き球の上にある")
	toilet.toggle_tank()
	await create_timer(1.8).timeout
	check(toilet.tank_open and toilet.coin_area.collision_layer == 2, "蓋を外すとコインを狙える")
	check(main.PROMPTS[toilet.get_prompt("tank_coin")] == "左クリック：コインを拾う", "「コインを拾う」の案内")
	# 照準（レイ）でも、蓋を外したタンクの中のコインを狙える
	var player = main.player
	player.set_physics_process(false)
	player.global_position = Vector3(-0.3, 0.0, 0.5)   # タンクの横（z 0.5）から。体が入れる位置
	var d: Vector3 = toilet.coin_root.global_position - player.camera.global_position
	player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	player.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await physics_frame
	await physics_frame
	var tgt = player.get_focused(true)
	check(tgt != null and String(tgt.get_meta("interact_id", "")) == "tank_coin", "照準でタンクの中のコインを狙える（横に立った目の高さから）")
	check(player.is_space_free(Vector3(-0.3, 0.0, 0.5), 1.6), "その立ち位置は体が入る")
	player.set_physics_process(true)
	# --- コイン制のクレーンゲーム
	check(ufo.coin_check.is_valid() and main.coin_count == 0, "クレーンゲームはコインが要る（最初は 0 枚）")
	check(ufo.interact("ufo_catcher") == "ufo_no_coin" and not ufo.busy, "コインがないと動かない")
	var key: String = toilet.interact("tank_coin")
	check(key == "coin_pickup" and main.coin_count == 1 and main.inventory.has("ufo_coin") and not toilet.coin_root.visible, "コインを拾うと持ち物に入る")
	check(toilet.coin_area.collision_layer == 0 and toilet.interact("tank_coin") == "", "コインは1枚だけ（2回は拾えない）")
	check(main.item_name("ufo_coin") == "UFOコイン×1" and main.inventory.size() == 1, "持ち物の名前に枚数が出る")
	main.add_coin(2)
	check(main.coin_count == 3 and main.inventory.size() == 1 and main.item_name("ufo_coin") == "UFOコイン×3", "コインは1つの欄にまとまる")
	main.coin_count = 1
	check(ufo.interact("ufo_catcher") == "ufo_miss" and main.coin_count == 0 and not main.inventory.has("ufo_coin"), "遊ぶと1枚へる。0 枚になると欄から消える")
	# --- 釣れたコイン
	var f = main.fishing
	var before: int = main.coin_count
	var coin_entry: Array = f.CATCHES.filter(func(c): return c.size() > 4 and c[4] == "coin")[0]
	f._land(coin_entry)
	check(main.coin_count == before + 1 and f.placed.size() == 0, "コインが釣れたら持ち物に入り、ベランダには置かれない")
	# --- ベランダの置き物
	var tops: Array = f.CATCHES.filter(func(c): return c.size() <= 4)
	for i in 8:
		f._place(tops[i * 2])
	var solid_count: int = f.placed.filter(func(p): return p.solid).size()
	check(f.placed.size() == 8 and solid_count == 5, "釣った物は順にベランダへ置かれ、当たり判定は最大 5 個（%d個）" % solid_count)
	var solids := 0
	for p in f.placed:
		solids += (p.node as Node3D).find_children("Solid", "StaticBody3D", true, false).size()
	check(solids == 5, "当たり判定の実体も 5 個だけ（%d）" % solids)
	var in_range := true
	for p in f.placed:
		var q: Vector3 = p.node.position
		in_range = in_range and q.x >= 1.55 and q.x <= 3.15 and q.z >= -2.05 and q.z <= -1.4 and q.y < 0.1
	check(in_range, "置き場所はベランダの床の上（室外機・窓の前の通路は外す）")
	var first_solid: Dictionary = f.placed[0]
	check(first_solid.node.position.z <= -1.88, "当たり判定のある物は手すりぎわ（体の通り道を塞がない）")
	var area_id: String = "catch_%d" % f.placed[7].id
	check(f.get_prompt(area_id) == "catch_look" and f.interact(area_id) == "fishing_text" and f.last_text.contains(f.placed[7].name), "置き物を調べると名前と説明が出る")
	for i in 20:
		f._place(tops[i % tops.size()])
	check(f.placed.size() <= 24, "置き物は 24 個まで（古い物から消える：%d）" % f.placed.size())
	# --- 24 時のインターホン
	var ic = apt.intercom
	check(not ic.rang and not ic.visitor_present and ic.position.z > 2.3 and ic.position.x < 0.9 and ic.position.x > -0.9, "インターホンは玄関ホールの奥の壁（出口のそば）にある")
	check(main.PROMPTS[ic.get_prompt("intercom")] == "左クリック：調べる" and ic.interact("intercom") == "intercom_idle", "ふだんは画面が暗い")
	# 点滅のあとで元の明るさに戻ることを確かめるため、いまの明るさを記録
	var energies := {}
	for l in main.room.find_children("*", "Light3D", true, false):
		if (l as Light3D).light_energy > 0.0:
			energies[l] = (l as Light3D).light_energy
	var lamp: Light3D = apt.get_node("RoomLightOwn")
	check(front_mail_hidden(main), "ふだんは受け箱に封筒はない")
	ic.ring()
	check(ic.rang and ic.visitor_present and ic.interact("intercom") == "intercom_visitor", "鳴ると人影が映る")
	check(main.room.front_door.mail_envelope.visible, "鳴ったあと、受け箱に封筒が入る")
	var dark_seen := false
	var bright_seen := false
	for i in 80:
		await process_frame
		if lamp.light_energy < 0.01:
			dark_seen = true
		elif dark_seen and lamp.light_energy > 0.3:
			bright_seen = true
	check(dark_seen and bright_seen, "明かりが消えたり点いたりする（点滅）")
	await create_timer(0.6).timeout
	var restored := true
	for l in energies:
		if is_instance_valid(l) and absf((l as Light3D).light_energy - float(energies[l])) > 0.02 and l != main.room.sky_clock:
			restored = false
	check(restored and ic._saved.is_empty(), "1 秒ほどで、すべての明かりが元の明るさに戻る")
	check(main.MESSAGES.has("intercom_idle") and main.MESSAGES.has("intercom_visitor") and main.MESSAGES.has("intercom_after"), "インターホンの文章")
	# 時刻の判定：0:00:00 でだけ鳴る
	ic.rang = false
	ic._last_key = ""
	var t: Dictionary = Time.get_datetime_dict_from_system()
	check(not (t.hour == 0 and t.minute == 0 and t.second <= 1) or ic.rang, "24 時以外は鳴らない（いまは %d:%02d）" % [t.hour, t.minute])
	# --- のぞき穴
	var door = main.room.front_door
	check(door.peephole_area.get_meta("interact_id") == "peephole" and door.mail_area.get_meta("interact_id") == "mail_catcher", "扉の部屋側に、のぞき穴と受け箱の判定がある")
	check(door.peephole_area.get_parent() == door.pivot and door.mail_area.get_parent() == door.pivot, "どちらも扉についている（扉といっしょに動く）")
	main._on_interact_requested(door.peephole_area)
	check(main.peeping and main.hud.is_peephole_open() and not main.player.controls_enabled, "のぞき穴を調べると、ぼんやりした景色の画面が開く")
	var tex: ImageTexture = ic.peephole_texture()
	var img := tex.get_image()
	check(img.get_width() == 160 and img.get_pixel(0, 0).v < 0.02 and img.get_pixel(40, 80).v > 0.1, "景色は丸く切り抜かれ（角は黒）、壁は明るい")
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	main._unhandled_input(ev)
	check(not main.peeping and not main.hud.is_peephole_open() and main.player.controls_enabled, "Esc で閉じる")
	# 人影は 24 時台だけ（トイレなどでも、24 時台以外には人影のメッセージは出ない）
	ic.visitor_present = false
	ic.hour_override = 14
	check(not ic.figure_visible(), "午後 2 時台は、のぞき穴に人影は見えない")
	var empty_img: Image = ic.peephole_texture().get_image()
	main._open_peephole()
	check(main.hud._message_label.text.contains("誰もいない") and not main.hud._message_label.text.contains("人影"), "24 時台以外にのぞくと「誰もいない」（人影のメッセージは出ない）")
	main._close_peephole()
	ic.hour_override = 0
	check(ic.figure_visible(), "24 時台は、鳴っていなくても人影が見える")
	var vis_img: Image = ic.peephole_texture().get_image()
	check(empty_img.get_pixel(80, 90).v > vis_img.get_pixel(80, 90).v + 0.1, "人影がいると、中央が暗く映る")
	main._open_peephole()
	check(main.hud._message_label.text.contains("人影"), "24 時台にのぞくと人影のメッセージ")
	main._close_peephole()
	ic.hour_override = 23
	check(not ic.figure_visible(), "23 時台は見えない")
	ic.visitor_present = true
	check(ic.figure_visible(), "鳴った直後の 25 秒は、時刻に関係なく見える")
	ic.hour_override = -1
	ic.rang = true
	main._on_interact_requested(door.mail_area)
	check(main.hud._message_label.text.contains("封筒"), "鳴ったあとの受け箱には封筒がある")
	print("night_test: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)


func front_mail_hidden(main) -> bool:
	return not main.room.front_door.mail_envelope.visible
