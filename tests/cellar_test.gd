extends SceneTree
## お酒のセラー：せり上がった浴室の下の柱の面にはめ込まれている。ただの飾り。射的でヒビだけ入り、割れない。九蓮宝燈で割れる。割れても「お酒は20歳になってから。」だけ。
## 動かない置物（射的でも動かない）と、ペタペタ貼ったシールの数も確かめる。
## 実行: Godot --headless --path . --script res://tests/cellar_test.gd

const Mahjong := preload("res://scripts/mahjong_game.gd")
const FigureArt := preload("res://scripts/figure_art.gd")
var _failures := 0


func _initialize() -> void:
	_run()


func _fresh() -> Node:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var m := current_scene
	m.credits_enabled = false
	return m


func _run() -> void:
	var main = await _fresh()
	var room = main.room
	var player = main.player
	_check(room.wine_cellar == null, "浴室がせり上がる前は、セラーはない（まだ柱が現れていない）")
	room.rise_unit(player, true)
	await process_frame
	var cel: Node3D = room.wine_cellar
	_check(cel != null and absf(cel.global_position.z - 1.28) < 0.01, "せり上がると、柱のホール側の面（z 1.28）にセラーが現れる（%s）" % (cel.global_position if cel else "なし"))
	_check(cel.get_node("Liquor1") != null and cel.get_node("Liquor6") != null and cel.get_node("LiquorLight") != null, "瓶と缶が 6 本、中の明かりがある")
	var ys := {}
	var xs := []
	for n in 6:
		var b := cel.get_node("Liquor%d" % (n + 1)) as MeshInstance3D
		ys[snappedf(b.position.y - (b.mesh as QuadMesh).size.y * 0.5, 0.001)] = true
		xs.append(b.position.x)
	_check(ys.size() == 1 and xs == xs.duplicate() and xs[0] < xs[5], "6 本は、横に 1 列にならんでいる（足元の高さがそろう）")
	_check(cel.global_position.y > 0.2 and cel.D <= 0.04, "床にはつかず（高さ %.2f）、壁から出っぱるのはほんの少し（%.2f m）" % [cel.global_position.y, cel.D])
	# 調べる（ただの飾り：説明だけ）
	for id in ["liquor_cellar", "liquor_1", "liquor_2", "liquor_3", "liquor_4", "liquor_5", "liquor_6"]:
		var node: Node = cel.get_node("CellarArea") if id == "liquor_cellar" else cel.get_node("LiquorArea" + id.substr(7))
		main._on_interact_requested(node)
		_check(main.hud._message_label.text == main.LIQUOR[id], "調べると説明が出る（%s）" % id)
	_check(main.inventory.is_empty() and not main.progress.discovered.has("liquor_1"), "取れる物はなく、謎解きにも関わらない")
	# 電気：停電中は、中の明かりも消える
	await create_timer(1.0).timeout
	_check(cel.get_node("LiquorLight").light_energy < 0.01, "停電中は、中の明かりが消えている")
	room.set_power(true, true)
	_check(cel.get_node("LiquorLight").light_energy > 0.3, "電気が戻ると、明かりがつく")
	# 射的：ヒビだけ入り、割れない
	main.add_item("cork_gun")
	main.select_item(main.inventory.find("cork_gun"))
	var area: Node = cel.get_node("CellarArea")
	for i in 14:
		player.global_position = Vector3(-0.3, 0.0, 1.9)
		var tp: Vector3 = cel.to_global(Vector3(0.08 + 0.07 * (i % 12), 0.06 + 0.03 * (i % 8), cel.D + 0.02))
		_aim(player, tp)
		await physics_frame
		await physics_frame
		main._gun_cool = 0.0
		main._fire(area)
		await physics_frame
	_check(cel.cracks == cel.MAX_CRACKS and not cel.broken, "撃つとヒビが増える（%d 本・上限 %d）が、割れはしない" % [cel.cracks, cel.MAX_CRACKS])
	_check(cel.get_node("Cracks").get_child_count() > 10 and cel.get_node("GlassDoor").visible, "ヒビの線が見え、ガラスはそのまま")
	# 九蓮宝燈：割れる
	var mj = Mahjong.new(3)
	main.mahjong = mj
	mj.start()
	var tiles := [0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 8]
	mj.hand = tiles
	mj.drawn = 4
	mj._finish_win()
	_check(mj.yaku == ["九蓮宝燈"] and mj.points == 32000, "九蓮宝燈の和了（役満 %d 点）" % mj.points)
	var not_chuuren := Mahjong.new(5)
	not_chuuren.start()
	not_chuuren.hand = [0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 9]
	not_chuuren.drawn = 4
	_check(not Mahjong.is_chuuren(Mahjong._counts(not_chuuren.hand + [not_chuuren.drawn])), "ほかの色が混ざると、九蓮宝燈にならない")
	main._check_chuuren()
	await create_timer(0.3).timeout
	_check(cel.broken and room.cellar_broken and not cel.get_node("GlassDoor").visible, "九蓮宝燈を出すと、セラーのガラスが割れる")
	await create_timer(1.6).timeout
	_check(main.hud._message_label.text == main.LIQUOR["broken"] and main.LIQUOR["broken"] == "お酒は20歳になってから。", "出るのは「お酒は20歳になってから。」だけ")
	main.hud._message_label.text = ""
	main._on_interact_requested(cel.get_node("LiquorArea3"))
	_check(main.hud._message_label.text == "お酒は20歳になってから。", "割れたあとは、瓶を調べても同じ")
	_check(main.inventory.has("cork_gun") and main.inventory == ["cork_gun", "medal"], "割れても、瓶から取れる物は何もない（出るのは九蓮宝燈のメダルだけ）")
	# 保存と復元
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	var st: Dictionary = snap.get("stage3", {})
	_check(bool(st.get("cellar_broken")) and int(st.get("cellar_cracks", 0)) == cel.MAX_CRACKS, "保存に、割れた・ヒビの数が入る")
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	_check(main.room.wine_cellar != null and main.room.wine_cellar.broken and main.room.cellar_broken, "復元しても、割れたまま")
	# セラーができる前に九蓮宝燈を出しても、あとで割れた姿で現れる
	main = await _fresh()
	main.room.break_wine_cellar()
	main.room.rise_unit(main.player, true)
	await process_frame
	_check(main.room.wine_cellar.broken, "柱が現れる前に割れていれば、割れた姿で現れる")
	# 置物とシール
	main = await _fresh()
	var orn: Node = main.room.apartment.get_node("Ornaments")
	_check(orn.get_child_count() == 9, "動かない置物が 9 点（机の上 6・カーテンの前 3）")
	var o1: Node3D = orn.get_child(0)
	var before := o1.position
	var tgt: Node = o1.get_node("OrnamentArea")
	main.add_item("cork_gun")
	main.select_item(main.inventory.find("cork_gun"))
	main._gun_cool = 0.0
	main._fire(tgt)
	_check(o1.position.is_equal_approx(before) and main.room.apartment.figures_down == 0, "射的で撃っても、置物は動かない")
	var stickers: Array = main.room.find_children("FigureSticker*", "MeshInstance3D", true, false)
	_check(stickers.size() == 39 and FigureArt.ORNAMENTS.size() + FigureArt.STICKERS.size() == 48, "置物 9 点・シール 39 枚（合わせて 48 点の絵を使い切る。シール %d 枚）" % stickers.size())
	print("CELLAR TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
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
