extends Node3D
## 隠しお酒のセラー（透明なガラスの扉）。浴室（トイレ）が持ち上がると現れる、柱（ペデスタル）のホール側の壁の中のセラー。
## もし手前に出っぱった物なら、持ち上がる前から見えてしまうので、壁の中にはめ込み、表面がほんの少し出るだけ（出っぱり 0.03）。床にはつかず、宙に浮いた高さに付く。
## 原点は、壁の面の、セラーの左下。ローカル +z が前（ホール側）。幅 1.0・高さ 0.42。変なラベルの瓶と缶が、横に 6 本ならんでいる。
## 絵は assets/textures/liquor/liquor_01〜06.png（透明な背景）。電気が止まると、中の明かりも消える（LiquorLight。room.gd の set_power）。
## ただの飾りで、謎解きには関わらない。
##   ・コルク銃（射的）で撃つと、ガラスにヒビが入る（add_crack）。ヒビは増えるが、割れはしない。
##   ・割れるのは、一人麻雀で「九蓮宝燈」を出したときだけ（break_glass）。
##   ・割れても、割れていなくても、瓶を調べて出るのは説明だけ。割れたあとは、何を調べても「お酒は20歳になってから。」。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")
const DIR := "res://assets/textures/liquor/"

const W := 1.0
const H := 0.42
const D := 0.03
const MAX_CRACKS := 12
## 横にならべる順：[番号, 高さ]。幅は、絵の縦横比のまま。すき間は、全体の幅に合わせて等しく開ける
const ITEMS := [[1, 0.31], [2, 0.26], [3, 0.34], [4, 0.35], [5, 0.33], [6, 0.3]]
const SHELF_Y := 0.035

var broken := false
var cracks := 0
var _glass: MeshInstance3D
var _crack_root: Node3D
var _shards: Node3D


