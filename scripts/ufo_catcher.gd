extends Node3D
## 超簡易のクレーンゲーム（自室の装飾。景品は取れても持ち帰れず、取得・脱出条件・謎には関係しない）。
## 原点は床の中心、ローカル +z が正面（遊ぶ側）。置くときに向きを回す。大きさ：幅0.5・奥行き0.5・高さ1.65m。
##
##   Cabinet … 下の箱（操作パネル：ボタンとレバー、取り出し口）。当たり判定（world）と調べる対象（ufo_catcher）を兼ねる
##   Glass   … ガラスの箱（半透明、当たり判定なし）。中に景品の絵（assets/textures/room/novelty_02・03・05・09・11・12、透過付き）
##   Claw    … 上のレールを動くアーム（運び台・ケーブル・3本爪）
##
## クリックすると 1 回遊ぶ（約5秒）：アームが景品の上へ動く → 降りる → 爪が閉じる → 上がる → 取り出し口の上へ → 離す。
## 3 回に 1 回ほど（疑似乱数・毎回同じ並び）つかめて、景品が取り出し口に落ちる。外れる回は、爪が景品から少しずれる。
## 景品は 6 つ。取り出し口に落ちた景品はそこに残る（見た目だけ）。6 つ取ったら「もうない」。
## 遊んでいる間は調べられない。一時停止中は止まる（Room の子）。再プレイで初期状態に戻る。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

const W := 0.5
const D := 0.5
const BASE_H := 0.58           # 下の箱の高さ（操作パネルまで）
const GLASS_TOP := 1.5
const TOTAL_H := 1.65
const FLOOR_Y := 0.62          # 景品の床
const HOME := Vector2(0.14, 0.14)   # アームの待機位置（右手前。x 右・z 前）
const OUTLET := Vector2(-0.14, 0.14)   # 取り出し口の上（左手前）
const CLAW_TOP_Y := 1.42
const CLAW_DOWN_Y := 0.88
const SUCCESS_EVERY := [true]   # コインは貴重なので、1 枚で必ず景品が出る（景品は固定順。main.gd が中身を決める）

var busy := false
var coin_check := Callable()   # 遊ぶ前に呼ぶ。コインを1枚使えたら true（main.gd が設定。なければ無料＝テスト用）
var plays := 0
var prizes: Array = []        # [{node, spot: Vector2, taken}]
var taken := 0
signal prize_won(index: int)   # 景品が取り出し口に落ちた（0 から数えた何個目か）
var claw: Node3D
var _cable: MeshInstance3D
var _prongs: Array = []
var _outlet_stack := 0


func _ready() -> void:
	MeshKit.auto_round = false
	_build_cabinet()
	_build_glass()
	_build_prizes()
	_build_claw()
	MeshKit.auto_round = true


