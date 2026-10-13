extends Node3D
## 小さなキッチン（自室の手前の壁＝南の壁の右寄り、x 4.0〜4.84 の台と x 4.85〜5.45 の冷蔵庫）。
## 流し台・ガスコンロ（やかん）・吊り戸棚・レンジフード・冷蔵庫。装飾と「調べる」だけ（水は出ない・火はつかない）。
## 座標は部屋と同じ（この節点は原点に置く）。体を止める当たり判定は、流し・コンロの台と冷蔵庫の箱。調べる対象：kitchen_sink / kitchen_stove / fridge。
##
## 画像（assets/textures/kitchen/、ユーザー作成・生成 AI 使用）：
##   kitchen_cabinet … 引き出しと両開き扉の台の正面（台の前面に、比率のまま貼る。幅 0.84m × 高さ 0.9m）
##   kitchen_counter … 天板の石目（0.5m で繰り返す。継ぎ目が出ないよう半分ずらして混ぜてある）
##   kitchen_sink    … 流しの真上からの絵（天板の上に平らに貼る）
##   kitchen_faucet  … 蛇口の横からの絵（流しの奥に、部屋側へ向けて立てる）
##   kitchen_stove   … コンロの真上からの絵（天板の右に平らに貼る）。左の火口の上にやかん

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")
const CorkGunScript := preload("res://scripts/cork_gun.gd")
const TEX_DIR := "res://assets/textures/kitchen/kitchen_%s.png"

const WALL_Z := 2.4
const COUNTER_H := 0.9      # 台の高さ（天板の下面）
const SLAB_T := 0.02        # 天板の厚み
const DEPTH := 0.6
const X0 := 3.998           # 台の左端（西）
const WIDTH := 0.844        # 台の幅（正面の絵の比率から）
const TOP := COUNTER_H + SLAB_T
const FRIDGE_X := Vector2(4.85, 5.45)
const FRIDGE_FRONT := 1.78     # 冷蔵庫の前面（扉の外面）の z
const COOK_TIME := 6.0         # 生から焼き上がりまで（秒）
const BURN_TIME := 20.0        # 生から焦げるまで（秒）

var eggs_held := 0             # 取り出して持っている卵
var eggs_eaten := 0
var flame_on := false
var pan_state := "empty"       # empty / raw / cooked / burnt
var cook_t := 0.0
var upper_open := false
var lower_open := false
var _eggs: Array = []          # {node, area, taken}
var _egg_total := 6
var _doors := {}               # "upper" / "lower" → 扉の回転軸
var _inside_light: OmniLight3D
var _flame: MeshInstance3D
var _flame_light: OmniLight3D
var _egg_white: MeshInstance3D
var _egg_yolk: MeshInstance3D
var _white_mat: StandardMaterial3D
var _yolk_mat: StandardMaterial3D
var _sizzle := 0.0
var _flicker := 0.0
var _inside_area: Area3D
var _goods_areas: Array = []
var _door_tween := {}
# 換気扇（レンジフード）：ボタンは 弱・中・狂 の3つ。同じボタンをもう一度押すと止まる
var hood_level := 0
var cork_gun: Node3D          # 冷蔵庫の上のコルク銃（拾うと消える）
var gun_area: Area3D
var _hood: MeshInstance3D
var _hood_base := Vector3.ZERO
var _hood_fan: Node3D
var _hood_lamp_mat: StandardMaterial3D
var _hood_sound: AudioStreamPlayer3D
var _hood_btns := []
var _hood_t := 0.0
const HOOD_NAMES := ["", "弱", "中", "狂"]
const JP_FONTS := ["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Yu Gothic UI", "Yu Gothic", "Meiryo", "Noto Sans CJK JP", "Noto Sans JP", "sans-serif"]


