extends SceneTree
## シャワーのホース：つながったひも（物理）。ヘッドを持って歩くと、ホースが追いついてくる。長さを超えては行けない。
## 実行: Godot --headless --path . --script res://tests/hose_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	main.credits_enabled = false
	var tub = main.room.bathtub
	_check(tub._hose_pts.size() == tub.HOSE_N and tub._hose_segs.size() == tub.HOSE_N - 1, "ホースは、つながった点と筒でできている")
	var rest_end: Vector3 = tub._hose_pts[tub.HOSE_N - 1]
	_check(rest_end.distance_to(tub._hose_rest) < 0.01 and tub._hose_pts[0].distance_to(tub._hose_anchor) < 0.01, "掛けているときは、蛇口の側とヘッドの側で止まっている")
	var mid_rest: Vector3 = tub._hose_pts[tub.HOSE_N / 2]
	_check(mid_rest.y < maxf(tub._hose_anchor.y, tub._hose_rest.y), "ホースは、重力でたるんでいる")
	# 持つ：ヘッドを遠くへ持っていく
	var cam: Camera3D = main.player.camera
	tub.hold_shower(cam)
	var p0: Vector3 = main.player.global_position
	main.player.global_position = tub.to_global(Vector3(-0.2, 0.0, 0.2))
	for i in 3:
		await process_frame
	var tail1: Vector3 = tub._hose_pts[tub.HOSE_N - 2]
	main.player.global_position = tub.to_global(Vector3(0.0, 0.0, 0.5))
	await process_frame
	var tail2: Vector3 = tub._hose_pts[tub.HOSE_N - 2]
	var mid_a: Vector3 = tub._hose_pts[tub.HOSE_N / 2]
	for i in 10:
		await process_frame
	var mid_b: Vector3 = tub._hose_pts[tub.HOSE_N / 2]
	_check(mid_a.distance_to(mid_b) > 0.005, "ヘッドを動かしたあと、ホースの真ん中は、少しあとから追いついてくる（%.3f m）" % mid_a.distance_to(mid_b))
	# 長さの上限
	main.player.global_position = tub.to_global(Vector3(-3.0, 0.0, 3.0))
	for i in 5:
		await process_frame
	var head_local: Vector3 = tub.to_local(tub.shower.global_position)
	_check(head_local.distance_to(tub._hose_anchor) <= tub.HOSE_LEN + 0.01, "ホースの長さより遠くへは、ヘッドを持っていけない（%.2f m）" % head_local.distance_to(tub._hose_anchor))
	# 戻す
	tub.release_shower()
	for i in 90:
		await process_frame
	_check((tub._hose_pts[tub.HOSE_N - 1] as Vector3).distance_to(tub._hose_rest) < 0.01, "戻すと、ホースの先は、もとの掛けた場所にもどる")
	print("HOSE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
