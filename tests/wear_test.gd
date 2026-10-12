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
	check(_count(wear, [CollisionObject3D, CollisionShape3D, Area3D]) == 0, "汚れ・傷・影・額に当たり判定と調べる判定がない")
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
	print("WEAR TEST: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)