func _ready() -> void:
	MeshKit.auto_round = false
	var steel := MeshKit.mat("kitchen_steel", Color(0.78, 0.8, 0.82), 0.3, 0.7)
	var dark := MeshKit.mat("kitchen_dark", Color(0.1, 0.1, 0.11), 0.5)
	var white := MeshKit.mat("kitchen_white", Color(0.94, 0.94, 0.95), 0.4)
	var cream := MeshKit.mat("kitchen_cream", Color(0.86, 0.8, 0.66), 0.7)
	var cz := WALL_Z - DEPTH * 0.5
	var half := WIDTH * 0.5
	var cx := X0 + half
	# 台（流し側とコンロ側の2つの箱。同じ色。前面に絵を貼る）
	_body("KitchenSink", "kitchen_sink", Vector3(half, TOP, DEPTH), Vector3(X0 + half * 0.5, TOP * 0.5, cz))
	_body("KitchenStove", "kitchen_stove", Vector3(half, TOP, DEPTH), Vector3(X0 + half * 1.5, TOP * 0.5, cz)).set_meta("fixture", self)
	MeshKit.box(self, Vector3(WIDTH, COUNTER_H, DEPTH), Vector3(cx, COUNTER_H * 0.5, cz), cream, "Cabinet")
	_quad("cabinet", Vector2(WIDTH, COUNTER_H), Vector3(cx, COUNTER_H * 0.5, WALL_Z - DEPTH - 0.002), Basis(Vector3.UP, PI), false, "CabinetFront")
	# 天板（石目）
	var top_mat := MeshKit.tiled_mat("kitchen_counter", load(TEX_DIR % "counter"), 0.5, Color.WHITE, 0.6)
	MeshKit.box(self, Vector3(WIDTH + 0.02, SLAB_T, DEPTH + 0.02), Vector3(cx, COUNTER_H + SLAB_T * 0.5, cz - 0.01), top_mat, "Top")
	# 天板の上の絵：流しは左（西）、コンロは右（東）。上から見た絵を、奥（壁側）が絵の上になるよう寝かせる
	var flat := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	var sink_x := X0 + half * 0.5
	var stove_x := X0 + half * 1.5
	_quad("sink", Vector2(0.38, 0.38 * 595.0 / 934.0), Vector3(sink_x, TOP + 0.002, cz), flat, false, "SinkTop")
	_quad("stove", Vector2(0.4, 0.4 * 668.0 / 1011.0), Vector3(stove_x, TOP + 0.002, cz), flat, true, "StoveTop")
	# 蛇口：流しの奥に、部屋側（-z）へ向けて立てる（絵の左が部屋から見て左）
	_quad("faucet", Vector2(0.17, 0.17 * 631.0 / 961.0), Vector3(sink_x + 0.02, TOP + 0.058, WALL_Z - 0.09), Basis(Vector3.UP, PI), true, "Faucet")
	# やかん：左の火口の上（絵の左の火口は、絵の左端から 25%、上から 50% のあたり）
	var kettle := MeshKit.mat("kitchen_kettle", Color(0.85, 0.35, 0.3), 0.3, 0.4)
	var burner_x := stove_x + (0.5 - 0.25) * 0.4
	MeshKit.cylinder(self, 0.07, 0.12, Vector3(burner_x, TOP + 0.075, cz), kettle, "Kettle", 0.06)
	MeshKit.sphere(self, 0.016, Vector3(burner_x, TOP + 0.145, cz), dark)
	# 吊り戸棚とレンジフード
	MeshKit.box(self, Vector3(WIDTH * 0.5, 0.6, 0.32), Vector3(X0 + half * 0.5, 1.72, WALL_Z - 0.16), cream, "WallCabinet")
	_hood = MeshKit.box(self, Vector3(WIDTH * 0.5, 0.04, 0.5), Vector3(X0 + half * 1.5, 1.45, WALL_Z - 0.25), steel, "Hood")
	_hood_base = _hood.position
	_build_hood_controls(X0 + half * 1.5)
	MeshKit.box(self, Vector3(0.18, 0.5, 0.18), Vector3(X0 + half * 1.5, 1.75, WALL_Z - 0.09), steel, "HoodDuct")
	_build_stove_extras(stove_x, cz)
	_build_fridge()
	MeshKit.auto_round = true


