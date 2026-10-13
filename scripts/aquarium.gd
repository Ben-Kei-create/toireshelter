extends Node3D
## 水槽（木の台の上の 80cm 水槽）。メダカ7匹は手前のガラスのそばを、アロワナ1匹は水面近くの上のほうを、それぞれ自動で泳ぐ。
## 原点は水槽の中心の床（部屋の x 4.5・z 0.55。押入れの前と、こたつ側に通路を残す。本棚の表紙（z 0.65 など）を手前の斜めから狙えるよう、棚とのあいだを 0.24m あけた）。長辺が x（0.8m）、奥行き z（0.38m）、前（見る側）は +z。台の高さ 0.7m、水面は 1.06m。
## 左クリックでえさをやる：魚がみな水面に集まり、薄片が沈みながら消える（10 秒）。
## 泳ぎ方は群れの計算なしの「ゾーンの中で目的地を決めて、向きをなめらかに変える」だけ（魚 8 匹・毎フレーム軽い計算のみ）。
## 判定：水槽と台の箱（体を止める。調べる対象 aquarium。fixture として get_prompt／interact を持つ）。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

const CENTER := Vector3(4.5, 0.0, 0.55)
const W := 0.8
const D := 0.38
const STAND_H := 0.7
const WATER_TOP := 1.06
const WATER_BOTTOM := 0.78
const FEED_TIME := 10.0

## 魚の泳ぐ範囲（水槽の中の座標）。メダカは手前（+z）のガラスのそば、アロワナは水面近くの上の層
const MEDAKA_ZONE := AABB(Vector3(-0.33, 0.80, 0.07), Vector3(0.66, 0.17, 0.08))
const AROWANA_ZONE := AABB(Vector3(-0.16, 0.96, -0.06), Vector3(0.32, 0.06, 0.1))

var fish: Array = []          # {node, tail, zone, speed, turn, target, vel, phase, kind}
var feed_left := 0.0
var _flakes: Array = []       # {node, vy}
var _bubbles: Array = []
var _plants: Array = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	position = CENTER
	_rng.seed = 4242
	MeshKit.auto_round = false
	_build_stand_and_tank()
	_build_decor()
	_build_fish()
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", "aquarium")
	body.set_meta("fixture", self)
	add_child(body)
	MeshKit.shape_box(body, Vector3(W + 0.04, 1.2, D + 0.04), Vector3(0, 0.6, 0))
	MeshKit.auto_round = true


func _build_stand_and_tank() -> void:
	var wood := MeshKit.tiled_mat("aquarium_wood", load("res://assets/textures/surfaces/surface_09.png"), 0.5, Color(0.55, 0.45, 0.38), 0.6)
	var black := MeshKit.mat("aquarium_black", Color(0.06, 0.06, 0.07), 0.4)
	MeshKit.box(self, Vector3(W + 0.02, STAND_H, D + 0.02), Vector3(0, STAND_H * 0.5, 0), wood, "Stand")
	for sx in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.006, STAND_H - 0.08, 0.004), Vector3(sx * 0.2, STAND_H * 0.5, D * 0.5 + 0.011), black, "DoorSeam")
		MeshKit.cylinder(self, 0.012, 0.012, Vector3(sx * 0.03 + 0.0, STAND_H * 0.55, D * 0.5 + 0.016), MeshKit.mat("aquarium_knob", Color(0.7, 0.65, 0.5), 0.3, 0.6), "Knob").rotation.x = PI * 0.5
	MeshKit.box(self, Vector3(0.006, STAND_H - 0.08, 0.004), Vector3(0, STAND_H * 0.5, D * 0.5 + 0.011), black, "DoorSeamMid")
	# 水槽：黒いフレーム（底・上）と角の柱、ガラス、水、背面の青い板
	var y0 := STAND_H
	var gh := 0.4
	MeshKit.box(self, Vector3(W + 0.02, 0.02, D + 0.02), Vector3(0, y0 + 0.01, 0), black, "FrameBottom")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MeshKit.box(self, Vector3(0.015, gh, 0.015), Vector3(sx * (W * 0.5 - 0.005), y0 + 0.02 + gh * 0.5, sz * (D * 0.5 - 0.005)), black, "Post")
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.95, 1.0, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gl := MeshKit.box(self, Vector3(W - 0.01, gh, D - 0.01), Vector3(0, y0 + 0.02 + gh * 0.5, 0), glass, "Glass")
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.45, 0.75, 0.85, 0.22)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.1
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wh := WATER_TOP - y0 - 0.02
	var wt := MeshKit.box(self, Vector3(W - 0.03, wh, D - 0.03), Vector3(0, y0 + 0.02 + wh * 0.5, 0), water, "Water")
	wt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var back := MeshKit.mat("aquarium_back", Color(0.12, 0.35, 0.45), 0.9)
	MeshKit.box(self, Vector3(W - 0.012, gh - 0.01, 0.003), Vector3(0, y0 + 0.02 + gh * 0.5, -D * 0.5 + 0.0045), back, "BackPanel")
	# 上のフタ（ライトつき）
	MeshKit.box(self, Vector3(W + 0.02, 0.02, D + 0.02), Vector3(0, y0 + 0.02 + gh + 0.01, 0), black, "Hood")
	var lamp := MeshKit.mat("aquarium_lamp", Color(0.9, 0.97, 1.0), 0.3)
	lamp.emission_enabled = true
	lamp.emission = Color(0.8, 0.95, 1.0)
	lamp.emission_energy_multiplier = 1.5
	MeshKit.box(self, Vector3(W - 0.1, 0.004, 0.06), Vector3(0, y0 + 0.02 + gh - 0.002, -0.02), lamp, "LightStrip")
	var light := OmniLight3D.new()
	light.name = "TankLight"
	light.position = Vector3(0, y0 + 0.3, 0.1)
	light.light_color = Color(0.7, 0.9, 1.0)
	light.light_energy = 0.6
	light.omni_range = 1.1
	light.shadow_enabled = false
	add_child(light)


