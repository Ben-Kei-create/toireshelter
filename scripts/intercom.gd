extends Node3D
## インターホン（玄関ホールの奥の壁、出口のすぐそば）と、のぞき穴の外の景色。
## システム日時が 24 時（0:00:00）になると鳴る：ピンポーン → 家の明かりが 1 秒ほど点滅して元に戻る → モニターに玄関の外の人影が映る（25 秒）。
## 鳴ったあと、扉の受け箱に封筒が一通入っている。のぞき穴の人影は 24 時台（0:00〜0:59）のあいだ見える（ぼんやり）。それ以外の時刻には、誰もいない廊下が見えるだけ。
## 時刻の確認は毎フレーム、同じ日に 2 回は鳴らさない。テストからは ring() を直接呼ぶ。
## モニターの絵・のぞき穴の絵はコードで描く（廊下を一点透視で描き、樽型にゆがめて、ぼかす）。外部の画像なし。
## 判定：モニター（id intercom。fixture として get_prompt／interact）。のぞき穴・受け箱は front_door.gd が持つ。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

signal notice(text: String)

const POS := Vector3(-0.45, 1.4, 2.4)        # ホールの奥（南）の壁
const VISITOR_TIME := 25.0
const FLICKER := [0.0, 0.18, 1.0, 0.1, 0.0, 0.25, 1.0, 0.12, 0.0, 0.2, 1.0, 0.0]   # 暗・明を交互に（秒）。最後は元の明るさ

var rang := false
var hour_override := -1      # テスト用：0〜23 を入れると、システム時刻の「時」の代わりに使う
var visitor_present := false
var lights_root: Node
var front_door: Node
var _last_key := ""
var _screen_mat: StandardMaterial3D
var _led_mat: StandardMaterial3D
var _tex_empty: ImageTexture
var _tex_visitor: ImageTexture
var _tex_off: ImageTexture
var _tween: Tween
var _flicker_tween: Tween
var _saved := {}


func _ready() -> void:
	position = POS
	MeshKit.auto_round = false
	var white := MeshKit.mat("intercom_body", Color(0.92, 0.92, 0.9), 0.4)
	var dark := MeshKit.mat("intercom_dark", Color(0.08, 0.08, 0.09), 0.4)
	MeshKit.box(self, Vector3(0.22, 0.2, 0.03), Vector3(0, 0, -0.015), white, "Body")
	MeshKit.box(self, Vector3(0.17, 0.125, 0.004), Vector3(0, 0.025, -0.032), dark, "Bezel")
	_tex_off = ImageTexture.create_from_image(_noise_image())
	_tex_empty = ImageTexture.create_from_image(corridor_image(96, false, Color(0.7, 1.0, 0.8), true))
	_tex_visitor = ImageTexture.create_from_image(corridor_image(96, true, Color(0.7, 1.0, 0.8), true))
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_texture = _tex_off
	_screen_mat.emission_enabled = true
	_screen_mat.emission_texture = _tex_off
	_screen_mat.emission_energy_multiplier = 0.15
	_screen_mat.roughness = 0.3
	var q := QuadMesh.new()
	q.size = Vector2(0.15, 0.105)
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = q
	screen.material_override = _screen_mat
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.position = Vector3(0, 0.025, -0.0345)
	screen.rotation.y = PI   # 表を部屋側（-z）へ
	add_child(screen)
	# ボタン（呼び出し）とスピーカーの溝、小さなランプ
	MeshKit.cylinder(self, 0.015, 0.008, Vector3(0, -0.07, -0.032), MeshKit.mat("intercom_button", Color(0.85, 0.85, 0.82), 0.3), "Button").rotation.x = PI * 0.5
	for k in 4:
		MeshKit.box(self, Vector3(0.05, 0.003, 0.002), Vector3(-0.06, -0.06 - k * 0.008, -0.031), dark, "Slot")
	_led_mat = StandardMaterial3D.new()
	_led_mat.albedo_color = Color(0.1, 0.25, 0.1)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color(0.2, 1.0, 0.3)
	_led_mat.emission_energy_multiplier = 0.4
	MeshKit.sphere(self, 0.004, Vector3(0.075, -0.065, -0.032), _led_mat)
	var area := MeshKit.interact_area(self, "IntercomArea", "intercom", self)
	MeshKit.shape_box(area, Vector3(0.26, 0.24, 0.08), Vector3(0, 0, -0.04))
	area.set_meta("interact_range", 2.4)
	MeshKit.auto_round = true