## レンジフードの下の操作部：「弱」「中」「狂」の3つのボタン（文字つき）と、回る羽、ランプ、音。
## 同じボタンをもう一度押すと止まる。狂にするとフードが激しく震え、ランプが赤く点滅し、すさまじい音になる。
func _build_hood_controls(hx: float) -> void:
	var yb := 1.43
	var zf := WALL_Z - 0.5   # フードの手前の縁
	var dark := MeshKit.mat("hood_panel", Color(0.15, 0.15, 0.17), 0.4, 0.4)
	MeshKit.box(self, Vector3(0.24, 0.035, 0.012), Vector3(hx, yb - 0.02, zf - 0.004), dark, "ControlPanel")
	var cols := [Color(0.35, 0.8, 0.45), Color(0.95, 0.8, 0.25), Color(0.9, 0.2, 0.2)]
	var font := SystemFont.new()
	font.font_names = PackedStringArray(JP_FONTS)
	for i in 3:
		var bx := hx + (1 - i) * 0.07   # 部屋側から見て、左から 弱・中・狂（見る人から見て x は逆向き）
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i]
		m.emission_enabled = true
		m.emission = cols[i]
		m.emission_energy_multiplier = 0.1
		var cap := MeshKit.box(self, Vector3(0.04, 0.018, 0.01), Vector3(bx, yb - 0.02, zf - 0.015), m, "HoodButton%d" % (i + 1))
		_hood_btns.append(m)
		var lab := Label3D.new()
		lab.text = HOOD_NAMES[i + 1]
		lab.font = font
		lab.font_size = 48
		lab.pixel_size = 0.00045
		lab.modulate = Color(0.05, 0.05, 0.05) if i < 2 else Color(1, 1, 1)
		lab.outline_size = 0
		lab.shaded = false
		lab.position = Vector3(bx, yb - 0.02, zf - 0.0215)
		lab.rotation.y = PI   # 文字を部屋側（-z）へ
		add_child(lab)
		var a := MeshKit.interact_area(self, "HoodArea%d" % (i + 1), "hood_%d" % (i + 1), self)
		MeshKit.shape_box(a, Vector3(0.05, 0.03, 0.05), Vector3(bx, yb - 0.02, zf - 0.02))
		a.set_meta("interact_range", 2.4)
	# 下から見える回る羽（フードの底）と、ランプ
	_hood_fan = Node3D.new()
	_hood_fan.name = "HoodFan"
	_hood_fan.position = Vector3(hx, 1.428, WALL_Z - 0.25)
	add_child(_hood_fan)
	for k in 4:
		var blade := MeshKit.box(_hood_fan, Vector3(0.16, 0.004, 0.035), Vector3.ZERO, MeshKit.mat("hood_blade", Color(0.3, 0.3, 0.32), 0.4, 0.6), "Blade")
		blade.rotation.y = k * PI * 0.5
	MeshKit.cylinder(_hood_fan, 0.02, 0.01, Vector3.ZERO, MeshKit.mat("hood_hub", Color(0.1, 0.1, 0.1), 0.5), "Hub")
	_hood_lamp_mat = StandardMaterial3D.new()
	_hood_lamp_mat.albedo_color = Color(0.95, 0.9, 0.7)
	_hood_lamp_mat.emission_enabled = true
	_hood_lamp_mat.emission = Color(1.0, 0.9, 0.6)
	_hood_lamp_mat.emission_energy_multiplier = 0.0
	MeshKit.box(self, Vector3(0.1, 0.004, 0.05), Vector3(hx, 1.428, WALL_Z - 0.4), _hood_lamp_mat, "HoodLamp")
	# 音：低いこもった風のうなり（ループ）。レベルで音量と高さを変える
	_hood_sound = AudioStreamPlayer3D.new()
	_hood_sound.name = "HoodSound"
	_hood_sound.bus = "Ambient"
	_hood_sound.position = Vector3(hx, 1.4, WALL_Z - 0.25)
	_hood_sound.unit_size = 2.0
	_hood_sound.max_distance = 12.0
	var n := 22050
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var y := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in n:
		y += 0.18 * (rng.randf_range(-1.0, 1.0) - y)
		var t := float(i) / 22050.0
		var v := y * 1.6 + 0.25 * sin(TAU * 110.0 * t) + 0.12 * sin(TAU * 220.0 * t)
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	_hood_sound.stream = w
	add_child(_hood_sound)


func _set_hood(level: int) -> void:
	hood_level = level
	for i in 3:
		(_hood_btns[i] as StandardMaterial3D).emission_energy_multiplier = 2.2 if level == i + 1 else 0.1
	if level == 0:
		_hood_sound.stop()
		_hood_lamp_mat.emission_energy_multiplier = 0.0
		_hood.position = _hood_base
		_hood.rotation = Vector3.ZERO
	else:
		_hood_sound.volume_db = [-30.0, -20.0, -6.0][level - 1]
		_hood_sound.pitch_scale = [0.8, 1.05, 1.9][level - 1]
		if not _hood_sound.playing:
			_hood_sound.play()
		_hood_lamp_mat.emission_energy_multiplier = 1.0
	Sfx.play("click", 1.4)