func _build_decor() -> void:
	var sand := MeshKit.mat("aquarium_sand", Color(0.8, 0.72, 0.55), 1.0)
	var y0 := STAND_H + 0.02
	MeshKit.box(self, Vector3(W - 0.03, 0.045, D - 0.03), Vector3(0, y0 + 0.0225, 0), sand, "Sand")
	var rock := MeshKit.mat("aquarium_rock", Color(0.42, 0.4, 0.38), 0.9)
	for r in [[-0.22, 0.0, 0.05, 0.06], [-0.15, 0.06, 0.03, 0.05], [0.24, -0.04, 0.04, 0.07]]:
		var m := MeshKit.sphere(self, r[3], Vector3(r[0], y0 + 0.045 + r[3] * 0.4, r[1]), rock)
		m.scale = Vector3(1.2, 0.7, 0.9)
	var green := MeshKit.mat("aquarium_plant", Color(0.2, 0.55, 0.25), 0.8)
	var green2 := MeshKit.mat("aquarium_plant2", Color(0.3, 0.65, 0.3), 0.8)
	var spots := [[-0.3, -0.08], [-0.26, 0.1], [0.1, -0.11], [0.29, 0.08], [0.33, -0.1], [-0.05, -0.12]]
	for i in spots.size():
		var cl := Node3D.new()
		cl.name = "Plant%d" % i
		cl.position = Vector3(spots[i][0], y0 + 0.04, spots[i][1])
		add_child(cl)
		for k in 4:
			var h := 0.12 + 0.05 * ((i + k) % 3)
			var blade := MeshKit.box(cl, Vector3(0.012, h, 0.002), Vector3((k - 1.5) * 0.012, h * 0.5, 0), green if (i + k) % 2 == 0 else green2, "Blade")
			blade.rotation.y = k * 0.7
		_plants.append(cl)
	# ぶくぶく：左の奥のエアストーンから泡が昇る
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.9, 0.97, 1.0, 0.35)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 5:
		var b := MeshKit.sphere(self, 0.006 + 0.002 * (i % 2), Vector3(-0.36, y0 + 0.05, -0.12), bm)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bubbles.append({"node": b, "t": i * 0.45})
	MeshKit.cylinder(self, 0.012, 0.02, Vector3(-0.36, y0 + 0.055, -0.12), MeshKit.mat("aquarium_stone", Color(0.5, 0.5, 0.55), 0.8), "AirStone")