func _ready() -> void:
	name = "LiquorCellar"
	MeshKit.auto_round = false
	var wood := MeshKit.mat("cellar_wood", Color(0.2, 0.12, 0.08), 0.55)
	var back := MeshKit.mat("cellar_back", Color(0.06, 0.08, 0.08), 0.35, 0.3)
	var glass := MeshKit.mat("cellar_glass", Color(0.78, 0.9, 0.95, 0.14), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var steel := MeshKit.mat("cellar_steel", Color(0.7, 0.72, 0.75), 0.3, 0.85)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	MeshKit.shape_box(body, Vector3(W + 0.07, H + 0.07, D), Vector3(W * 0.5, H * 0.5, D * 0.5))
	# 枠（柱の面にはめ込んだ縁取り）：左右・上・下
	var t := 0.035
	var fd := D + 0.006   # 縁の出っぱり（壁の面から）
	MeshKit.box(self, Vector3(t, H + 2.0 * t, fd), Vector3(-t * 0.5, H * 0.5, fd * 0.5), wood, "FrameL")
	MeshKit.box(self, Vector3(t, H + 2.0 * t, fd), Vector3(W + t * 0.5, H * 0.5, fd * 0.5), wood, "FrameR")
	MeshKit.box(self, Vector3(W, t, fd), Vector3(W * 0.5, H + t * 0.5, fd * 0.5), wood, "FrameTop")
	MeshKit.box(self, Vector3(W, t, fd), Vector3(W * 0.5, -t * 0.5, fd * 0.5), wood, "FrameBottom")
	MeshKit.box(self, Vector3(W, H, 0.01), Vector3(W * 0.5, H * 0.5, 0.006), back, "Back")
	# ガラスの棚（瓶の足元に 1 枚）
	MeshKit.box(self, Vector3(W - 0.02, 0.006, D - 0.012), Vector3(W * 0.5, SHELF_Y - 0.005, (D - 0.012) * 0.5 + 0.006), glass, "GlassShelf")
	# 中の明かり：上の裏の細い帯と、点光源
	var led := MeshKit.mat("cellar_led", Color(0.9, 0.95, 1.0), 0.4)
	led.emission_enabled = true
	led.emission = Color(0.85, 0.93, 1.0)
	led.emission_energy_multiplier = 1.3
	MeshKit.box(self, Vector3(W - 0.1, 0.006, 0.01), Vector3(W * 0.5, H - 0.012, D - 0.01), led, "Led")
	var l := OmniLight3D.new()
	l.name = "LiquorLight"
	l.position = Vector3(W * 0.5, H * 0.5, D + 0.22)
	l.light_color = Color(0.85, 0.93, 1.0)
	l.light_energy = 0.7
	l.omni_range = 1.3
	add_child(l)
	# 瓶と缶（絵の板）：横に 6 本、幅いっぱいにならべる
	var widths := []
	var total := 0.0
	for it in ITEMS:
		var tex: Texture2D = load(DIR + "liquor_%02d.png" % int(it[0]))
		widths.append(float(it[1]) * float(tex.get_width()) / float(tex.get_height()))
		total += float(widths[-1])
	# 幅におさまらなければ、全部を同じ割合で小さくする（すき間は最低 1.5cm）
	var avail := W - 0.04 - 0.015 * float(ITEMS.size() - 1)
	var k := minf(1.0, avail / total)
	total *= k
	var gap := (W - 0.04 - total) / float(ITEMS.size() - 1)
	var x := 0.02
	for i in ITEMS.size():
		var w: float = float(widths[i]) * k
		_bottle(int(ITEMS[i][0]), x + w * 0.5, float(ITEMS[i][1]) * k)
		x += w + gap
	# ガラスの扉（ほぼ透明）。ヒビと割れは、ここに出る
	_glass = MeshKit.box(self, Vector3(W, H, 0.006), Vector3(W * 0.5, H * 0.5, D - 0.003), glass, "GlassDoor")
	MeshKit.box(self, Vector3(0.012, 0.3, 0.016), Vector3(W - 0.05, H * 0.5, D + 0.006), steel, "Handle")
	_crack_root = Node3D.new()
	_crack_root.name = "Cracks"
	add_child(_crack_root)
	_shards = Node3D.new()
	_shards.name = "Shards"
	add_child(_shards)
	var area := MeshKit.interact_area(self, "CellarArea", "liquor_cellar")
	MeshKit.shape_box(area, Vector3(W, H, 0.05), Vector3(W * 0.5, H * 0.5, D + 0.02))
	MeshKit.auto_round = true


func _bottle(n: int, cx: float, h: float) -> void:
	var tex: Texture2D = load(DIR + "liquor_%02d.png" % n)
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var mi := MeshInstance3D.new()
	mi.name = "Liquor%d" % n
	mi.mesh = q
	mi.material_override = m
	mi.position = Vector3(cx, SHELF_Y + 0.004 + h * 0.5, D * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var area := MeshKit.interact_area(self, "LiquorArea%d" % n, "liquor_%d" % n)
	MeshKit.shape_box(area, Vector3(w, h, 0.04), mi.position + Vector3(0, 0, 0.04))


## 射的で当たった所（世界の座標）に、ヒビを入れる。割れはしない。返り値：ヒビの数（割れていれば -1）。
func add_crack(world_point: Vector3) -> int:
	if broken:
		return -1
	if cracks >= MAX_CRACKS:
		return cracks
	var lp := to_local(world_point)
	_draw_crack(Vector2(clampf(lp.x, 0.05, W - 0.05), clampf(lp.y, 0.05, H - 0.05)), cracks)
	cracks += 1
	Sfx.play("crack", 1.6, -4.0)
	return cracks


func _draw_crack(c: Vector2, seed_n: int) -> void:
	var mat := MeshKit.mat("cellar_crack", Color(0.92, 0.96, 1.0, 0.85), 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.9, 1.0)
	mat.emission_energy_multiplier = 0.7
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + seed_n * 31
	var n := rng.randi_range(5, 7)
	for k in n:
		var a := TAU * k / n + rng.randf_range(-0.3, 0.3)
		var len := rng.randf_range(0.05, 0.17)
		var seg := MeshKit.box(_crack_root, Vector3(len, 0.003, 0.002), Vector3(c.x + cos(a) * len * 0.5, c.y + sin(a) * len * 0.5, D + 0.002), mat, "Crack")
		seg.rotation.z = a
		if rng.randf() < 0.6:   # 枝わかれ
			var a2 := a + rng.randf_range(-0.8, 0.8)
			var l2 := len * rng.randf_range(0.3, 0.5)
			var e := Vector2(c.x + cos(a) * len, c.y + sin(a) * len)
			var br := MeshKit.box(_crack_root, Vector3(l2, 0.0025, 0.002), Vector3(e.x + cos(a2) * l2 * 0.5, e.y + sin(a2) * l2 * 0.5, D + 0.002), mat, "CrackBranch")
			br.rotation.z = a2
	var ring := MeshKit.cylinder(_crack_root, 0.012, 0.002, Vector3(c.x, c.y, D + 0.002), mat, "Impact", -1.0, 10)
	ring.rotation.x = PI * 0.5


## 一人麻雀で九蓮宝燈を出したとき：ガラスが割れる（破片が下へ落ちる）。
func break_glass(instant := false) -> void:
	if broken:
		return
	broken = true
	_glass.visible = false
	_crack_root.visible = false
	var shard_mat := MeshKit.mat("cellar_shard", Color(0.82, 0.92, 0.97, 0.45), 0.1)
	shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in 16:
		var shard := MeshKit.box(_shards, Vector3(rng.randf_range(0.03, 0.09), rng.randf_range(0.02, 0.07), 0.003), Vector3(rng.randf_range(0.05, W - 0.05), rng.randf_range(0.05, H - 0.05), D), shard_mat, "Shard")
		var land := Vector3(rng.randf_range(0.0, W), 0.0, D + rng.randf_range(0.0, 0.4))
		land.y = -position.y + 0.004   # 床（世界の y 0）。セラーは宙に浮いた高さに付いている
		if instant:
			shard.position = land
			shard.rotation = Vector3(PI * 0.5, rng.randf_range(0, TAU), 0)
		else:
			var tw := create_tween().set_parallel(true)
			var dur := rng.randf_range(0.5, 0.9)
			tw.tween_property(shard, "position", land, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(shard, "rotation", Vector3(PI * 0.5, rng.randf_range(0, TAU), rng.randf_range(-1, 1)), dur)
	if not instant:
		Sfx.play("crack", 1.0)
		await get_tree().create_timer(0.15).timeout
		Sfx.play("crack", 0.7)
		await get_tree().create_timer(0.25).timeout
		Sfx.play("clunk", 1.5, -4.0)


## 保存からの復元（演出なし。すでに同じ状態なら何もしない）。
func restore(p_broken: bool, p_cracks: int) -> void:
	for i in range(cracks, p_cracks):
		_draw_crack(Vector2(0.15 + 0.1 * (i % 6), 0.2 + 0.1 * (i / 6)), i)
	cracks = maxi(cracks, p_cracks)
	if p_broken and not broken:
		break_glass(true)