func _hood_step(delta: float) -> void:
	if hood_level == 0:
		return
	_hood_t += delta
	_hood_fan.rotation.y += delta * [6.0, 16.0, 55.0][hood_level - 1]
	if hood_level == 3:
		# 狂：フードが震え、ランプが赤く点滅する
		_hood.position = _hood_base + Vector3(sin(_hood_t * 90.0) * 0.0012, sin(_hood_t * 71.0) * 0.001, sin(_hood_t * 83.0) * 0.0012)
		_hood.rotation.z = sin(_hood_t * 60.0) * 0.004
		var flick: bool = int(_hood_t * 12.0) % 2 == 0
		_hood_lamp_mat.emission = Color(1.0, 0.1, 0.05) if flick else Color(1.0, 0.8, 0.5)
		_hood_lamp_mat.emission_energy_multiplier = 2.0 if flick else 0.6
	else:
		_hood_lamp_mat.emission = Color(1.0, 0.9, 0.6)
		_hood_lamp_mat.emission_energy_multiplier = 1.0


## コンロの右の火口：フライパン・炎（点いたときだけ）・フライパンの中の卵（割ったときだけ）。
func _build_stove_extras(stove_x: float, cz: float) -> void:
	var bx := stove_x - 0.1
	var black := MeshKit.mat("pan_black", Color(0.07, 0.07, 0.08), 0.4, 0.5)
	var pan := Node3D.new()
	pan.name = "Pan"
	pan.position = Vector3(bx, TOP, cz)
	add_child(pan)
	MeshKit.cylinder(pan, 0.085, 0.032, Vector3(0, 0.03, 0), black, "PanBody", 0.1)
	MeshKit.cylinder(pan, 0.08, 0.004, Vector3(0, 0.018, 0), MeshKit.mat("pan_inside", Color(0.16, 0.16, 0.17), 0.3, 0.4), "PanBottom")
	MeshKit.box(pan, Vector3(0.02, 0.012, 0.15), Vector3(0, 0.04, -0.15), black, "PanHandle")
	_white_mat = StandardMaterial3D.new()
	_white_mat.albedo_color = Color(0.95, 0.95, 0.95, 0.5)
	_white_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_white_mat.roughness = 0.4
	_egg_white = MeshKit.cylinder(pan, 0.058, 0.004, Vector3(0.005, 0.024, 0.0), _white_mat, "EggWhite")
	_yolk_mat = StandardMaterial3D.new()
	_yolk_mat.albedo_color = Color(1.0, 0.75, 0.1)
	_yolk_mat.roughness = 0.25
	_egg_yolk = MeshKit.sphere(pan, 0.02, Vector3(0.0, 0.03, 0.0), _yolk_mat)
	_egg_yolk.scale = Vector3(1.0, 0.55, 1.0)
	_egg_white.visible = false
	_egg_yolk.visible = false
	# 炎：青い輪（点いたときだけ）
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.55, 1.0)
	fm.emission_enabled = true
	fm.emission = Color(0.3, 0.55, 1.0)
	fm.emission_energy_multiplier = 2.5
	var torus := TorusMesh.new()
	torus.inner_radius = 0.03
	torus.outer_radius = 0.04
	_flame = MeshInstance3D.new()
	_flame.name = "Flame"
	_flame.mesh = torus
	_flame.material_override = fm
	_flame.position = Vector3(bx, TOP + 0.008, cz)
	_flame.scale = Vector3(1.0, 1.4, 1.0)
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.visible = false
	add_child(_flame)
	_flame_light = OmniLight3D.new()
	_flame_light.name = "FlameLight"
	_flame_light.position = Vector3(bx, TOP + 0.12, cz)
	_flame_light.light_color = Color(0.7, 0.75, 1.0)
	_flame_light.light_energy = 0.0
	_flame_light.omni_range = 0.6
	_flame_light.shadow_enabled = false
	add_child(_flame_light)