func _build_fish() -> void:
	# メダカ：橙が多め、白っぽいのが1匹。長さ約 3.5cm
	for i in 7:
		var col := Color(0.97, 0.55, 0.12) if i != 3 else Color(0.95, 0.93, 0.85)
		if i == 5:
			col = Color(0.98, 0.7, 0.2)
		var f := _make_fish("Medaka%d" % i, 0.016, 0.0065, 0.005, col, 0.012, false)
		_register(f, MEDAKA_ZONE, 0.075 + 0.02 * (i % 3), 5.0, "medaka")
	# アロワナ：細長い体、銀色に淡い赤み、背びれと尻びれが後ろへ長い。長さ約 32cm
	var a := _make_fish("Arowana", 0.15, 0.034, 0.022, Color(0.78, 0.8, 0.84), 0.07, true)
	_register(a, AROWANA_ZONE, 0.06, 1.2, "arowana")


## 魚1匹の体。前（+x）に頭、後ろに尾。a／b／c は体の半径（長さ・高さ・幅）。戻り値 {node, tail}。
func _make_fish(node_name: String, a: float, b: float, c: float, col: Color, tail_len: float, big: bool) -> Dictionary:
	var root := Node3D.new()
	root.name = node_name
	add_child(root)
	var body_mat := MeshKit.mat("fish_%s" % node_name, col, 0.3 if big else 0.5, 0.5 if big else 0.0)
	var body := MeshKit.sphere(root, 1.0, Vector3.ZERO, body_mat)
	body.scale = Vector3(a, b, c)
	var dark := MeshKit.mat("fish_eye", Color(0.02, 0.02, 0.03), 0.3)
	for sz in [-1.0, 1.0]:
		var eye := MeshKit.sphere(root, b * 0.28 if not big else 0.007, Vector3(a * 0.72, b * 0.25, sz * c * 0.7), dark)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(-a * 0.9, 0, 0)
	root.add_child(tail)
	var fin_col := col.lerp(Color(0.9, 0.35, 0.3), 0.5 if big else 0.1)
	var fin := MeshKit.box(tail, Vector3(tail_len, b * 1.4, 0.001), Vector3(-tail_len * 0.45, 0, 0), MeshKit.mat("fish_fin_%s" % node_name, fin_col, 0.6), "TailFin")
	fin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if big:
		var fin_m := MeshKit.mat("fish_fin_big", Color(0.85, 0.5, 0.5), 0.6)
		MeshKit.box(root, Vector3(0.1, 0.022, 0.001), Vector3(-0.07, b * 0.95, 0), fin_m, "DorsalFin")
		MeshKit.box(root, Vector3(0.12, 0.022, 0.001), Vector3(-0.05, -b * 0.95, 0), fin_m, "AnalFin")
		for sz in [-1.0, 1.0]:
			var pf := MeshKit.box(root, Vector3(0.03, 0.004, 0.012), Vector3(a * 0.35, -b * 0.5, sz * c * 1.1), fin_m, "PectoralFin")
			pf.rotation.y = sz * 0.5
			var bb := MeshKit.cylinder(root, 0.0015, 0.02, Vector3(a * 0.98, -b * 0.35, sz * 0.006), dark, "Barbel")
			bb.rotation.z = PI * 0.5
		MeshKit.sphere(root, 0.014, Vector3(a * 0.62, 0.0, 0.0), MeshKit.mat("fish_gill", Color(0.92, 0.65, 0.65), 0.4, 0.3)).scale = Vector3(0.9, 1.2, 1.2)
	else:
		MeshKit.box(root, Vector3(0.008, 0.005, 0.001), Vector3(-a * 0.3, b * 0.85, 0), MeshKit.mat("fish_dorsal", col.darkened(0.15), 0.6), "Dorsal")
	return {"node": root, "tail": tail}


func _register(f: Dictionary, zone: AABB, speed: float, turn: float, kind: String) -> void:
	var start := Vector3(zone.position.x + _rng.randf() * zone.size.x, zone.position.y + _rng.randf() * zone.size.y, zone.position.z + _rng.randf() * zone.size.z)
	f.node.position = start
	f.zone = zone
	f.speed = speed
	f.turn = turn
	f.kind = kind
	f.target = start
	f.vel = Vector3(speed, 0, 0)
	f.phase = _rng.randf() * TAU
	fish.append(f)


