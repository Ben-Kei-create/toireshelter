extends SceneTree
## 下を見たときに「透けて」何も無い所がないかの確認（ベランダ・廊下・窓の前）。
## 外の見た目だけの面（当たり判定のないもの）にも一時的に当たり判定を付け、いろいろな位置から斜め下へレイを撃ち、
## 何にも当たらず抜けていく向き（＝空の下半分が見えてしまう所）を数える。
## 実行: Godot --headless --path . --script res://tests/void_test.gd
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s   %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and not (n.get_parent() is Label3D):
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var meshes := []
	_collect(main.room, meshes)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 10
	body.collision_mask = 0
	main.add_child(body)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh is QuadMesh or mi.get_parent().name == "Glass" or mi.name == "Glass":
			continue   # 看板や窓ガラスなどの薄い板は穴を隠すものとして数えない
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.global_transform = mi.global_transform
		body.add_child(cs)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var spots := {
		"ベランダ中央": Vector3(2.5, 1.5, -1.8), "ベランダ左": Vector3(1.5, 1.5, -1.8), "ベランダ右": Vector3(3.5, 1.5, -1.8),
		"廊下の北": Vector3(-2.0, 1.5, -0.5), "廊下の中ほど": Vector3(-2.0, 1.5, 2.8), "廊下の南": Vector3(-2.0, 1.5, 5.6),
	}
	for name in spots:
		var from: Vector3 = spots[name]
		var misses := 0
		var first := ""
		for pitch in range(-85, -4, 10):
			for yaw in range(0, 360, 10):
				var dir := Vector3(0, 0, -1).rotated(Vector3.RIGHT, deg_to_rad(pitch)).rotated(Vector3.UP, deg_to_rad(yaw))
				var q := PhysicsRayQueryParameters3D.create(from, from + dir * 400.0, 1 << 10)
				if space.intersect_ray(q).is_empty():
					misses += 1
					if first.is_empty():
						first = "pitch %d yaw %d" % [pitch, yaw]
		check(misses == 0, "%s から斜め下 5〜85° の全方向で何かに当たる（抜ける向き %d%s）" % [name, misses, "：" + first if misses > 0 else ""])
	# 路地の地面：ベランダの前から向かいの建物の足元まで、真上から見て地面（上面 y -13.6＝1 階。5 階の 4 階ぶん下）がある（深い道まで抜けない）
	var gaps := []
	for x in range(-3, 8):
		for zi in range(0, 14):
			var z := -2.3 - zi * 0.15 - 0.02 * zi
			var q2 := PhysicsRayQueryParameters3D.create(Vector3(x + 0.5, 1.0, z), Vector3(x + 0.5, -30.0, z), 1 << 10)
			var h: Dictionary = space.intersect_ray(q2)
			# 下の階のベランダの床（-3.4〜-10.2）や手すりは途中にあってよいが、最終的に路地の面（-13.6 付近）で受けること
			var q3 := PhysicsRayQueryParameters3D.create(Vector3(x + 0.5, -12.0, z), Vector3(x + 0.5, -40.0, z), 1 << 10)   # 庇（y -8）より下から撃つ
			var h3: Dictionary = space.intersect_ray(q3)
			if h3.is_empty() or absf(h3.position.y - (-13.6)) > 0.3:
				gaps.append(Vector3(x + 0.5, h3.position.y if not h3.is_empty() else -99.0, z))
	check(gaps.is_empty(), "路地の地面（ベランダ前〜向かいの建物の足元、x -3〜8）に穴がない（穴 %d）%s" % [gaps.size(), str(gaps.slice(0, 3))])
	print("VOID TEST: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)