func _build_cabinet() -> void:
	var body := StaticBody3D.new()
	body.name = "Cabinet"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", "ufo_catcher")
	body.set_meta("fixture", self)
	add_child(body)
	MeshKit.shape_box(body, Vector3(W, TOTAL_H, D), Vector3(0, TOTAL_H * 0.5, 0))
	var teal := MeshKit.mat("ufo_body", Color(0.2, 0.55, 0.62), 0.5)
	var dark := MeshKit.mat("ufo_dark", Color(0.1, 0.12, 0.15), 0.6)
	var pink := MeshKit.mat("ufo_pink", Color(0.9, 0.45, 0.6), 0.5)
	MeshKit.box(self, Vector3(W, BASE_H, D), Vector3(0, BASE_H * 0.5, 0), teal, "Base")
	# 操作パネル：手前の上の斜めの板。赤い大きなボタンと黒いレバー
	var panel := MeshKit.box(self, Vector3(W - 0.04, 0.02, 0.16), Vector3(0, BASE_H + 0.0, D * 0.5 - 0.06), dark, "Panel")
	panel.rotation.x = deg_to_rad(-12.0)
	var button := MeshKit.cylinder(self, 0.034, 0.025, Vector3(0.1, BASE_H + 0.03, D * 0.5 - 0.06), MeshKit.mat("ufo_button", Color(0.9, 0.15, 0.12), 0.3), "Button")
	var lever_base := MeshKit.cylinder(self, 0.03, 0.012, Vector3(-0.1, BASE_H + 0.02, D * 0.5 - 0.06), MeshKit.mat("ufo_lever", Color(0.2, 0.2, 0.22), 0.4), "LeverBase")
	MeshKit.cylinder(self, 0.007, 0.07, Vector3(-0.1, BASE_H + 0.065, D * 0.5 - 0.06), MeshKit.mat("ufo_lever", Color(0.2, 0.2, 0.22), 0.4), "LeverStick")
	MeshKit.sphere(self, 0.018, Vector3(-0.1, BASE_H + 0.105, D * 0.5 - 0.06), MeshKit.mat("ufo_knob", Color(0.95, 0.85, 0.2), 0.4))
	# 取り出し口（手前の面の下、左）：暗い穴と、半透明のフタ
	MeshKit.box(self, Vector3(0.2, 0.17, 0.012), Vector3(OUTLET.x, 0.2, D * 0.5 + 0.0005), dark, "OutletHole")
	var flap := MeshKit.mat("ufo_flap", Color(0.8, 0.85, 0.9, 0.35), 0.2)
	flap.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	MeshKit.box(self, Vector3(0.21, 0.01, 0.1), Vector3(OUTLET.x, 0.31, D * 0.5 + 0.03), flap, "OutletRoof")
	# コイン口の板（飾り）
	MeshKit.box(self, Vector3(0.1, 0.1, 0.01), Vector3(0.1, 0.25, D * 0.5 + 0.0005), pink, "CoinPlate")
	MeshKit.box(self, Vector3(0.05, 0.008, 0.012), Vector3(0.1, 0.27, D * 0.5 + 0.006), dark, "CoinSlot")
	# 上の箱（看板）：光る帯に「つかみどり」
	MeshKit.box(self, Vector3(W, TOTAL_H - GLASS_TOP, D), Vector3(0, GLASS_TOP + (TOTAL_H - GLASS_TOP) * 0.5, 0), teal, "Marquee")
	var glow := MeshKit.mat("ufo_glow", Color(1.0, 0.92, 0.6), 0.5)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.85, 0.45)
	glow.emission_energy_multiplier = 1.2
	MeshKit.box(self, Vector3(W - 0.06, 0.09, 0.01), Vector3(0, GLASS_TOP + 0.075, D * 0.5 + 0.0005), glow, "MarqueeGlow")
	var label := Label3D.new()
	label.name = "MarqueeText"
	label.text = "つかみどり"
	label.font_size = 64
	label.pixel_size = 0.0012
	label.modulate = Color(0.55, 0.15, 0.2)
	label.shaded = false
	label.position = Vector3(0, GLASS_TOP + 0.075, D * 0.5 + 0.006)
	add_child(label)
	var l := OmniLight3D.new()
	l.name = "InnerLight"
	l.position = Vector3(0, GLASS_TOP - 0.1, 0)
	l.light_color = Color(1.0, 0.9, 0.75)
	l.light_energy = 0.5
	l.omni_range = 1.6
	add_child(l)