func _random_in(zone: AABB) -> Vector3:
	return Vector3(zone.position.x + _rng.randf() * zone.size.x, zone.position.y + _rng.randf() * zone.size.y, zone.position.z + _rng.randf() * zone.size.z)


func _process(delta: float) -> void:
	_t += delta
	if feed_left > 0.0:
		feed_left -= delta
	for f in fish:
		_swim(f, delta)
	for p in _plants:
		var i: int = _plants.find(p)
		(p as Node3D).rotation.z = sin(_t * 0.9 + i) * 0.06
		(p as Node3D).rotation.x = cos(_t * 0.7 + i * 1.3) * 0.05
	for b in _bubbles:
		b.t += delta * 0.35
		var k: float = fmod(b.t, 1.0)
		(b.node as Node3D).position = Vector3(-0.36 + sin(k * 14.0) * 0.004, STAND_H + 0.07 + k * (WATER_TOP - STAND_H - 0.08), -0.12)
	for fl in _flakes.duplicate():
		var n: Node3D = fl.node
		n.position.y -= fl.vy * delta
		n.rotation.y += delta
		if n.position.y < WATER_BOTTOM + 0.04 or feed_left <= 0.0:
			n.queue_free()
			_flakes.erase(fl)


func _swim(f: Dictionary, dt: float) -> void:
	var node: Node3D = f.node
	var zone: AABB = f.zone
	var pos := node.position
	var speed: float = f.speed
	var feeding := feed_left > 0.0
	if feeding:
		# 水面近くへ集まる（えさの落ちる中央あたり）
		var top := Vector3(_rng.randf_range(-0.12, 0.12), WATER_TOP - 0.03 - (0.0 if f.kind == "arowana" else _rng.randf() * 0.04), _rng.randf_range(-0.04, 0.12))
		if pos.distance_to(f.target) < 0.03 or f.target.y < WATER_TOP - 0.1:
			f.target = top
		speed *= 1.8
	elif pos.distance_to(f.target) < 0.035:
		f.target = _random_in(zone)
	var desired: Vector3 = (f.target - pos).normalized() * speed
	f.vel = (f.vel as Vector3).lerp(desired, 1.0 - exp(-float(f.turn) * dt))
	pos += f.vel * dt
	if not feeding:
		pos = Vector3(clampf(pos.x, zone.position.x, zone.end.x), clampf(pos.y, zone.position.y, zone.end.y), clampf(pos.z, zone.position.z, zone.end.z))
	else:
		pos = Vector3(clampf(pos.x, -0.35, 0.35), clampf(pos.y, WATER_BOTTOM, WATER_TOP - 0.02), clampf(pos.z, -0.15, 0.15))
	node.position = pos
	var v: Vector3 = f.vel
	if v.length() > 0.004:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(-v.z, v.x), clampf(6.0 * dt, 0.0, 1.0))
		node.rotation.z = lerp_angle(node.rotation.z, clampf(v.y / maxf(speed, 0.01), -1.0, 1.0) * 0.35, clampf(4.0 * dt, 0.0, 1.0))
	var amp := 0.5 if f.kind == "medaka" else 0.3
	(f.tail as Node3D).rotation.y = sin(_t * (14.0 if f.kind == "medaka" else 5.0) * (0.6 + v.length() / maxf(f.speed, 0.01) * 0.4) + f.phase) * amp


# ---------------------------------------------------------------- 調べる（fixture）

func get_prompt(_id: String) -> String:
	return "aquarium_feed"


## えさをやる。10 秒のあいだ魚が水面に集まる。
func interact(_id: String) -> String:
	if feed_left > 0.0:
		return "aquarium_full"
	feed_left = FEED_TIME
	Sfx.play("plop", 1.3, -6.0)
	var fm := MeshKit.mat("fish_food", Color(0.85, 0.7, 0.25), 0.8)
	for i in 8:
		var fl := MeshKit.box(self, Vector3(0.008, 0.001, 0.008), Vector3(_rng.randf_range(-0.1, 0.1), WATER_TOP - 0.01 - i * 0.012, _rng.randf_range(-0.04, 0.1)), fm, "Flake")
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flakes.append({"node": fl, "vy": 0.02 + _rng.randf() * 0.015})
	return "aquarium_fed"
