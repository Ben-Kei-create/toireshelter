extends SceneTree
## 浴室の経年感（汚れ・傷）・環境音・雑貨スタンド・額が、操作や判定に影響しないことの確認。
## 実行: Godot --headless --path . --script res://tests/wear_test.gd
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s   %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _count(n: Node, cls: Array) -> int:
	var c := 0
	for ch in n.get_children():
		for k in cls:
			if is_instance_of(ch, k):
				c += 1
		c += _count(ch, cls)
	return c


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var wear: Node = main.room.get_node("BathWear")
	check(wear != null, "BathWear がある")
	var decals := 0
	for g in ["Walls", "Floor", "Fixtures"]:
		decals += wear.get_node(g).get_child_count()
	check(decals == 14, "壁9・床3・設備2＝14 枚の汚れ／傷（%d 枚）" % decals)
	var pivot: Node3D = main.room.mirror_cabinet.door_pivot
	var prints := 0
	for c in pivot.get_children():
		if str(c.name).begins_with("Wear08_"):
			prints += 1
	check(prints == 2, "鏡の扉の指紋が扉の子として 2 枚（開閉に付いて動く）")
	var wear_areas := _count(wear, [CollisionObject3D, CollisionShape3D, Area3D])
	check(wear_areas == 3, "汚れ・傷・影・額に当たり判定と調べる判定がない（あるのはトイレ用スリッパの調べる判定 1 つだけ：%d）" % wear_areas)
	check(wear.get_node("OverheadPicture/Picture") != null, "俯瞰の額がある")
	var shade: Node = wear.get_node("ContactShade")
	check(shade.get_child_count() == 14, "接地影の帯12と丸い影2（%d）" % shade.get_child_count())
	for n in ["Walls", "Floor", "Fixtures"]:
		for d in wear.get_node(n).get_children():
			if (d as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				check(false, "%s は影を落とさない" % d.name)
	var snd: Node = main.room.get_node("AmbientSound")
	check(snd.get_node("VentHum").stream.get_length() > 0.9, "換気扇の音がある")
	check(snd.get_node("AlleyMurmur").stream.get_length() > 1.9, "遠くの路地の音がある")
	check(snd.get_node("Drip").stream.get_length() > 0.2, "しずくの音がある")
	var props: Node = main.room.apartment.get_node("Novelties")
	check(props.get_child_count() == 3, "机の雑貨スタンドが 3 つ")
	check(_count(props, [CollisionObject3D, Area3D]) == 0, "雑貨スタンドに当たり判定・調べる判定がない")
	var tv: Node = main.room.apartment.get_node("TvCorner")
	check(tv.get_node("Tv/Screen") != null and tv.get_node("Console") != null and tv.get_node("Game05") != null, "テレビ・ゲーム機・ソフト5本がある")
	var tv_areas := tv.find_children("*", "Area3D", true, false)
	check(tv_areas.size() == 12 and tv_areas.filter(func(a): return a.get_meta("interact_id") == "tv_play").size() == 3 and tv_areas.filter(func(a): return String(a.get_meta("interact_id")).begins_with("game_case_")).size() == 5 and tv_areas.filter(func(a): return String(a.get_meta("interact_id")).begins_with("game_cover_")).size() == 4, "テレビ台まわりの判定は、ゲームを始める3つ（テレビ・ゲーム機・コントローラ）とソフトのケース5つ、床のケース4つ（調べるだけ）")
	check(main.room.apartment.get_node("HallSlippers") != null and wear.get_node("BathSlippers") != null, "スリッパが玄関ホールと浴室にある")
	var lp: Node = main.room.apartment.get_node("LifePapers")
	var ids := []
	for c in lp.get_children():
		if c is Area3D:
			ids.append(String(c.get_meta("interact_id")))
	ids.sort()
	check(ids == ["life_paper_02", "life_paper_07"], "生活小物の紙は 02 と 07 の2つで、調べる判定がある（%s）" % str(ids))
	for id in ids:
		check(main.MESSAGES.has(id), "%s の説明文がある" % id)
	check(main.MESSAGES["life_paper_02"] == "古い映画の再上映。半券を捨てずに取ってある。", "02 の文章が指定どおり")
	check(main.MESSAGES["life_paper_07"] == "石好きの会。ここなら話が合いそうだ。", "07 の文章が指定どおり")
	check(_count(lp, [StaticBody3D, CharacterBody3D, RigidBody3D]) == 0, "生活小物の紙に体を止める判定がない")
	print("WEAR TEST: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)