## 冷蔵庫：上が冷凍室・下が冷蔵室の2枚の扉（左の縁が蝶番）。開けると中が見え、卵（6個）を取れる。
## 体を止める箱は「体だけ止める層」にして、照準は扉と中身に届く。
func _build_fridge() -> void:
	var white := MeshKit.mat("kitchen_white", Color(0.94, 0.94, 0.95), 0.4)
	var steel := MeshKit.mat("kitchen_steel", Color(0.78, 0.8, 0.82), 0.3, 0.7)
	var inner := MeshKit.mat("fridge_inside", Color(0.9, 0.93, 0.96), 0.5)
	var cx := (FRIDGE_X.x + FRIDGE_X.y) * 0.5
	var w := FRIDGE_X.y - FRIDGE_X.x
	var zf := FRIDGE_FRONT + 0.05     # 殻の前面（扉の厚み 5cm の奥）
	var zb := WALL_Z
	var zc := (zf + zb) * 0.5
	var d := zb - zf
	var blk := StaticBody3D.new()
	blk.name = "FridgeBlock"
	blk.collision_layer = MeshKit.LAYER_BODY_ONLY
	blk.collision_mask = 0
	add_child(blk)
	MeshKit.shape_box(blk, Vector3(w, 1.7, WALL_Z - FRIDGE_FRONT), Vector3(cx, 0.85, (FRIDGE_FRONT + WALL_Z) * 0.5))
	# 殻（後ろ・左右・上・下・仕切り）
	MeshKit.box(self, Vector3(w, 1.7, 0.02), Vector3(cx, 0.85, zb - 0.01), inner, "ShellBack")
	MeshKit.box(self, Vector3(0.02, 1.7, d), Vector3(FRIDGE_X.x + 0.01, 0.85, zc), white, "ShellLeft")
	MeshKit.box(self, Vector3(0.02, 1.7, d), Vector3(FRIDGE_X.y - 0.01, 0.85, zc), white, "ShellRight")
	MeshKit.box(self, Vector3(w, 0.02, d), Vector3(cx, 1.69, zc), white, "ShellTop")
	MeshKit.box(self, Vector3(w, 0.03, d), Vector3(cx, 0.015, zc), white, "ShellBottom")
	MeshKit.box(self, Vector3(w - 0.04, 0.02, d - 0.02), Vector3(cx, 1.15, zc - 0.01), inner, "Divider")
	# 冷蔵室の棚（2枚）と野菜室
	for y in [0.42, 0.78]:
		MeshKit.box(self, Vector3(w - 0.04, 0.012, d - 0.04), Vector3(cx, y, zc - 0.01), MeshKit.mat("fridge_glass", Color(0.8, 0.9, 0.95), 0.2), "Shelf")
	MeshKit.box(self, Vector3(w - 0.06, 0.18, d - 0.08), Vector3(cx, 0.12, zc - 0.02), MeshKit.mat("fridge_veg", Color(0.7, 0.85, 0.75), 0.4), "VegDrawer")
	MeshKit.sphere(self, 0.07, Vector3(cx - 0.08, 0.24, zc + 0.0), MeshKit.mat("fridge_cabbage", Color(0.55, 0.78, 0.4), 0.8))
	# 中身：牛乳・ジャム・電池と石（「冷やすものではない」）・タッパー
	var sy := 0.42 + 0.006
	MeshKit.box(self, Vector3(0.07, 0.2, 0.07), Vector3(cx - 0.2, sy + 0.1, zc + 0.06), MeshKit.mat("fridge_milk", Color(0.95, 0.96, 1.0), 0.5), "Milk")
	MeshKit.box(self, Vector3(0.07, 0.04, 0.07), Vector3(cx - 0.2, sy + 0.22, zc + 0.06), MeshKit.mat("fridge_milk_top", Color(0.4, 0.6, 0.85), 0.5), "MilkTop")
	MeshKit.cylinder(self, 0.03, 0.08, Vector3(cx - 0.08, sy + 0.04, zc + 0.08), MeshKit.mat("fridge_jam", Color(0.65, 0.12, 0.18), 0.3), "Jam")
	MeshKit.cylinder(self, 0.031, 0.015, Vector3(cx - 0.08, sy + 0.087, zc + 0.08), MeshKit.mat("fridge_jam_lid", Color(0.85, 0.8, 0.5), 0.4, 0.5), "JamLid")
	for k in 2:
		MeshKit.cylinder(self, 0.007, 0.05, Vector3(cx + 0.1 + k * 0.02, sy + 0.007, zc + 0.1), MeshKit.mat("fridge_battery", Color(0.85, 0.7, 0.15), 0.4, 0.5), "Battery").rotation.x = PI * 0.5
	MeshKit.sphere(self, 0.035, Vector3(cx + 0.19, sy + 0.025, zc + 0.08), MeshKit.mat("fridge_stone", Color(0.3, 0.3, 0.32), 0.9)).scale = Vector3(1.0, 0.7, 0.9)
	MeshKit.box(self, Vector3(0.14, 0.06, 0.1), Vector3(cx + 0.12, sy + 0.036, zc - 0.05), MeshKit.mat("fridge_tupper", Color(0.85, 0.9, 0.95, 1.0), 0.3), "Tupperware")
	# 卵のパック（上の棚）：2列×3個
	var ey := 0.78 + 0.006
	MeshKit.box(self, Vector3(0.18, 0.025, 0.11), Vector3(cx, ey + 0.0125, zc + 0.03), MeshKit.mat("egg_carton", Color(0.7, 0.66, 0.58), 0.9), "EggCarton")
	var shell_a := MeshKit.mat("egg_shell_a", Color(0.95, 0.88, 0.75), 0.5)
	var shell_b := MeshKit.mat("egg_shell_b", Color(0.88, 0.7, 0.5), 0.5)
	for i in _egg_total:
		var ex := cx + (i % 3 - 1) * 0.055
		var ez := zc + 0.0 + (i / 3) * 0.055
		var egg := MeshKit.sphere(self, 0.022, Vector3(ex, ey + 0.045, ez), shell_a if i % 2 == 0 else shell_b)
		egg.name = "Egg%d" % i
		egg.scale = Vector3(0.85, 1.1, 0.85)
		var area := MeshKit.interact_area(self, "EggArea%d" % i, "fridge_egg_%d" % i, self)
		MeshKit.shape_box(area, Vector3(0.05, 0.06, 0.05), Vector3(ex, ey + 0.045, ez))
		area.collision_layer = 0
		_eggs.append({"node": egg, "area": area, "taken": false})
	# 冷凍室：氷の皿・冷凍食品・アイス
	MeshKit.box(self, Vector3(0.16, 0.025, 0.1), Vector3(cx - 0.1, 1.17 + 0.0125, zc + 0.05), MeshKit.mat("fridge_ice", Color(0.75, 0.88, 0.98), 0.2), "IceTray")
	MeshKit.box(self, Vector3(0.12, 0.05, 0.1), Vector3(cx + 0.12, 1.17 + 0.025, zc + 0.05), MeshKit.mat("fridge_peas", Color(0.4, 0.7, 0.35), 0.7), "FrozenPeas")
	MeshKit.cylinder(self, 0.05, 0.1, Vector3(cx - 0.05, 1.17 + 0.075 + 0.025, zc - 0.07), MeshKit.mat("fridge_icecream", Color(0.95, 0.8, 0.85), 0.6), "IceCream")
	# 中身をまとめて調べる判定（卵より奥）
	_inside_area = MeshKit.interact_area(self, "InsideArea", "fridge_inside", self)
	MeshKit.shape_box(_inside_area, Vector3(w - 0.04, 1.0, 0.03), Vector3(cx, 0.6, zb - 0.04))
	_inside_area.collision_layer = 0
	_inside_light = OmniLight3D.new()
	_inside_light.name = "InsideLight"
	_inside_light.position = Vector3(cx, 1.1, zc - 0.05)
	_inside_light.light_color = Color(0.9, 0.95, 1.0)
	_inside_light.light_energy = 0.0
	_inside_light.omni_range = 0.9
	_inside_light.shadow_enabled = false
	add_child(_inside_light)
	# 扉：左の縁が蝶番。上（冷凍室 y 1.15〜1.7）と下（冷蔵室 y 0.03〜1.15）
	for def in [["upper", 1.16, 0.54, 1.0], ["lower", 0.03, 1.11, 0.0]]:
		var key: String = def[0]
		var y0: float = def[1]
		var h: float = def[2]
		var pivot := Node3D.new()
		pivot.name = "Door_" + key
		pivot.position = Vector3(FRIDGE_X.x, y0, FRIDGE_FRONT)
		add_child(pivot)
		MeshKit.box(pivot, Vector3(w, h, 0.05), Vector3(w * 0.5, h * 0.5, 0.025), white, "DoorLeaf")
		var hy := h - 0.2 if key == "upper" else h * 0.65
		MeshKit.box(pivot, Vector3(0.015, 0.4 if key == "lower" else 0.3, 0.02), Vector3(w - 0.07, hy, -0.01), steel, "Handle")
		if key == "upper":
			for k in 5:
				MeshKit.box(pivot, Vector3(0.05, 0.05, 0.006), Vector3(0.15 + (k % 3) * 0.1, 0.25 + (k / 3) * 0.1 - 0.12, -0.003), MeshKit.mat("magnet_%d" % k, Color.from_hsv(k * 0.18, 0.6, 0.9), 0.5), "Magnet")
		else:
			# 扉の内側のポケット：ペットボトルとマヨネーズ
			MeshKit.cylinder(pivot, 0.03, 0.22, Vector3(0.15, 0.35, 0.1), MeshKit.mat("fridge_bottle", Color(0.55, 0.8, 0.9, 1.0), 0.3), "Bottle")
			MeshKit.cylinder(pivot, 0.025, 0.16, Vector3(0.32, 0.31, 0.09), MeshKit.mat("fridge_mayo", Color(0.95, 0.9, 0.75), 0.5), "Mayo")
		# 開けた扉は体を止める（照準は通す）。扉といっしょに動く
		var blk_d := StaticBody3D.new()
		blk_d.name = "DoorBlock"
		blk_d.collision_layer = MeshKit.LAYER_BODY_ONLY
		blk_d.collision_mask = 0
		pivot.add_child(blk_d)
		MeshKit.shape_box(blk_d, Vector3(w, h, 0.05), Vector3(w * 0.5, h * 0.5, 0.025))
		_doors[key] = pivot
		var da := MeshKit.interact_area(pivot, "DoorArea", "fridge_" + key, self)
		MeshKit.shape_box(da, Vector3(w, h, 0.1), Vector3(w * 0.5, h * 0.5, 0.02))
	_build_gun()
	_goods_areas = _eggs.map(func(e): return e.area)
	_goods_areas.append(_inside_area)