func _process(_delta: float) -> void:
	var t := Time.get_datetime_dict_from_system()
	if t.hour == 0 and t.minute == 0 and t.second <= 1:
		var key := "%d-%d-%d" % [t.year, t.month, t.day]
		if key != _last_key:
			_last_key = key
			ring()


## 呼び出しを 1 回ぶん起こす（24 時になると自動で呼ばれる）。
func ring() -> void:
	rang = true
	visitor_present = true
	_show_screen()
	Sfx.play("intercom")
	notice.emit("ピンポーン。……こんな時間に、誰だろう。")
	flicker_lights()
	if front_door and front_door.get("mail_envelope"):
		front_door.mail_envelope.visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(VISITOR_TIME)
	_tween.tween_callback(func() -> void:
		visitor_present = false
		_show_screen())
	_tween.tween_interval(6.0)
	_tween.tween_callback(func() -> void:
		_screen_mat.albedo_texture = _tex_off
		_screen_mat.emission_texture = _tex_off
		_screen_mat.emission_energy_multiplier = 0.15)


func _show_screen() -> void:
	var tex := _tex_visitor if visitor_present else _tex_empty
	_screen_mat.albedo_texture = tex
	_screen_mat.emission_texture = tex
	_screen_mat.emission_energy_multiplier = 0.9
	_led_mat.emission_energy_multiplier = 2.0 if visitor_present else 0.4


## 家の明かり（部屋・ホール・浴室の灯り）を 1 秒ほど点滅させて、元の明るさに戻す。
func flicker_lights() -> void:
	if lights_root == null:
		return
	for l in lights_root.find_children("*", "Light3D", true, false):
		var lt := l as Light3D
		var p := lt.global_position
		if lt.light_energy > 0.0 and p.x > -1.1 and p.x < 5.7 and p.z > -1.4 and p.z < 2.6 and p.y > -0.1 and p.y < 2.7 and not _saved.has(lt):
			_saved[lt] = lt.light_energy
	if _flicker_tween:
		_flicker_tween.kill()
	_flicker_tween = create_tween()
	for i in FLICKER.size():
		if i % 2 == 0:
			_flicker_tween.tween_callback(_set_lights.bind(FLICKER[i]))
		else:
			_flicker_tween.tween_interval(FLICKER[i])
	_flicker_tween.tween_callback(_restore_lights)


## 点滅のあいだの明るさ（0 は消灯、1 は元の明るさ）。
func _set_lights(k: float) -> void:
	for l in _saved:
		if is_instance_valid(l):
			(l as Light3D).light_energy = float(_saved[l]) * k


func _restore_lights() -> void:
	_set_lights(1.0)
	_saved.clear()


# ---------------------------------------------------------------- 調べる（fixture）

func get_prompt(_id: String) -> String:
	return "examine"


func interact(_id: String) -> String:
	return "intercom_visitor" if visitor_present else ("intercom_after" if rang else "intercom_idle")


## のぞき穴から人影が見えるか：24 時台（0:00〜0:59）か、インターホンが鳴って 25 秒以内。それ以外の時刻は、誰もいない廊下。
func figure_visible() -> bool:
	var hour: int = hour_override if hour_override >= 0 else int(Time.get_datetime_dict_from_system().hour)
	return hour == 0 or visitor_present


## のぞき穴の絵（人影の有無を反映）。丸く切り抜いた、ぼんやりした景色。
func peephole_texture() -> ImageTexture:
	return ImageTexture.create_from_image(corridor_image(160, figure_visible(), Color(1.0, 0.95, 0.8), false))


# ---------------------------------------------------------------- 絵（コードで描く）

func _noise_image() -> Image:
	var img := Image.create(48, 36, false, Image.FORMAT_RGB8)
	for y in 36:
		for x in 48:
			var v := 0.03 + 0.02 * fmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
			img.set_pixel(x, y, Color(v, v * 1.1, v))
	return img


