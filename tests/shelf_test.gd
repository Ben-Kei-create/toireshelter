extends SceneTree
## 本棚の本の重なりを、MultiMesh の各本の実際の外形（変換後の箱）で調べる（FIX-12）。
## 実行: Godot --headless --path . --script res://tests/shelf_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var apt = current_scene.room.apartment
	var shelf: Node3D = apt.get_node("Bookshelf")
	var mmi: MultiMeshInstance3D = shelf.get_node("Books")
	var mm := mmi.multimesh
	var unit := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	var boxes := []
	for i in mm.instance_count:
		boxes.append(mmi.global_transform * mm.get_instance_transform(i) * unit)
	var covers := []
	for n in shelf.get_children():
		if n.name.begins_with("Book") and n is Node3D and n.name != "Books":
			covers.append([n.name, _aabb(n)])
	var hit_cover := 0
	var hit_book := 0
	var outside := 0
	var examples := []
	var lo: float = -1.1 + 0.0125
	var hi: float = 2.3 - 0.0125
	for i in boxes.size():
		var a: AABB = (boxes[i] as AABB).grow(-0.0015)
		if a.position.z < lo or a.end.z > hi:
			outside += 1
		for c in covers:
			if a.intersects(c[1]):
				hit_cover += 1
				if examples.size() < 3:
					examples.append("本%d と %s" % [i, c[0]])
		for j in range(i + 1, boxes.size()):
			if a.intersects((boxes[j] as AABB).grow(-0.0015)):
				hit_book += 1
	print("本 %d 冊、表紙を見せた本 %d 冊" % [boxes.size(), covers.size()])
	_check(hit_cover == 0, "背表紙の本・横積みが表紙を見せた本の範囲に入らない（重なり %d 件 %s）" % [hit_cover, str(examples)])
	_check(hit_book == 0, "背表紙の本どうしが重ならない（%d 件）" % hit_book)
	_check(outside == 0, "本が本棚の側板の外へはみ出さない（%d 冊）" % outside)
	_check(boxes.size() >= 300, "物量感を保つ（%d 冊以上）" % 300)
	print("SHELF TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