## コルク銃：冷蔵庫の天板（y 1.7）に、銃口を前の縁から 3cm はみ出させて寝かせてある。下から見上げると、筒の先だけがちらりと見える。
func _build_gun() -> void:
	cork_gun = CorkGunScript.build()
	cork_gun.position = Vector3((FRIDGE_X.x + FRIDGE_X.y) * 0.5 + 0.05, 1.7 + 0.022, FRIDGE_FRONT - 0.03 + 0.235)
	cork_gun.rotation.y = deg_to_rad(4.0)
	add_child(cork_gun)
	gun_area = MeshKit.interact_area(cork_gun, "GunArea", "cork_gun")
	MeshKit.shape_box(gun_area, Vector3(0.1, 0.12, 0.45), Vector3(0, 0, 0))
	gun_area.set_meta("interact_range", 2.6)


func remove_gun() -> void:
	cork_gun.visible = false
	gun_area.collision_layer = 0


## 画像1枚の板（比率は呼び出し側で size に入れる）。basis で向きを決め、透過の縁は alpha scissor で抜く。影は落とさない。
func _quad(file: String, size: Vector2, pos: Vector3, basis: Basis, double_sided: bool, node_name: String) -> MeshInstance3D:
	var tex: Texture2D = load(TEX_DIR % file)
	var q := QuadMesh.new()
	q.size = size
	var m := MeshKit.texture_mat("kitchen_%s" % file, tex, 0.6).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.basis = basis
	mi.position = pos
	add_child(mi)
	return mi