## 廊下を玄関の外から見た絵（正方形 size×size）。一点透視の廊下（床・天井・左右の壁と扉・天井灯）を樽型にゆがめ、
## visitor なら中央に人影（暗い体と頭、目だけ小さく光る）。最後に小さくして引き伸ばし、ぼかす。
## monitor が true ならモニター用（緑がかって走査線）、false ならのぞき穴用（丸く切り抜く）。
static func corridor_image(size: int, visitor: bool, tint: Color, monitor: bool) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var wall := Color(0.55, 0.52, 0.45)
	var floor_c := Color(0.35, 0.3, 0.25)
	var ceil_c := Color(0.62, 0.62, 0.6)
	for y in size:
		for x in size:
			var u := (float(x) / (size - 1)) * 2.0 - 1.0
			var v := (float(y) / (size - 1)) * 2.0 - 1.0
			var r2 := u * u + v * v
			var k := 1.0 + 0.55 * r2          # 樽型のゆがみ（外側ほど中心へ寄せる）
			var uu := u * k
			var vv := v * k
			var m := maxf(absf(uu), absf(vv))
			var c: Color
			if m < 0.22:
				c = Color(0.18, 0.2, 0.22)       # 廊下の突き当たり（暗い）
				if absf(uu) < 0.07 and vv > -0.06:
					c = Color(0.28, 0.3, 0.28)   # 突き当たりの扉
			else:
				var depth := 0.22 / m              # 0〜1：奥ほど 1 に近い…手前ほど小さい
				if absf(vv) > absf(uu):
					c = ceil_c if vv < 0.0 else floor_c
					var along := 0.22 / m
					if vv < 0.0 and fposmod(along * 6.0, 1.0) < 0.12 and absf(uu) < 0.5 * absf(vv):
						c = Color(1.0, 0.95, 0.75)   # 天井灯
				else:
					c = wall
					var along2 := 0.22 / m
					if fposmod(along2 * 4.0, 1.0) < 0.35 and absf(vv) < 0.55 * absf(uu):
						c = Color(0.38, 0.3, 0.22)   # 隣の部屋の扉
				c = c.lerp(Color(0.12, 0.13, 0.14), clampf(depth * 1.1 - 0.3, 0.0, 0.85))   # 奥ほど暗い
			img.set_pixel(x, y, c)
	if visitor:
		var cx := size * 0.5
		var base := size * 0.88
		for y in size:
			for x in size:
				var dx := (x - cx) / (size * 0.5)
				var body := Vector2(dx / 0.2, (y - size * 0.64) / (size * 0.24)).length() < 1.0
				var head := Vector2((x - cx) / (size * 0.075), (y - size * 0.4) / (size * 0.085)).length() < 1.0
				var neck := absf(x - cx) < size * 0.035 and y > size * 0.46 and y < size * 0.52
				if (body or head or neck) and y < base:
					img.set_pixel(x, y, Color(0.03, 0.03, 0.04))
		for ex in [-0.028, 0.028]:
			var px := int(cx + size * ex)
			var py := int(size * 0.4)
			for ddx in range(-1, 1):
				for ddy in range(-1, 1):
					img.set_pixel(clampi(px + ddx, 0, size - 1), clampi(py + ddy, 0, size - 1), Color(0.9, 0.95, 0.8))
	# ぼかす：小さくして、なめらかに戻す
	var small := maxi(14, size / 6)
	img.resize(small, small, Image.INTERPOLATE_BILINEAR)
	img.resize(size, size, Image.INTERPOLATE_BILINEAR)
	for y in size:
		for x in size:
			var c2 := img.get_pixel(x, y)
			if monitor:
				var g := c2.r * 0.3 + c2.g * 0.55 + c2.b * 0.15
				c2 = Color(g * tint.r, g * tint.g, g * tint.b) * (0.8 + 0.2 * sin(y * 1.6))
			else:
				var u2 := (float(x) / (size - 1)) * 2.0 - 1.0
				var v2 := (float(y) / (size - 1)) * 2.0 - 1.0
				var rr := sqrt(u2 * u2 + v2 * v2)
				var edge := clampf((1.0 - rr) * 12.0, 0.0, 1.0)   # 丸く切り抜く（外は黒）
				c2 = Color(c2.r * tint.r, c2.g * tint.g, c2.b * tint.b) * edge * (1.0 - 0.35 * rr * rr)
			img.set_pixel(x, y, c2)
	return img
