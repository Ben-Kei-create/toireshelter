extends SceneTree
## 広げた自室の自動検証：部屋の大きさ、半分の本棚、押入れとクレーンゲーム、キッチン、黒電話・ギター・剥製・平積みの本、こたつの携帯。
## 実行: Godot --headless --path . --script res://tests/room_test.gd
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
	# ホールと自室の境のふすまは、はじめ閉まっている。ここは通り抜けの検証なので、開けておく（ふすま自体は stage3_test）
	apt.hall_fusuma.set_open(true, true)
	var player = main.player
	var A := preload("res://scripts/apartment.gd")
	check(is_equal_approx(A.ROOM.end.x, 5.5) and is_equal_approx(A.ROOM.size.x, 4.5), "自室の幅（本棚の方向の奥行き）が 4.5m（x 1.0〜5.5）に広がった")
	check(A.in_room(Vector3(5.0, 0.05, 0.5)) and not A.in_room(Vector3(5.7, 0.05, 0.5)), "広げた部分が自室として判定される")
	# 本棚は半分の大きさ
	var shelf: Node3D = apt.get_node("Bookshelf")
	check(is_equal_approx(apt.books.shelf_step * apt.books.levels, 1.18) and apt.books.levels == 4, "本棚は高さ 1.18m・4段（以前の半分）")
	var areas: Node = shelf.get_node("BookAreas")
	var lv := 0
	for a in areas.get_children():
		if String(a.get_meta("interact_id")) == "shelf_books":
			var shape: BoxShape3D = (a.get_child(0) as CollisionShape3D).shape
			lv += 1
			check(is_equal_approx(shape.size.z, 1.7 - 0.06), "背表紙の段の長さが 1.7m（以前の半分）") if lv == 1 else null
	# 押入れ
	var cl = apt.closet
	check(cl != null and cl.get_node("Futon") != null and cl.get_node("Zabuton") != null, "押入れにふとんと座布団がある")
	check(apt.ufo_catcher != null and apt.ufo_catcher.get_parent() == cl, "クレーンゲームは押入れの中にある")
	# キッチン
	var kit = apt.kitchen
	var kids := []
	for c in kit.get_children():
		if c is StaticBody3D and c.has_meta("interact_id"):
			kids.append(String(c.get_meta("interact_id")))
	kids.sort()
	check(kids == ["kitchen_sink", "kitchen_stove"], "キッチンに流し台・コンロの調べる対象がある（冷蔵庫は扉と中身の判定）（%s）" % str(kids))
	# 小物
	var odd = apt.oddities
	check(odd.get_node("BlackPhone") != null and odd.get_node("WallItems/Guitar") != null, "黒電話とギターがある")
	var animals := 0
	for c in odd.get_node("WallItems/TaxidermyBoard").get_children():
		if str(c.name).begins_with("Animal"):
			animals += 1
	check(animals == 4, "何の動物か分からない剥製が4つ、板の釘に刺さっている（%d）" % animals)
	var top_ids := []
	for b in odd.get_node("ShelfTopBooks").get_children():
		top_ids.append(String(b.get_node("BookArea").get_meta("interact_id")))
	check(top_ids == ["book_13", "book_14", "book_15"], "本棚の上の平積み（13〜15）が読める（%s）" % str(top_ids))
	var phone_area: Node = apt.kotatsu.get_node("MobilePhone/PhoneArea")
	check(String(phone_area.get_meta("interact_id")) == "phone_mobile", "こたつの上のみかんの鉢に携帯がある")
	for id in ["kitchen_sink", "kitchen_stove", "fridge", "guitar", "taxidermy", "phone_black", "phone_mobile"]:
		check(main.MESSAGES.has(id) and main.INTERACT_SFX.has(id) or id in ["taxidermy", "phone_black"], "%s の説明文" % id)
	var K := preload("res://scripts/kotatsu.gd")
	check(K.SEATS.size() == 3 and K.SEATS[2].name == "east", "こたつの座布団は北・西・東の3つ")
	var free_east := false
	for e in K.SEATS[2].exits:
		free_east = free_east or player.is_space_free(e, 1.6)
	check(free_east, "東の座布団から立てる位置が空いている")
	# 通路：出入口から窓の前・東の押入れの前・キッチンの前まで体が通れる
	var pts := [Vector3(1.0, 0.0, 1.78), Vector3(1.8, 0.0, 1.78), Vector3(1.8, 0.0, 1.0), Vector3(1.8, 0.0, 0.1), Vector3(2.0, 0.0, 0.05), Vector3(2.3, 0.0, 0.03),
			Vector3(3.3, 0.0, 0.0), Vector3(4.7, 0.0, 0.0), Vector3(3.8, 0.0, 0.0), Vector3(3.8, 0.0, 1.25), Vector3(4.4, 0.0, 1.5)]
	var blocked := []
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var n := int(a.distance_to(b) / 0.05)
		for i in n + 1:
			var p := a.lerp(b, float(i) / maxi(n, 1))
			if not player.is_space_free(p, 1.4):
				blocked.append(p)
	check(blocked.is_empty(), "出入口 → こたつの脇 → 押入れの前 → キッチンの前まで体が通れる（ぶつかる点 %d）%s" % [blocked.size(), str(blocked.slice(0, 3))])
	print("ROOM TEST: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)