func _body(node_name: String, interact_id: String, size: Vector3, center: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = node_name
	b.collision_layer = MeshKit.LAYER_WORLD
	b.collision_mask = 0
	b.set_meta("interact_id", interact_id)
	add_child(b)
	MeshKit.shape_box(b, size, center)
	return b


# ---------------------------------------------------------------- 冷蔵庫・コンロの操作（fixture）

func get_prompt(id: String) -> String:
	if id.begins_with("hood_"):
		return "hood_press"
	if id.begins_with("fridge_egg_"):
		return "egg_take"
	match id:
		"fridge_upper":
			return "fridge_close" if upper_open else "fridge_open"
		"fridge_lower":
			return "fridge_close" if lower_open else "fridge_open"
		"fridge_inside":
			return "fridge_look"
		"kitchen_stove":
			if not flame_on:
				return "stove_ignite"
			match pan_state:
				"empty":
					return "stove_crack_prompt" if eggs_held > 0 else "stove_off_prompt"
				"raw":
					return "stove_wait_prompt"
				"cooked":
					return "stove_eat_prompt"
				_:
					return "stove_clear_prompt"
	return ""


## 戻り値は main.gd の MESSAGES のキー。
func interact(id: String) -> String:
	if id.begins_with("hood_"):
		var lv := int(id.substr(5))
		_set_hood(0 if lv == hood_level else lv)
		return "hood_off" if hood_level == 0 else "hood_%d" % hood_level
	if id.begins_with("fridge_egg_"):
		var idx := int(id.substr(11))
		if eggs_held >= 3:
			return "egg_hands_full"
		_eggs[idx].taken = true
		(_eggs[idx].node as Node3D).visible = false
		(_eggs[idx].area as Area3D).collision_layer = 0
		eggs_held += 1
		Sfx.play("pop", 1.2, -4.0)
		return "egg_taken"
	match id:
		"fridge_upper":
			_set_door("upper", not upper_open)
			return "fridge_upper_opened" if upper_open else "fridge_closed"
		"fridge_lower":
			_set_door("lower", not lower_open)
			return "fridge_lower_opened" if lower_open else "fridge_closed"
		"fridge_inside":
			return "fridge_inside"
		"kitchen_stove":
			return _stove()
	return ""


## 文章の {n}（いま持っている卵の数）などを置き換える。
func format_message(_key: String, text: String) -> String:
	return text.replace("{n}", str(eggs_held)).replace("{left}", str(_eggs.filter(func(e): return not e.taken).size()))


func _set_door(which: String, open: bool) -> void:
	if which == "upper":
		upper_open = open
	else:
		lower_open = open
	Sfx.play("thunk", 1.7, -7.0)
	var pivot: Node3D = _doors[which]
	if _door_tween.has(which) and _door_tween[which]:
		(_door_tween[which] as Tween).kill()
	var tw := create_tween()
	_door_tween[which] = tw
	tw.tween_property(pivot, "rotation:y", deg_to_rad(100.0) if open else 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	_refresh_fridge()


func _refresh_fridge() -> void:
	_inside_light.light_energy = 0.7 if (upper_open or lower_open) else 0.0
	for e in _eggs:
		(e.area as Area3D).collision_layer = MeshKit.LAYER_INTERACT if (lower_open and not e.taken) else 0
	_inside_area.collision_layer = MeshKit.LAYER_INTERACT if lower_open else 0


func _stove() -> String:
	if not flame_on:
		flame_on = true
		_flame.visible = true
		_flame_light.light_energy = 0.5
		Sfx.play("ignite")
		return "stove_on"
	match pan_state:
		"empty":
			if eggs_held > 0:
				eggs_held -= 1
				pan_state = "raw"
				cook_t = 0.0
				_egg_white.visible = true
				_egg_yolk.visible = true
				_white_mat.albedo_color = Color(0.95, 0.95, 0.95, 0.5)
				_white_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_yolk_mat.albedo_color = Color(1.0, 0.75, 0.1)
				Sfx.play("crack")
				return "stove_crack"
			flame_on = false
			_flame.visible = false
			_flame_light.light_energy = 0.0
			return "stove_off"
		"raw":
			return "stove_wait"
		"cooked":
			pan_state = "empty"
			cook_t = 0.0
			_egg_white.visible = false
			_egg_yolk.visible = false
			eggs_eaten += 1
			Sfx.play("pop", 0.8)
			return "stove_eat_1" if eggs_eaten == 1 else ("stove_eat_2" if eggs_eaten == 2 else "stove_eat_3")
		_:
			pan_state = "empty"
			cook_t = 0.0
			_egg_white.visible = false
			_egg_yolk.visible = false
			return "stove_burnt_clear"


func _process(delta: float) -> void:
	_hood_step(delta)
	if flame_on:
		_flicker += delta * 18.0
		_flame.scale = Vector3(1.0 + 0.03 * sin(_flicker), 1.4 + 0.15 * sin(_flicker * 1.7), 1.0 + 0.03 * sin(_flicker * 1.3))
		_flame_light.light_energy = 0.45 + 0.1 * sin(_flicker * 0.9)
	if flame_on and (pan_state == "raw" or pan_state == "cooked"):
		cook_t += delta
		_sizzle -= delta
		if _sizzle <= 0.0:
			_sizzle = 1.3
			Sfx.play("sizzle", 1.0, -14.0)
		if pan_state == "raw":
			var k := clampf(cook_t / COOK_TIME, 0.0, 1.0)
			_white_mat.albedo_color = Color(0.95, 0.95, 0.95, lerpf(0.5, 1.0, k))
			if cook_t >= COOK_TIME:
				pan_state = "cooked"
				_white_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		elif cook_t >= BURN_TIME:
			pan_state = "burnt"
			_white_mat.albedo_color = Color(0.2, 0.12, 0.07)
			_yolk_mat.albedo_color = Color(0.12, 0.08, 0.05)
