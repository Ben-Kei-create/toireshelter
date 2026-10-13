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
	print("failures: %d" % failures)
	quit(1 if failures > 0 else 0)
