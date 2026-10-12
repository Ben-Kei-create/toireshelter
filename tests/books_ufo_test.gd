extends SceneTree
## 本棚の本を読む・クレーンゲームの自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/books_ufo_test.gd
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
	var player = main.player
	# --- 本を読む
	var areas: Node = apt.get_node("Bookshelf/BookAreas")
	var covers := 0
	var levels := 0
	for a in areas.get_children():
		var id := String(a.get_meta("interact_id"))
		if id.begins_with("book_"):
			covers += 1
		elif id == "shelf_books":
			levels += 1
	check(covers == 12 and levels == 4, "表紙の本12冊と背表紙の段4つに判定がある（%d・%d）。残り3冊（13〜15）は本棚の上" % [covers, levels])
	check(main.PROMPTS["book_read"] == "左クリック：本を読む", "案内「左クリック：本を読む」")
	var ok_all := true
	for n in range(1, 16):
		ok_all = ok_all and apt.books.COVERS.has(n) and apt.books.COVERS[n][1].size() == 3 and not String(apt.books.COVERS[n][0]).is_empty()
	check(ok_all, "表紙の本15冊すべてに題名と3ページの文章がある")
	check(apt.books.SPINES.size() >= 30, "背表紙の本の一節が30以上ある")
	# 狙って読む：表紙の本 → 3ページ → 閉じる
	player.global_position = Vector3(3.0, 0.05, 0.2)
	main.reading = false
	apt.books.interact("book_04")
	check(main.reading and main.hud.is_reader_open() and not player.controls_enabled and main._reader_title == "引力のない辞典", "表紙の本を読むと本の画面が開き、操作が止まる")
	check(main._reader_pages.size() == 3 and main._reader_page == 0, "3ページの1ページ目")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	await process_frame
	main._unhandled_input(click)
	check(main._reader_page == 1 and main.reading, "左クリックで次のページ")
	main._unhandled_input(click)
	main._unhandled_input(click)
	check(not main.reading and not main.hud.is_reader_open() and player.controls_enabled, "最後のページの次で閉じて、操作が戻る")
	apt.books.interact("shelf_books")
	check(main.reading and main._reader_pages.size() == 1, "背表紙の本は1ページの一節")
	await process_frame
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	main._unhandled_input(esc)
	check(not main.reading and not main.paused, "Esc は読書画面を閉じるだけで、一時停止にならない")
	# 実際に照準（レイ）で狙える：棚の前、約1.2m 離れた目の高さから、表紙の本15冊がそれぞれの判定に当たる。
	# 背表紙の段の判定や本棚の本体に邪魔されない。クレーンゲームの正面にある本には、斜めの位置から狙う
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var mask: int = player.ray.collision_mask
	var aimed := 0
	var wrong := []
	for n in range(1, 13):
		var area: Node3D = areas.get_node("Book%02d" % n)
		var c: Vector3 = area.get_child(0).global_position
		# 目の位置の候補（棚から 1.1m、横に 0.5〜1.2m ずらす）のどれかで当たればよい（大きな家具の陰になる位置があるため）
		var id := "なし"
		for dz in [0.6, -0.6, 1.2, -1.2, 0.9, -0.9]:
			var eye := Vector3(c.x - 1.1, 1.75, c.z + dz)
			var q := PhysicsRayQueryParameters3D.create(eye, eye + (c - eye).normalized() * 2.4, mask)
			q.collide_with_areas = true
			var hit: Dictionary = space.intersect_ray(q)
			id = String(hit.collider.get_meta("interact_id", "")) if hit.has("collider") else "なし"
			if id == "book_%02d" % n:
				break
		if id == "book_%02d" % n:
			aimed += 1
		else:
			wrong.append("%02d→%s" % [n, id])
	check(aimed == 12, "表紙の本12冊を照準で狙える（%d冊。外れ %s）" % [aimed, str(wrong)])
	# 背表紙の段：本の無い所を狙うと shelf_books
	var lv: Node3D = areas.get_node("Level2")
	var lc: Vector3 = lv.get_child(0).global_position
	var eye2 := Vector3(lc.x - 1.1, 1.75, lc.z + 0.7)
	var q2 := PhysicsRayQueryParameters3D.create(eye2, eye2 + (Vector3(lc.x, lc.y, lc.z) - eye2).normalized() * 2.4, mask)
	q2.collide_with_areas = true
	var h2: Dictionary = space.intersect_ray(q2)
	var id2 := String(h2.collider.get_meta("interact_id", "")) if h2.has("collider") else "なし"
	check(id2 == "shelf_books" or id2.begins_with("book_"), "背表紙の段を狙うと本を読める判定に当たる（%s）" % id2)
	# --- クレーンゲーム
	var ufo = apt.ufo_catcher
	check(ufo.get_prompt("ufo_catcher") == "ufo_play" and main.PROMPTS.has("ufo_play"), "クレーンゲームを狙うと「アームを動かす」")
	var msgs := []
	for k in 3:
		var key: String = ufo.interact("ufo_catcher")
		msgs.append(key)
		check(ufo.busy and ufo.get_prompt("ufo_catcher") == "", "遊んでいる間は調べられない（%d回目）" % (k + 1))
		await create_timer(9.0).timeout
		check(not ufo.busy, "遊び終わる（%d回目）" % (k + 1))
	check(msgs == ["ufo_miss", "ufo_miss", "ufo_win"], "3回目につかめる（%s）" % str(msgs))
	check(ufo.taken == 1, "景品が1つ取り出し口に落ちた")
	check(main.MESSAGES.has("ufo_miss") and main.MESSAGES.has("ufo_win") and main.MESSAGES.has("ufo_empty"), "結果の文章がある")
	check(player.is_space_free(Vector3(4.7, 0.0, 0.0), 1.4), "押入れの前に立てる")
	# 押入れ：襖が左に寄っている間はクレーンゲームが見え、右へ寄せるとふとんが見える（クレーンゲームは襖に隠れる）
	var closet = apt.closet
	var space2: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var aim := func() -> String:
		var from := Vector3(5.07, 1.5, 0.6)
		var to := Vector3(5.07, 1.0, -0.8)
		var q := PhysicsRayQueryParameters3D.create(from, from + (to - from).normalized() * 2.4, 1 | 2)
		q.collide_with_areas = true
		var h: Dictionary = space2.intersect_ray(q)
		return String(h.collider.get_meta("interact_id", "")) if h.has("collider") else "なし"
	check(closet.crane_visible and aim.call() == "ufo_catcher", "押入れの襖が左に寄っていて、右にクレーンゲームが見える（照準：%s）" % aim.call())
	check(main.PROMPTS.has(closet.get_prompt("fusuma")), "襖の案内がある")
	closet.interact("fusuma")
	await create_timer(1.0).timeout
	check(not closet.crane_visible and aim.call() == "fusuma", "襖を右へ寄せると、クレーンゲームは襖に隠れる（照準：%s）" % aim.call())
	closet.interact("fusuma")
	await create_timer(1.0).timeout
	check(closet.crane_visible and aim.call() == "ufo_catcher", "もう一度寄せると、また見える")
	check(apt.ufo_catcher == closet.ufo and closet.get_node("UfoCatcher").global_position.x > 4.9, "クレーンゲームは押入れの中（x %.2f）にある" % closet.get_node("UfoCatcher").global_position.x)
	check(main.inventory.is_empty(), "景品は持ち物にならない（取得なし）")
	print("BOOKS UFO TEST: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)