func _build_glass() -> void:
	var glass := MeshKit.mat("ufo_glass", Color(0.75, 0.9, 0.95, 0.12), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var h := GLASS_TOP - BASE_H
	var cy := BASE_H + h * 0.5
	var g := Node3D.new()
	g.name = "Glass"
	add_child(g)
	for s in [-1.0, 1.0]:
		var side := MeshKit.box(g, Vector3(0.006, h, D - 0.04), Vector3(s * (W * 0.5 - 0.02), cy, 0), glass, "Side")
		side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var front := MeshKit.box(g, Vector3(W - 0.04, h, 0.006), Vector3(0, cy, D * 0.5 - 0.02), glass, "Front")
	front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var back := MeshKit.box(g, Vector3(W - 0.04, h, 0.006), Vector3(0, cy, -D * 0.5 + 0.02), MeshKit.mat("ufo_back", Color(0.35, 0.6, 0.7), 0.7), "Back")
	var post := MeshKit.mat("ufo_post", Color(0.9, 0.9, 0.92), 0.4, 0.5)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MeshKit.box(g, Vector3(0.02, h, 0.02), Vector3(sx * (W * 0.5 - 0.02), cy, sz * (D * 0.5 - 0.02)), post, "Post")
	# 景品の床（少し暗い敷物）
	MeshKit.box(g, Vector3(W - 0.04, 0.02, D - 0.04), Vector3(0, BASE_H + 0.01, 0), MeshKit.mat("ufo_floor", Color(0.55, 0.3, 0.45), 0.9), "Floor")


## 景品：絵6つ（平らな絵の立て札）。透過付きの novelty を画像の比率のまま、床に立てて少しずつ傾ける。
func _build_prizes() -> void:
	var spots := [Vector2(-0.12, -0.12), Vector2(0.02, -0.14), Vector2(0.14, -0.08), Vector2(-0.14, 0.0), Vector2(0.0, -0.02), Vector2(0.12, 0.04), Vector2(-0.06, 0.12), Vector2(0.1, -0.18)]
	var files := [2, 3, 5, 9, 11, 12, 1, 4]
	for i in files.size():
		var tex: Texture2D = load("res://assets/textures/room/novelty_%02d.png" % files[i])
		var h := 0.12
		var node := Node3D.new()
		node.name = "Prize%02d" % files[i]
		node.position = Vector3(spots[i].x, FLOOR_Y, spots[i].y)
		node.rotation.y = deg_to_rad(-12.0 + i * 9.0)
		add_child(node)
		var q := QuadMesh.new()
		q.size = Vector2(h * tex.get_width() / tex.get_height(), h)
		var m := MeshKit.texture_mat("novelty_%02d" % files[i], tex, 0.7).duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.name = "Picture"
		mi.mesh = q
		mi.material_override = m
		mi.position = Vector3(0, h * 0.5, 0)
		mi.rotation.y = PI * 0.5 * 0.0
		node.add_child(mi)
		MeshKit.box(node, Vector3(0.06, 0.006, 0.05), Vector3(0, 0.003, 0), MeshKit.mat("ufo_base", Color(0.9, 0.9, 0.9, 0.5), 0.3), "Stand")
		prizes.append({"node": node, "spot": spots[i], "taken": false})


func _build_claw() -> void:
	# 上のレール（x 方向の棒）と運び台。運び台は x と z に動く
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	MeshKit.box(self, Vector3(W - 0.06, 0.02, 0.02), Vector3(0, CLAW_TOP_Y + 0.05, 0), metal, "Rail")
	claw = Node3D.new()
	claw.name = "Claw"
	claw.position = Vector3(HOME.x, CLAW_TOP_Y, HOME.y)
	add_child(claw)
	MeshKit.box(claw, Vector3(0.06, 0.04, 0.06), Vector3(0, 0.03, 0), MeshKit.mat("ufo_carriage", Color(0.9, 0.35, 0.3), 0.4), "Carriage")
	_cable = MeshKit.box(claw, Vector3(0.006, 1.0, 0.006), Vector3(0, -0.5, 0), MeshKit.mat("ufo_cable", Color(0.15, 0.15, 0.15), 0.6), "Cable")
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, -0.06, 0)
	claw.add_child(head)
	MeshKit.cylinder(head, 0.022, 0.03, Vector3.ZERO, metal, "Hub")
	for k in 3:
		var pivot := Node3D.new()
		pivot.name = "Prong%d" % k
		pivot.rotation.y = TAU * k / 3.0
		head.add_child(pivot)
		var arm := Node3D.new()
		arm.position = Vector3(0.02, -0.01, 0)
		arm.rotation.z = deg_to_rad(-28.0)   # 開いた状態
		pivot.add_child(arm)
		MeshKit.box(arm, Vector3(0.008, 0.07, 0.01), Vector3(0, -0.035, 0), metal, "Finger")
		_prongs.append(arm)
	_set_cable(0.06)


