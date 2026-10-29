extends SceneTree
## 玄関ドア・廊下・脱出の経路の確認：浴室のドアを直して開けた状態で、体（半径 0.25m）が
## 浴室 → 玄関ホール → 玄関ドア → 廊下 → エレベーターの前まで、実際に通れる（壁・開いたドアにぶつからない）こと。
## 実行: Godot --headless --path . --script res://tests/exit_test.gd
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
	var player = main.player
	var room = main.room
	room.front_door.locked = false   # 玄関ドアは、はじめ施錠（家の鍵で開く）。ここでは、開けた先の検証なので、開けておく（鍵は stage5_test）
	room.open_door()
	room.front_door.interact("front_door")
	await create_timer(1.6).timeout
	check(room.front_door.is_open, "玄関ドアが開いている")
	var pts := [Vector3(0.0, 0.0, 0.75), Vector3(0.0, 0.0, 1.5), Vector3(-0.6, 0.0, 1.85), Vector3(-1.2, 0.0, 1.85), Vector3(-1.8, 0.0, 1.85), Vector3(-2.2, 0.0, 1.85), Vector3(-2.2, 0.0, 5.7)]
	var blocked := []
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var n := int(a.distance_to(b) / 0.05)
		for i in n + 1:
			var p := a.lerp(b, float(i) / maxi(n, 1))
			if not player.is_space_free(p, 1.4):
				blocked.append(p)
	check(blocked.is_empty(), "浴室から玄関ドア・廊下・エレベーター前まで体が通れる（ぶつかる点 %d）%s" % [blocked.size(), str(blocked.slice(0, 3))])
	# 閉じたままの玄関ドアは通れない
	var main2 := current_scene
	check(not _closed_door_passable(room), "（確認）閉じた玄関ドアの開口には当たり判定がある")
	check(CorridorProbe.ok(), "廊下の区画判定が玄関の敷居の外から始まる")
	print("EXIT TEST: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)


func _closed_door_passable(room: Node) -> bool:
	return room.front_door.get_node("Pivot/Leaf").collision_layer == 0


class CorridorProbe:
	static func ok() -> bool:
		var C := preload("res://scripts/corridor.gd")
		return C.in_corridor(Vector3(-1.5, 0, 1.85)) and not C.in_corridor(Vector3(-0.95, 0, 1.85)) and not C.in_corridor(Vector3(0.0, 0, 1.85))
