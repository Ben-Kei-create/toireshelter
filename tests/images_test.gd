extends SceneTree
## ユーザーの画像（assets/textures/props/）の読み込み・透過・番号の対応・貼った場所の自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/images_test.gd
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s   %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _corner_transparent(t: Texture2D) -> bool:
	var img := t.get_image()
	return img.get_pixel(1, 1).a < 0.1 and img.get_pixel(img.get_width() - 2, img.get_height() - 2).a < 0.1


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var apt = main.room.apartment
	var MK = main.room.apartment.MeshKit
	var MJ = main.MahjongGame
	# --- 麻雀牌：34 種＋裏がそろい、透過があり、縦横比がゆがんでいない（0.55〜0.85）
	var ok_all := true
	var ratios_ok := true
	var alpha_ok := true
	for k in 34:
		var t: Texture2D = load("res://assets/textures/props/mj_%d.png" % k)
		ok_all = ok_all and t != null
		if t:
			var r := float(t.get_width()) / t.get_height()
			ratios_ok = ratios_ok and r > 0.55 and r < 0.85
			alpha_ok = alpha_ok and _corner_transparent(t)
	check(ok_all, "麻雀牌の画像が 34 種そろっている")
	check(ratios_ok, "牌の縦横比が保たれている")
	check(alpha_ok, "牌の角は透過")
	check(load("res://assets/textures/props/mj_back.png") != null, "牌の裏の画像がある")
	# 番号の対応：牌の名前（内部の番号）と、画像の絵（ここでは名前の文字種）
	var names := ["一萬", "二萬", "三萬", "四萬", "五萬", "六萬", "七萬", "八萬", "九萬", "一筒", "二筒", "三筒", "四筒", "五筒", "六筒", "七筒", "八筒", "九筒", "一索", "二索", "三索", "四索", "五索", "六索", "七索", "八索", "九索", "東", "南", "西", "北", "白", "發", "中"]
	var names_ok := true
	for k in 34:
		names_ok = names_ok and MJ.tile_name(k) == names[k]
	check(names_ok, "牌の番号と名前の対応（0〜8 萬、9〜17 筒、18〜26 索、27〜30 風、31〜33 三元）")
	# 索子の 2 と 3 は、ユーザーの個別画像（2 本、3 本）：二索の画像は二索の比率（幅広）、三索は縦長
	var t2: Texture2D = load("res://assets/textures/props/mj_19.png")
	var t3: Texture2D = load("res://assets/textures/props/mj_20.png")
	check(t2.get_width() > t3.get_width() * 1.05, "二索（19）と三索（20）は、渡された個別画像（比率が違う）")
	# --- 画像の読み込み
	var files := ["wall_clock_face", "intercom_standby", "peephole_view", "teddy_face", "ufo_coin_face", "radio_front", "tissue_top", "tissue_side", "egg_label", "aquarium_bg", "card_back", "card_s_A", "card_h_K"]
	for i in 12:
		files.append("calendar_%02d" % (i + 1))
	for i in 4:
		files.append("aquarium_plant_%d" % (i + 1))
		files.append("game_cover_%d" % (i + 1))
		files.append("sticker_card_%d" % (i + 1))
	for i in 3:
		files.append(["jacket_kotatsu_mahjong", "jacket_chika_nanadan", "jacket_rusu_record"][i])
	var miss := []
	for f in files:
		if not ResourceLoader.exists("res://assets/textures/props/%s.png" % f):
			miss.append(f)
	check(miss.is_empty(), "画像がそろっている %s" % str(miss))
	# --- 貼った場所
	check(apt.get_node("TvCorner").find_children("GameCover*", "Node3D", false, false).size() == 7, "ソフトのケース 7 つが台の前の床にある")
	for i in 7:
		check(main.MESSAGES.has("game_cover_%d" % (i + 1)), "ケース%d を調べられる" % (i + 1))
	for i in 8:
		check(main.MESSAGES.has("book_new_%d" % (i + 1)) and ResourceLoader.exists("res://assets/textures/props/book_new_%d.png" % (i + 1)), "床の本%d（画像と文章）" % (i + 1))
	for i in 4:
		check(main.MESSAGES.has("record_jacket_%d" % (i + 1)) and ResourceLoader.exists("res://assets/textures/props/lp_%d.png" % (i + 1)), "ジャケット%d（画像と文章）" % (i + 1))
	check(apt.kitchen.get_node("Door_upper").get_node_or_null("DoorPoster") != null and apt.kitchen.get_node("Door_lower").get_node_or_null("DoorPoster") == null, "冷凍室の扉（上）にだけポスター、下の扉にはシール（扉ごとに別の絵）")
	check(apt.get_node("SmallProps").get_node("NewBooks1").get_child_count() == 4 and apt.get_node("SmallProps").get_node("NewBooks2").get_child_count() == 4, "床の本が 4 冊ずつ 2 か所")
	check(apt.record_player.find_children("Jacket*", "Node3D", false, false).size() == 4, "レコードのジャケットが 4 枚")
	var door = apt.kitchen.get_node("Door_lower")
	check(door.get_node_or_null("StickerCard") != null and apt.kitchen.get_node("Door_upper").get_node_or_null("StickerCard") == null, "冷蔵庫将軍のシールは冷蔵室の扉（下）に貼ってあり、扉といっしょに動く（上の扉には貼らない）")
	check(apt.get_node("Gem").get_node_or_null("StickerCard") != null, "石焼き大魔王のシールが台座にある")
	check(apt.get_node("Bed").get_node_or_null("StickerCard") != null, "留守番天使のシールが寝床の壁にある")
	check(apt.get_parent().get_node("Exterior/Duct").get_node_or_null("StickerCard") != null, "配管仙人のシールが管の中にある")
	# --- 洋風トランプ：種類別 4 シートの 52 枚。内部の番号（種類×ランク）と絵が対応している
	var SP = main.SmallPropsScript
	var card_ok := true
	var card_ratio_ok := true
	for suit in ["s", "h", "d", "c"]:
		for rk in ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]:
			var ct = load("res://assets/textures/props/card_%s_%s.png" % [suit, rk])
			card_ok = card_ok and ct != null
			if ct:
				var cr: float = float(ct.get_width()) / ct.get_height()
				card_ratio_ok = card_ratio_ok and cr > 0.55 and cr < 0.8 and _corner_transparent(ct)
	check(card_ok, "トランプの表 52 枚がそろっている")
	check(card_ratio_ok, "トランプの縦横比が保たれ、角が透過")
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 99
	r2.seed = 99
	var draw_ok := true
	for i in 200:
		var nm: String = SP.draw_card(r1)
		var su: String = SP.SUITS[r2.randi() % 4]
		var ra: String = SP.RANKS[r2.randi() % 13]
		var exp: String = "res://assets/textures/props/card_%s_%s.png" % [su.substr(0, 1), ra]
		draw_ok = draw_ok and SP.last_card.resource_path == exp and nm == "%sの%s" % [SP.SUIT_NAMES[su], ra]
	check(draw_ok, "引いた札の名前と表示する絵が、種類とランクで一致する（200 回）")
	check(load("res://assets/textures/props/card_back.png") != null, "裏面は採用済みの画像のまま")
	# --- 時計：針のない文字盤（針は実際の時刻で動く）
	var face: Texture2D = load("res://assets/textures/props/wall_clock_face.png")
	check(face != null and absf(float(face.get_width()) / face.get_height() - 1.0) < 0.03 and _corner_transparent(face), "針なしの文字盤（ほぼ正円、角は透過）")
	var clk = apt.wall_clock
	check(clk.hour_hand != null and clk.minute_hand != null and clk.second_hand != null and clk.time_text().contains("時"), "動く針と時刻の処理は維持されている")
	# --- 床の物：重ならない・浮かない・埋まらない・照準を邪魔しない
	var items := []   # [名前, 箱の幅, 箱の奥行き, 節点, 箱の厚み]
	for n in apt.get_node("TvCorner").find_children("GameCover*", "Node3D", false, false):
		var bx: MeshInstance3D = n.get_node("Case")
		items.append([n.name, (bx.mesh as BoxMesh).size.x if bx.mesh is BoxMesh else 0.12, 0.2, n, 0.012, bx])
	for g in 2:
		for n in apt.get_node("SmallProps").get_node("NewBooks%d" % (g + 1)).get_children():
			var bx2: MeshInstance3D = n.get_node("Body")
			var sz := (bx2.mesh as BoxMesh).size if bx2.mesh is BoxMesh else Vector3(0.13, 0.018, 0.17)
			items.append([n.name, sz.x, sz.z, n, sz.y, bx2])
	for n in apt.record_player.find_children("Jacket*", "Node3D", false, false):
		var bx3: MeshInstance3D = n.get_node("Sleeve")
		var sz3 := (bx3.mesh as BoxMesh).size if bx3.mesh is BoxMesh else Vector3(0.19, 0.004, 0.19)
		items.append([n.name, sz3.x, sz3.z, n, sz3.y, bx3])
	check(items.size() == 19, "床の物は 19（ケース7・本8・ジャケット4）")
	var polys := []
	for it in items:
		var nd: Node3D = it[3]
		var box: MeshInstance3D = it[5]
		var hw: float = it[1] * 0.5
		var hd: float = it[2] * 0.5
		var pts := PackedVector2Array()
		for c in [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]:
			var wp: Vector3 = box.global_transform * c
			pts.append(Vector2(wp.x, wp.z))
		polys.append(pts)
	var overlaps := []
	for i in polys.size():
		for j in range(i + 1, polys.size()):
			if not Geometry2D.intersect_polygons(polys[i], polys[j]).is_empty():
				overlaps.append("%s×%s" % [items[i][0], items[j][0]])
	check(overlaps.is_empty(), "床の物どうしが重ならない %s" % str(overlaps))
	var floats := []
	for it in items:
		var box2: MeshInstance3D = it[5]
		var bottom: float = box2.global_position.y - float(it[4]) * 0.5
		if bottom < -0.002 or bottom > 0.0145:
			floats.append("%s(%.3f)" % [it[0], bottom])
	check(floats.is_empty(), "床の物が浮いたり埋まったりしていない（底が床 0 かじゅうたん 0.0125 の上）%s" % str(floats))
	var space3: PhysicsDirectSpaceState3D = main.player.get_world_3d().direct_space_state
	var buried := []
	for it in items:
		var box3: MeshInstance3D = it[5]
		var shape := BoxShape3D.new()
		shape.size = Vector3(float(it[1]) - 0.01, 0.02, float(it[2]) - 0.01)
		var qp := PhysicsShapeQueryParameters3D.new()
		qp.shape = shape
		qp.transform = Transform3D(box3.global_transform.basis, Vector3(box3.global_position.x, 0.04, box3.global_position.z))
		qp.collision_mask = 1 | 16
		if not space3.intersect_shape(qp, 1).is_empty():
			buried.append(it[0])
	check(buried.is_empty(), "床の物が家具や壁に重なっていない %s" % str(buried))
	var blocked := []
	for it in items:
		var box4: MeshInstance3D = it[5]
		var top := Vector3(box4.global_position.x, 1.5, box4.global_position.z)
		var q := PhysicsRayQueryParameters3D.create(top, Vector3(top.x, 0.0, top.z), main.player.ray.collision_mask)
		q.collide_with_areas = true
		var h: Dictionary = space3.intersect_ray(q)
		var hid := String(h.collider.get_meta("interact_id", "")) if h.has("collider") else ""
		if not (hid.begins_with("game_cover_") or hid.begins_with("book_new_") or hid.begins_with("record_jacket_")):
			blocked.append("%s→%s" % [it[0], hid])
	check(blocked.is_empty(), "真上から狙うと、それぞれの物を調べられる（他の判定にさえぎられない）%s" % str(blocked))
	# --- 電子レンジ：吊り戸棚の上、調べるだけ、台所の他の設備に触れない
	check(apt.kitchen.get_node("Door_upper").get_node_or_null("DoorFront") != null and apt.kitchen.get_node("Door_lower").get_node_or_null("DoorFront") != null, "冷蔵庫の上下の扉に、それぞれ別の正面の絵が貼ってあり、扉といっしょに動く")
	check(ResourceLoader.exists("res://assets/textures/props/fridge_door_upper.png") and ResourceLoader.exists("res://assets/textures/props/fridge_door_lower.png") and ResourceLoader.exists("res://assets/textures/props/microwave_front.png"), "冷蔵庫の扉 2 枚と電子レンジの正面の画像がある")
	var mw: Node3D = apt.kitchen.get_node("Microwave")
	check(mw.get_node_or_null("FrontPicture") != null, "電子レンジの正面に絵が貼ってある")
	check(mw != null and mw.get_node("MicrowaveArea").get_meta("interact_id") == "microwave" and main.MESSAGES["microwave"] == "電子レンジ。中には何も入っていない。", "電子レンジがあり、調べると「中には何も入っていない」")
	check(mw.global_position.y - 0.13 >= 2.0 and mw.global_position.y + 0.13 <= 2.4, "電子レンジは吊り戸棚の上で、天井に収まる")
	check(mw.find_children("*", "CollisionObject3D", true, false).filter(func(c): return c is StaticBody3D).is_empty(), "電子レンジに体の当たり判定はない（設備の操作を妨げない）")
	# 4 本の既存の台所の判定（流し・コンロ・冷蔵庫・扉）がそのまま
	var ids: Array = apt.kitchen.find_children("*", "Area3D", true, false).map(func(a): return String(a.get_meta("interact_id", "")))
	check(ids.has("fridge_upper") and ids.has("fridge_lower") and ids.has("fridge_inside") and ids.has("microwave"), "冷蔵庫の扉・中と電子レンジの判定がそろっている")
	print("failures: %d" % failures)
	quit(1 if failures > 0 else 0)