## ケーブルの長さ（運び台から爪の中心まで）を決め、爪の位置を合わせる。
func _set_cable(length: float) -> void:
	_cable.scale.y = length
	_cable.position.y = -length * 0.5
	(claw.get_node("Head") as Node3D).position.y = -length


func get_prompt(_id: String) -> String:
	if busy or taken >= prizes.size():
		return ""
	return "ufo_play"


func interact(_id: String) -> String:
	if busy:
		return ""
	if taken >= prizes.size():
		return "ufo_empty"
	if coin_check.is_valid() and not coin_check.call():
		return "ufo_no_coin"
	busy = true
	Sfx.play("beep")
	var win: bool = SUCCESS_EVERY[plays % SUCCESS_EVERY.size()]
	plays += 1
	var target := _next_prize()
	_play(target, win)
	return "ufo_win" if win else "ufo_miss"


func _next_prize() -> int:
	for i in prizes.size():
		if not prizes[i].taken:
			return i
	return -1


func _play(index: int, win: bool) -> void:
	var p: Dictionary = prizes[index]
	var spot: Vector2 = p.spot
	var aim := spot if win else spot + Vector2(0.07, -0.05)
	aim = Vector2(clampf(aim.x, -0.19, 0.19), clampf(aim.y, -0.19, 0.19))
	var top := Vector3(aim.x, CLAW_TOP_Y, aim.y)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(claw, "position", top, 1.1)
	tw.tween_method(_set_cable, 0.06, CLAW_TOP_Y - CLAW_DOWN_Y, 0.8)
	tw.tween_method(_close_prongs, 0.0, 1.0, 0.4)
	tw.tween_callback(func() -> void: Sfx.play("clunk"))
	if win:
		tw.tween_callback(func() -> void: _grab(p))
	tw.tween_method(_set_cable, CLAW_TOP_Y - CLAW_DOWN_Y, 0.06, 0.8)
	tw.tween_property(claw, "position", Vector3(OUTLET.x, CLAW_TOP_Y, OUTLET.y), 1.2)
	tw.tween_method(_close_prongs, 1.0, 0.0, 0.3)
	if win:
		tw.tween_callback(func() -> void: _drop(p))
		tw.tween_callback(func() -> void: Sfx.play("chime"))
		tw.tween_interval(0.6)
	else:
		tw.tween_callback(func() -> void: Sfx.play("buzz"))
	tw.tween_property(claw, "position", Vector3(HOME.x, CLAW_TOP_Y, HOME.y), 1.0)
	tw.tween_callback(func() -> void: busy = false)


func _close_prongs(t: float) -> void:
	for arm in _prongs:
		(arm as Node3D).rotation.z = deg_to_rad(lerpf(-28.0, -6.0, t))


## つかんだ：景品の絵を爪の下に付ける（見た目だけ）。
func _grab(p: Dictionary) -> void:
	var node: Node3D = p.node
	var keep := node.global_transform
	node.get_parent().remove_child(node)
	(claw.get_node("Head") as Node3D).add_child(node)
	node.global_transform = keep
	node.position = Vector3(0, -0.1, 0)
	node.rotation = Vector3.ZERO


## 取り出し口の上で離す：景品が落ち、取り出し口の中に残る。
func _drop(p: Dictionary) -> void:
	var node: Node3D = p.node
	var keep := node.global_transform
	node.get_parent().remove_child(node)
	add_child(node)
	node.global_transform = keep
	p.taken = true
	taken += 1
	prize_won.emit(taken - 1)
	var slot := Vector3(OUTLET.x + (_outlet_stack % 3 - 1) * 0.055, 0.125, D * 0.5 + 0.035)   # 取り出し口の暗い穴の前（フタの下）に並ぶ
	_outlet_stack += 1
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "position", slot, 0.5)
	node.rotation = Vector3(0, deg_to_rad(_outlet_stack * 7.0 - 10.0), 0)
