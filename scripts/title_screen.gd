extends CanvasLayer
## タイトル画面：マンション「コーポヨシミ」を空の上から見下ろして、ゆっくり周りを回る俯瞰の背景（ゲーム中にこの視点にはならない）。
## 近くをKO線がゆっくり走り、マンションのエレベーターが上下し、隣のマンションの屋上ではBBQをしている。
## 手前に「はじめる（つづきから）」「設定」「終了」。難易度の選択はない。
## main.gd が、ゲームを止めたままこの画面を重ねる。設定は HUD の設定画面を使う（main が開く）。

signal start_requested(continue_save: bool)
signal settings_requested
signal quit_requested

const MeshKit := preload("res://scripts/mesh_kit.gd")
const HudScript := preload("res://scripts/hud.gd")

const CENTER := Vector3(0.0, 7.5, 0.0)
const ORBIT_RADIUS := 28.0
const ORBIT_HEIGHT := 19.0
const ORBIT_SPEED := 0.055            # rad/秒（一周は約 2 分）
const FLOORS := 5
const FLOOR_H := 3.0
const BUILDING := Vector3(12.0, FLOORS * FLOOR_H, 8.0)
const TRACK_Z := 40.0                 # KO線（マンションの南。高架）
const TRACK_YAW := -10.0              # 度。地図のとおり、西から東へ少し南へ下がる
const DECK_Y := 7.0                   # 高架の線路の高さ
const ROAD_X := 17.0                  # 茶沢通り（マンションの東。北東から南西へ）
const ROAD_YAW := -20.0
const STREET_Z := -24.0               # 北の細い通り
const NEIGHBOR := Vector3(-31.0, 0.0, -12.0)
const NEIGHBOR_SIZE := Vector3(9.0, 18.0, 8.0)
const ELEVATOR_POS := Vector3(7.6, 0.0, -2.5)
const FLY_TIME := 2.8                          # 「はじめる」のあと、503 号室の窓へ飛び込むまでの秒数
const WINDOW_IN := Vector3(1.5, 13.6, 1.6)     # 503 号室（5 階の窓）の奥。ここで暗くなって、ゲームのトイレへ
const WINDOW_LOOK := Vector3(1.5, 13.6, -2.0)

var has_save := false                 # add_child の前に main が設定する
var continue_note := ""               # 「つづきから」に添える、続きの幕の名前

var _viewport: SubViewport
var _camera: Camera3D
var _angle := 0.7
var _time := 0.0
var _font: SystemFont
var _mats := {}
var _elevator: Node3D
var _elev_seq := [4, 0, 2, 3, 1, 4, 0, 3]
var _elev_i := 0
var _elev_wait := 1.5
var _train: Node3D
var _train_x := -60.0
var _train_wait := 1.0
var _road_cars: Array = []
var _people: Array = []
var _arm: Node3D
var _clouds: Array = []
var _buttons: Array[Button] = []
var _menu: VBoxContainer
var _fade: ColorRect
var _ui: Control
var _busy := false
var _fly_t := -1.0                    # 飛び込みの進み（0〜1。負なら周回中）
var _fly_a0 := 0.0                    # 飛び込みを始めたときの周回の角度
var _fly_continue := false
var _fly_done := false


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(HudScript.JP_FONTS)
	_build_view()
	_build_world()
	_build_ui()
	_fade.modulate.a = 1.0
	create_tween().tween_property(_fade, "modulate:a", 0.0, 1.6)


func _process(delta: float) -> void:
	_time += delta
	if _fly_t >= 0.0:
		_update_fly(delta)
		_update_scene(delta)
		return
	_angle += delta * ORBIT_SPEED
	var h := ORBIT_HEIGHT + sin(_time * 0.12) * 1.8
	_camera.position = CENTER + Vector3(sin(_angle) * ORBIT_RADIUS, h - CENTER.y, cos(_angle) * ORBIT_RADIUS)
	_camera.look_at(CENTER, Vector3.UP)
	_camera.position -= _camera.basis.x * 5.0   # マンションを画面の右寄りに置く（左の文字と重ならないように）
	_update_scene(delta)


func _update_scene(delta: float) -> void:
	_update_elevator(delta)
	_update_train(delta)
	for c in _road_cars:
		var n: Node3D = c.node
		n.position.z += float(c.speed) * delta
		if absf(n.position.z) > 100.0:
			n.position.z = -signf(float(c.speed)) * 100.0
	for p in _people:
		var n: Node3D = p.node
		n.position.y = float(p.base) + maxf(0.0, sin(_time * 2.2 + float(p.phase))) * 0.04
		n.rotation.y = float(p.yaw) + sin(_time * 0.7 + float(p.phase)) * 0.35
	if _arm:
		_arm.rotation.x = sin(_time * 3.0) * 0.5 - 0.6
	for c in _clouds:
		var n: Node3D = c.node
		n.position.x += float(c.speed) * delta
		if n.position.x > 130.0:
			n.position.x = -130.0


# ---------------------------------------------------------------- 画面

func _build_view() -> void:
	var cont := SubViewportContainer.new()
	cont.name = "View"
	cont.stretch = true
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cont)
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.handle_input_locally = false
	cont.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 400.0
	_camera.current = true
	_viewport.add_child(_camera)


func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 24
	var root := Control.new()
	root.name = "Ui"
	_ui = root
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 左側を少し暗くして、文字を読みやすくする
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.06, 0.72))
	grad.set_color(1, Color(0.02, 0.03, 0.06, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	var shade := TextureRect.new()
	shade.name = "Shade"
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.anchor_right = 0.5
	shade.anchor_bottom = 1.0

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 88)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 64)
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var title := Label.new()
	title.name = "Title"
	title.text = "コーポヨシミ"
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.07, 0.95))
	title.add_theme_constant_override("outline_size", 14)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	var sub := Label.new()
	sub.name = "Subtitle"
	sub.text = "下南澤（シモミナ）　503号室"
	sub.add_theme_font_size_override("font_size", 34)
	sub.add_theme_color_override("font_color", Color(1.0, 0.9, 0.75))
	sub.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.07, 0.9))
	sub.add_theme_constant_override("outline_size", 8)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override("separation", 10)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # ボタンを画面いっぱいに広げない
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_menu)
	if has_save:
		_add_button("つづきから　%s" % continue_note if not continue_note.is_empty() else "つづきから", func() -> void: _go(true))
		_add_button("はじめから", func() -> void: _go(false))
	else:
		_add_button("はじめる", func() -> void: _go(false))
	_add_button("設定", func() -> void: settings_requested.emit())
	_add_button("終了", func() -> void: quit_requested.emit())
	var note := Label.new()
	note.name = "Note"
	note.text = "↑↓ かマウスで選んで、Enter かクリックで決める"
	note.add_theme_font_size_override("font_size", 16)
	note.modulate = Color(1, 1, 1, 0.6)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(note)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)   # 題名やボタンを消しても、暗幕は残す（_ui の外）
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_menu()


func _add_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 56)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
	b.add_theme_color_override("font_focus_color", Color(1, 0.95, 0.7))
	b.add_theme_stylebox_override("normal", _button_style(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.0)))
	var hover := _button_style(Color(0.15, 0.12, 0.05, 0.6), Color(1.0, 0.85, 0.4, 1.0))
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(callback)
	_menu.add_child(b)
	_buttons.append(b)
	return b


func _button_style(bg: Color, accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = accent
	s.border_width_left = 5
	s.set_corner_radius_all(4)
	s.content_margin_left = 22.0
	s.content_margin_right = 14.0
	return s


## 設定を開いている間は、題名とボタンを隠す（設定の文字と重ならないように）。
func show_ui(on: bool) -> void:
	_ui.visible = on
	if on:
		focus_menu()


func focus_menu() -> void:
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func buttons() -> Array[Button]:
	return _buttons


## 「はじめる」「つづきから」を押したあと、カメラがマンションへ寄って 503 号室の窓をすり抜け、暗くなってから main に知らせる。
func _go(continue_save: bool) -> void:
	if _busy:
		return
	_busy = true
	_fly_continue = continue_save
	_fly_a0 = _angle
	_fly_t = 0.0


func _update_fly(delta: float) -> void:
	_fly_t = minf(_fly_t + delta / FLY_TIME, 1.0)
	var t := _fly_t
	# 前半：周回の円に沿って、503 号室の窓がある南の面へ回り込む。後半：窓へまっすぐ、ぐーっと加速して寄る
	var turn := smoothstep(0.0, 0.5, t)
	var a_front := asin(WINDOW_IN.x / ORBIT_RADIUS)
	var a := lerp_angle(_fly_a0, a_front, turn)
	var h := ORBIT_HEIGHT + sin(_time * 0.12) * 1.8
	var look := CENTER.lerp(WINDOW_LOOK, smoothstep(0.0, 1.0, t))
	_camera.position = CENTER + Vector3(sin(a) * ORBIT_RADIUS, h - CENTER.y, cos(a) * ORBIT_RADIUS)
	_camera.look_at(look, Vector3.UP)
	_camera.position -= _camera.basis.x * 5.0 * (1.0 - smoothstep(0.0, 0.4, t))   # 周回中の横ずらしを、滑らかに戻す
	_camera.position = _camera.position.lerp(WINDOW_IN, pow(t, 1.8))
	_camera.look_at(look, Vector3.UP)
	_camera.fov = lerpf(50.0, 72.0, t)
	_ui.modulate.a = 1.0 - clampf(t / 0.18, 0.0, 1.0)
	_fade.modulate.a = clampf((t - 0.8) / 0.2, 0.0, 1.0)
	if t >= 1.0 and not _fly_done:
		_fly_done = true
		start_requested.emit(_fly_continue)


# ---------------------------------------------------------------- 世界

func _m(color: Color, emit := 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(true), emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _m(color, emit)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(parent: Node, r: float, h: float, pos: Vector3, color: Color, top_r := -1.0, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if top_r < 0.0 else top_r
	cm.height = h
	cm.radial_segments = 14
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _m(color, emit)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _ball(parent: Node, r: float, pos: Vector3, color: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _m(color, emit)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _label(parent: Node, text: String, px: int, pos: Vector3, yaw: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = px
	l.pixel_size = 0.012
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0.1, 0.08, 0.07)
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = false
	parent.add_child(l)
	return l


func _build_world() -> void:
	var world := Node3D.new()
	world.name = "World"
	_viewport.add_child(world)

	# 空・光・霧（夕方の少し前）
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.27, 0.42, 0.74)
	sky_mat.sky_horizon_color = Color(0.98, 0.76, 0.6)
	sky_mat.ground_horizon_color = Color(0.82, 0.66, 0.58)
	sky_mat.ground_bottom_color = Color(0.4, 0.36, 0.4)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.93, 0.78, 0.68)
	env.fog_density = 0.0045
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, -52.0, 0.0)
	sun.light_color = Color(1.0, 0.87, 0.72)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	world.add_child(sun)

	_build_ground(world)
	_build_building(world)
	_build_elevator(world)
	_build_neighbor(world)
	_build_railway(world)
	_build_city(world)
	_build_clouds(world)


func _blocked(p: Vector3, r: float) -> bool:
	if absf(p.x) < 10.0 + r and p.z > -8.0 - r and p.z < 13.0 + r:
		return true   # マンションと前庭
	var ra := deg_to_rad(ROAD_YAW)
	var dir := Vector2(sin(ra), cos(ra))
	if absf((p.x - ROAD_X) * dir.y - p.z * dir.x) < 7.0 + r:
		return true   # 茶沢通り
	if absf(p.z - TRACK_Z - 0.176 * p.x) < 9.0 + r:
		return true   # 高架と、その下の道
	if absf(p.z - STREET_Z) < 5.0 + r:
		return true   # 北の細い通り
	if absf(p.x - NEIGHBOR.x) < NEIGHBOR_SIZE.x * 0.5 + 2.0 + r and absf(p.z - NEIGHBOR.z) < NEIGHBOR_SIZE.z * 0.5 + 2.0 + r:
		return true
	if absf(p.x - 12.0) < 11.0 + r and absf(p.z + 33.0) < 8.0 + r:
		return true   # タウンホール
	return p.distance_to(ELEVATOR_POS) < 4.0 + r


func _build_ground(world: Node3D) -> void:
	_box(world, Vector3(520, 0.4, 520), Vector3(0, -0.2, 0), Color(0.36, 0.42, 0.34))
	# 茶沢通り（マンションの東、北東から南西へ。高架の下をくぐる）と、走る車
	var road := Node3D.new()
	road.name = "ChazawaDori"
	road.position = Vector3(ROAD_X, 0, 0)
	road.rotation_degrees.y = ROAD_YAW
	world.add_child(road)
	_box(road, Vector3(8.0, 0.06, 320), Vector3(0, 0.03, 0), Color(0.22, 0.22, 0.25))
	for sx in [-1.0, 1.0]:
		_box(road, Vector3(1.6, 0.12, 320), Vector3(sx * 4.8, 0.06, 0), Color(0.62, 0.6, 0.57))
	for i in 60:
		_box(road, Vector3(0.14, 0.07, 1.6), Vector3(0, 0.04, -148.0 + i * 5.0), Color(0.95, 0.95, 0.9))
	for i in 3:
		var car := Node3D.new()
		car.position = Vector3(-1.9 + (i % 2) * 3.8, 0.0, -60.0 + i * 55.0)
		road.add_child(car)
		var col: Color = [Color(0.8, 0.25, 0.2), Color(0.25, 0.4, 0.7), Color(0.9, 0.85, 0.7)][i]
		_box(car, Vector3(1.7, 0.8, 3.8), Vector3(0, 0.6, 0), col)
		_box(car, Vector3(1.6, 0.7, 2.0), Vector3(0, 1.3, -0.2), col.darkened(0.15))
		_box(car, Vector3(1.62, 0.5, 1.9), Vector3(0, 1.32, -0.2), Color(0.2, 0.28, 0.4))
		_road_cars.append({"node": car, "speed": 4.2 if i % 2 == 0 else -3.4})
	# 北の細い通り
	_box(world, Vector3(520, 0.06, 6.0), Vector3(0, 0.03, STREET_Z), Color(0.24, 0.24, 0.27))
	# 前庭の駐車場
	_box(world, Vector3(14, 0.05, 6), Vector3(0, 0.025, 11.5), Color(0.55, 0.53, 0.5))
	for i in 5:
		_box(world, Vector3(0.12, 0.06, 4.0), Vector3(-5.2 + i * 2.6, 0.03, 11.5), Color(0.95, 0.95, 0.9))
	# 木（街路樹と庭）
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var placed := 0
	var guard := 0
	while placed < 16 and guard < 400:
		guard += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(10.0, 30.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if _blocked(p, 1.0):
			continue
		var h := rng.randf_range(2.2, 4.0)
		_cyl(world, 0.18, h, Vector3(p.x, h * 0.5, p.z), Color(0.36, 0.26, 0.18))
		_ball(world, rng.randf_range(1.3, 2.0), Vector3(p.x, h + 0.7, p.z), Color(0.27, 0.45, 0.28).lightened(rng.randf() * 0.15))
		placed += 1
	_build_hall(world)


## 北のタウンホール（茶色い屋根の大きな低い建物）。地図の目印。
func _build_hall(world: Node3D) -> void:
	var h := Node3D.new()
	h.name = "TownHall"
	h.position = Vector3(12.0, 0.0, -33.0)
	world.add_child(h)
	_box(h, Vector3(20, 9.0, 14), Vector3(0, 4.5, 0), Color(0.78, 0.74, 0.68))
	_box(h, Vector3(20.6, 0.6, 14.6), Vector3(0, 9.3, 0), Color(0.55, 0.3, 0.2))
	_box(h, Vector3(8, 1.6, 6), Vector3(3, 10.4, -1), Color(0.5, 0.28, 0.2))
	for i in 5:
		_box(h, Vector3(2.2, 3.0, 0.12), Vector3(-7.0 + i * 3.5, 4.0, 7.04), Color(0.28, 0.36, 0.48))
	_label(h, "ヨシミタウンホール", 80, Vector3(0, 7.2, 7.15), 0.0, Color(1.0, 0.96, 0.85))


func _build_building(world: Node3D) -> void:
	var b := Node3D.new()
	b.name = "Building"
	world.add_child(b)
	var wall := Color(0.76, 0.7, 0.6)
	_box(b, BUILDING, Vector3(0, BUILDING.y * 0.5, 0), wall)
	_box(b, Vector3(12.5, 0.4, 8.5), Vector3(0, BUILDING.y + 0.2, 0), Color(0.55, 0.52, 0.5))
	_box(b, Vector3(12.5, 0.7, 0.2), Vector3(0, BUILDING.y + 0.75, 4.15), Color(0.8, 0.77, 0.7))
	_box(b, Vector3(12.5, 0.7, 0.2), Vector3(0, BUILDING.y + 0.75, -4.15), Color(0.8, 0.77, 0.7))
	# 屋上の給水タンクと看板
	_cyl(b, 1.3, 2.0, Vector3(-3.5, BUILDING.y + 1.4, -1.0), Color(0.7, 0.72, 0.75))
	for sx in [-1.0, 1.0]:
		_box(b, Vector3(0.2, 1.4, 0.2), Vector3(sx * 2.8, BUILDING.y + 1.0, 3.3), Color(0.45, 0.45, 0.48))
	_box(b, Vector3(7.4, 1.7, 0.3), Vector3(0, BUILDING.y + 2.2, 3.3), Color(0.16, 0.2, 0.3))
	_label(b, "コーポヨシミ", 110, Vector3(0, BUILDING.y + 2.2, 3.47), 0.0, Color(1.0, 0.96, 0.82))
	_label(b, "コーポヨシミ", 110, Vector3(0, BUILDING.y + 2.2, 3.13), PI, Color(1.0, 0.96, 0.82))
	# 窓・ベランダ（南）・廊下（北）
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var glass := Color(0.24, 0.33, 0.48)
	var lamp := Color(1.0, 0.82, 0.5)
	for f in FLOORS:
		var y := 1.7 + f * FLOOR_H
		for ix in 4:
			var x := -4.5 + ix * 3.0
			var lit := rng.randf() < 0.4
			if f == FLOORS - 1 and ix == 2:
				lit = true   # 503 号室
			_box(b, Vector3(1.7, 1.4, 0.12), Vector3(x, y, 4.04), lamp if lit else glass, 0.8 if lit else 0.0)
			_box(b, Vector3(1.7, 1.4, 0.12), Vector3(x, y, -4.04), lamp if rng.randf() < 0.3 else glass, 0.0)
		for sz in [-1.8, 1.8]:
			_box(b, Vector3(0.12, 1.2, 1.2), Vector3(6.04, y, sz), glass)
			_box(b, Vector3(0.12, 1.2, 1.2), Vector3(-6.04, y, sz), glass)
		var floor_y := f * FLOOR_H + 0.1
		for bx in [-3.0, 3.0]:
			_box(b, Vector3(3.2, 0.16, 1.3), Vector3(bx, floor_y + 0.9, 4.65), Color(0.7, 0.68, 0.64))
			_box(b, Vector3(3.2, 0.95, 0.06), Vector3(bx, floor_y + 1.45, 5.25), Color(0.93, 0.93, 0.9))
			_box(b, Vector3(0.06, 0.95, 1.3), Vector3(bx - 1.57, floor_y + 1.45, 4.65), Color(0.93, 0.93, 0.9))
			_box(b, Vector3(0.06, 0.95, 1.3), Vector3(bx + 1.57, floor_y + 1.45, 4.65), Color(0.93, 0.93, 0.9))
		_box(b, Vector3(12.0, 0.16, 1.2), Vector3(0, floor_y + 0.9, -4.6), Color(0.68, 0.66, 0.62))
		_box(b, Vector3(12.0, 0.95, 0.06), Vector3(0, floor_y + 1.45, -5.17), Color(0.88, 0.88, 0.85))
		for dx in 4:
			_box(b, Vector3(0.9, 1.9, 0.08), Vector3(-4.5 + dx * 3.0, floor_y + 1.05, -4.04), Color(0.4, 0.3, 0.24))
	_build_entrance_front(b)


## 1 階の入口（ゲームの中の 1 階と同じ造り）：黒ずんだレンガの土台に、レンガのアーチの口と鉄の門、壁灯、蔦。
## 石のタイルの前庭。503 号室のベランダの真下には、白い自動販売機。
func _build_entrance_front(b: Node3D) -> void:
	var brick := Color(0.2, 0.1, 0.085)
	var brick_light := Color(0.42, 0.2, 0.15)
	var dark := Color(0.03, 0.03, 0.04)
	var iron := Color(0.15, 0.17, 0.21)
	# 1 階の壁を、黒ずんだレンガにする
	_box(b, Vector3(BUILDING.x + 0.1, FLOOR_H, 0.16), Vector3(0, FLOOR_H * 0.5, 4.08), brick)
	# アーチの口（暗い）と、縁のレンガ
	_box(b, Vector3(1.6, 1.6, 0.1), Vector3(0, 0.8, 4.18), dark)
	var top := _cyl(b, 0.8, 0.1, Vector3(0, 1.6, 4.18), dark)
	top.rotation.x = deg_to_rad(90.0)
	for k in 13:
		var a := PI * (k + 0.5) / 13.0
		var r := 0.95
		var v := _box(b, Vector3(0.22, 0.2, 0.2), Vector3(cos(a) * r, 1.6 + sin(a) * r, 4.2), brick_light)
		v.rotation.z = a - PI * 0.5
	# 開いた鉄の門扉（左右）
	for sx in [-1.0, 1.0]:
		_box(b, Vector3(0.05, 1.7, 0.7), Vector3(sx * 0.95, 0.85, 4.55), iron).rotation.y = deg_to_rad(18.0 * sx)
	# 壁灯（暖色の二つの球）
	_ball(b, 0.12, Vector3(-1.45, 2.3, 4.3), Color(1.0, 0.85, 0.55), 2.2)
	_ball(b, 0.12, Vector3(-1.2, 2.3, 4.3), Color(1.0, 0.85, 0.55), 2.2)
	# 蔦（右側）
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 40:
		var c := Color(0.12 + rng.randf() * 0.2, 0.28 + rng.randf() * 0.25, 0.1)
		_ball(b, rng.randf_range(0.12, 0.3), Vector3(rng.randf_range(1.5, 2.4), rng.randf_range(0.2, 2.6), rng.randf_range(4.2, 4.6)), c)
	# 前庭のタイル
	_box(b, Vector3(3.2, 0.06, 2.4), Vector3(0, 0.03, 5.3), Color(0.86, 0.69, 0.5))
	# 503 号室のベランダ（x 3）の真下の、白い自動販売機
	_box(b, Vector3(0.9, 1.8, 0.7), Vector3(3.0, 0.9, 4.6), Color(0.92, 0.93, 0.95))
	_box(b, Vector3(0.7, 0.7, 0.04), Vector3(3.0, 1.3, 4.96), Color(0.95, 0.96, 1.0), 1.0)
	_box(b, Vector3(0.5, 0.14, 0.04), Vector3(2.95, 0.3, 4.96), Color(0.1, 0.1, 0.12))


func _build_elevator(world: Node3D) -> void:
	var e := Node3D.new()
	e.name = "ElevatorShaft"
	e.position = ELEVATOR_POS
	world.add_child(e)
	var steel := Color(0.52, 0.55, 0.6)
	var h := BUILDING.y + 0.8
	for sx in [-1.1, 1.1]:
		for sz in [-1.1, 1.1]:
			_box(e, Vector3(0.16, h, 0.16), Vector3(sx, h * 0.5, sz), steel)
	for i in FLOORS + 1:
		var y := i * FLOOR_H + 0.1
		_box(e, Vector3(2.4, 0.08, 0.1), Vector3(0, y, -1.1), steel)
		_box(e, Vector3(2.4, 0.08, 0.1), Vector3(0, y, 1.1), steel)
		_box(e, Vector3(0.1, 0.08, 2.4), Vector3(-1.1, y, 0), steel)
		_box(e, Vector3(0.1, 0.08, 2.4), Vector3(1.1, y, 0), steel)
	_box(e, Vector3(2.6, 0.2, 2.6), Vector3(0, h, 0), Color(0.45, 0.47, 0.5))
	_elevator = Node3D.new()
	_elevator.position = Vector3(0, 1.3 + _elev_seq[0] * FLOOR_H, 0)
	e.add_child(_elevator)
	_box(_elevator, Vector3(1.8, 2.3, 1.8), Vector3.ZERO, Color(0.78, 0.82, 0.86))
	_box(_elevator, Vector3(1.4, 1.5, 0.05), Vector3(0, 0.1, 0.92), Color(1.0, 0.95, 0.75), 0.9)
	_box(_elevator, Vector3(0.05, 1.5, 1.4), Vector3(0.92, 0.1, 0), Color(1.0, 0.95, 0.75), 0.9)
	_box(_elevator, Vector3(0.05, 1.5, 1.4), Vector3(-0.92, 0.1, 0), Color(1.0, 0.95, 0.75), 0.9)


func _update_elevator(delta: float) -> void:
	var target: float = 1.3 + float(_elev_seq[_elev_i]) * FLOOR_H
	if absf(_elevator.position.y - target) < 0.02:
		_elev_wait -= delta
		if _elev_wait <= 0.0:
			_elev_i = (_elev_i + 1) % _elev_seq.size()
			_elev_wait = 2.2
	else:
		_elevator.position.y = move_toward(_elevator.position.y, target, 2.4 * delta)


func _build_neighbor(world: Node3D) -> void:
	var n := Node3D.new()
	n.name = "NeighborBuilding"
	n.position = NEIGHBOR
	world.add_child(n)
	var sx := NEIGHBOR_SIZE.x
	var sz := NEIGHBOR_SIZE.z
	_box(n, NEIGHBOR_SIZE, Vector3(0, NEIGHBOR_SIZE.y * 0.5, 0), Color(0.72, 0.74, 0.78))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for f in 6:
		for ix in 3:
			var lit := rng.randf() < 0.35
			_box(n, Vector3(1.6, 1.3, 0.12), Vector3(-3.0 + ix * 3.0, 1.6 + f * 3.0, sz * 0.5 + 0.04), Color(1.0, 0.82, 0.5) if lit else Color(0.26, 0.34, 0.46), 0.7 if lit else 0.0)
			_box(n, Vector3(1.6, 1.3, 0.12), Vector3(-3.0 + ix * 3.0, 1.6 + f * 3.0, -sz * 0.5 - 0.04), Color(0.26, 0.34, 0.46))
	var top := NEIGHBOR_SIZE.y
	_box(n, Vector3(sx + 0.3, 0.3, sz + 0.3), Vector3(0, top + 0.15, 0), Color(0.5, 0.5, 0.52))
	# 屋上の柵
	_box(n, Vector3(sx + 0.3, 1.0, 0.15), Vector3(0, top + 0.8, sz * 0.5 + 0.1), Color(0.8, 0.8, 0.82))
	_box(n, Vector3(sx + 0.3, 1.0, 0.15), Vector3(0, top + 0.8, -sz * 0.5 - 0.1), Color(0.8, 0.8, 0.82))
	_box(n, Vector3(0.15, 1.0, sz + 0.3), Vector3(sx * 0.5 + 0.1, top + 0.8, 0), Color(0.8, 0.8, 0.82))
	_box(n, Vector3(0.15, 1.0, sz + 0.3), Vector3(-sx * 0.5 - 0.1, top + 0.8, 0), Color(0.8, 0.8, 0.82))
	var roof := Node3D.new()
	roof.position = Vector3(0, top + 0.3, 0)
	n.add_child(roof)
	# BBQ コンロ（炭が赤く光る）と煙
	var grill := Node3D.new()
	grill.position = Vector3(1.4, 0, 0.2)
	roof.add_child(grill)
	for gx in [-0.45, 0.45]:
		for gz in [-0.25, 0.25]:
			_cyl(grill, 0.04, 0.7, Vector3(gx, 0.35, gz), Color(0.15, 0.15, 0.16))
	_box(grill, Vector3(1.1, 0.25, 0.7), Vector3(0, 0.8, 0), Color(0.12, 0.12, 0.13))
	_box(grill, Vector3(1.0, 0.05, 0.6), Vector3(0, 0.93, 0), Color(1.0, 0.35, 0.1), 2.2)
	_add_smoke(grill, Vector3(0, 1.0, 0))
	# テーブル・椅子・パラソル・飾りの電球
	var table := Node3D.new()
	table.position = Vector3(-1.2, 0, 0.6)
	roof.add_child(table)
	_box(table, Vector3(2.2, 0.08, 1.0), Vector3(0, 0.75, 0), Color(0.62, 0.45, 0.3))
	for tx in [-1.0, 1.0]:
		for tz in [-0.4, 0.4]:
			_box(table, Vector3(0.06, 0.75, 0.06), Vector3(tx, 0.37, tz), Color(0.4, 0.3, 0.2))
	_box(table, Vector3(0.5, 0.12, 0.3), Vector3(0.3, 0.85, 0.1), Color(0.9, 0.3, 0.25))
	_box(table, Vector3(0.3, 0.14, 0.3), Vector3(-0.5, 0.86, -0.1), Color(0.95, 0.9, 0.5))
	_cyl(table, 0.03, 2.2, Vector3(0, 1.1, -0.9), Color(0.8, 0.8, 0.8))
	_cyl(table, 1.3, 0.35, Vector3(0, 2.3, -0.9), Color(0.9, 0.25, 0.22), 0.05)
	for i in 8:
		_ball(roof, 0.07, Vector3(-3.8 + i * 1.1, 2.3 + sin(i * 1.4) * -0.15, sz * 0.5 - 0.3), Color(1.0, 0.9, 0.55), 2.0)
	# 人（円柱の体と球の頭）
	var specs := [
		[Vector3(-2.6, 0, 0.6), 0.5, Color(0.85, 0.3, 0.3), 0.0],
		[Vector3(-1.0, 0, 1.7), PI, Color(0.3, 0.55, 0.8), 1.3],
		[Vector3(0.0, 0, 0.9), -1.2, Color(0.9, 0.75, 0.3), 2.1],
		[Vector3(1.4, 0, -0.9), 0.0, Color(0.95, 0.95, 0.9), 0.6],
	]
	for i in specs.size():
		var s: Array = specs[i]
		var person := Node3D.new()
		person.position = s[0]
		roof.add_child(person)
		_cyl(person, 0.22, 0.85, Vector3(0, 0.62, 0), s[2])
		_ball(person, 0.17, Vector3(0, 1.22, 0), Color(0.95, 0.78, 0.62))
		_ball(person, 0.18, Vector3(0, 1.28, -0.02), Color(0.2, 0.15, 0.12).lightened(0.05 * i))
		_cyl(person, 0.09, 0.45, Vector3(-0.1, 0.1, 0), Color(0.25, 0.28, 0.4))
		_cyl(person, 0.09, 0.45, Vector3(0.1, 0.1, 0), Color(0.25, 0.28, 0.4))
		if i == 3:   # 焼く人：腕（トングを持って上下する）
			_arm = Node3D.new()
			_arm.position = Vector3(0.2, 0.95, 0)
			person.add_child(_arm)
			_box(_arm, Vector3(0.1, 0.1, 0.6), Vector3(0, 0, -0.3), Color(0.95, 0.78, 0.62))
		_people.append({"node": person, "phase": s[3], "base": person.position.y, "yaw": float(s[1])})


func _add_smoke(parent: Node3D, pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 22
	p.lifetime = 4.5
	p.preprocess = 4.0
	p.direction = Vector3.UP
	p.spread = 14.0
	p.gravity = Vector3(0.3, 0.35, 0.0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.88, 0.88, 0.9, 0.5))
	ramp.set_color(1, Color(0.88, 0.88, 0.9, 0.0))
	p.color_ramp = ramp
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1)
	sm.material = mat
	p.mesh = sm
	p.emitting = true
	parent.add_child(p)


func _build_railway(world: Node3D) -> void:
	var rail := Node3D.new()
	rail.name = "KoLine"
	rail.position = Vector3(0, 0, TRACK_Z)
	rail.rotation_degrees.y = TRACK_YAW
	world.add_child(rail)
	var concrete := Color(0.66, 0.64, 0.6)
	# 高架：床・防護壁・橋脚（茶沢通りが通る所は、橋脚を抜く）
	_box(rail, Vector3(420, 0.9, 4.6), Vector3(0, DECK_Y - 0.45, 0), concrete)
	_box(rail, Vector3(420, 0.4, 3.6), Vector3(0, DECK_Y + 0.2, 0), Color(0.5, 0.47, 0.44))
	for z in [-0.72, 0.72]:
		_box(rail, Vector3(420, 0.12, 0.1), Vector3(0, DECK_Y + 0.46, z), Color(0.72, 0.72, 0.75))
	for z in [-2.3, 2.3]:
		_box(rail, Vector3(420, 0.7, 0.2), Vector3(0, DECK_Y + 0.35, z), concrete.lightened(0.1))
	for i in 46:
		var x := -200.0 + i * 9.0
		var wp: Vector3 = rail.transform * Vector3(x, 0, 0)
		var ra := deg_to_rad(ROAD_YAW)
		if absf((wp.x - ROAD_X) * cos(ra) - wp.z * sin(ra)) < 8.0:
			continue
		for z in [-1.5, 1.5]:
			_box(rail, Vector3(1.1, DECK_Y - 0.9, 1.1), Vector3(x, (DECK_Y - 0.9) * 0.5, z), concrete.darkened(0.05))
		_box(rail, Vector3(1.3, 0.6, 4.2), Vector3(x, DECK_Y - 1.2, 0), concrete)
	# 高架の下の道（線路に沿う）と、サイクルパーク
	_box(rail, Vector3(420, 0.06, 7.0), Vector3(0, 0.03, 0), Color(0.24, 0.24, 0.27))
	_box(rail, Vector3(420, 0.07, 0.15), Vector3(0, 0.04, 0), Color(0.9, 0.85, 0.5))
	_box(rail, Vector3(7.5, 0.1, 3.0), Vector3(-24.0, 0.06, 5.2), Color(0.5, 0.58, 0.5))
	_box(rail, Vector3(5.6, 1.0, 0.1), Vector3(-24.0, 4.2, 2.35), Color(0.12, 0.4, 0.28))
	_label(rail, "KOサイクルパーク", 46, Vector3(-24.0, 4.2, 2.42), 0.0, Color(1, 1, 1))
	for i in 9:
		_box(rail, Vector3(0.12, 0.7, 1.5), Vector3(-27.0 + i * 0.7, 0.4, 5.2), [Color(0.2, 0.3, 0.7), Color(0.8, 0.25, 0.2), Color(0.85, 0.85, 0.85)][i % 3])
	# 架線の柱
	for i in 20:
		var x2 := -95.0 + i * 10.0
		_cyl(rail, 0.12, 6.0, Vector3(x2, DECK_Y + 3.0, -1.9), Color(0.5, 0.52, 0.55))
		_box(rail, Vector3(0.1, 0.1, 2.4), Vector3(x2, DECK_Y + 5.8, -0.7), Color(0.5, 0.52, 0.55))
	_box(rail, Vector3(420, 0.04, 0.04), Vector3(0, DECK_Y + 5.6, 0.0), Color(0.2, 0.2, 0.22))
	# 電車（4 両。高架の上をゆっくり走る）
	_train = Node3D.new()
	_train.position = Vector3(_train_x, DECK_Y + 0.62, 0)
	rail.add_child(_train)
	for i in 4:
		var car := Node3D.new()
		car.position = Vector3(i * 6.4, 1.3, 0)
		_train.add_child(car)
		_box(car, Vector3(6.0, 2.5, 2.5), Vector3.ZERO, Color(0.93, 0.92, 0.86))
		_box(car, Vector3(6.02, 0.35, 2.52), Vector3(0, -0.5, 0), Color(0.15, 0.5, 0.5))
		_box(car, Vector3(5.2, 0.85, 2.55), Vector3(0, 0.45, 0), Color(0.22, 0.3, 0.4))
		for w in 3:
			_box(car, Vector3(0.06, 0.9, 2.56), Vector3(-1.8 + w * 1.8, 0.45, 0), Color(0.93, 0.92, 0.86))
		_box(car, Vector3(5.6, 0.2, 2.2), Vector3(0, 1.35, 0), Color(0.55, 0.57, 0.6))
		_box(car, Vector3(5.2, 0.1, 2.4), Vector3(0, -0.2, 0), Color(1.0, 0.92, 0.7), 0.5)
	_box(_train, Vector3(0.1, 0.4, 1.4), Vector3(-3.05, 1.2, 0), Color(1.0, 0.95, 0.75), 1.5)
	_update_train(0.0)


func _update_train(delta: float) -> void:
	if _train_x > 130.0:
		_train_wait -= delta
		_train.visible = false
		if _train_wait <= 0.0:
			_train_x = -140.0
			_train_wait = 5.0
	else:
		_train.visible = true
		_train_x += 3.2 * delta
	_train.position.x = _train_x


func _build_city(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var placed := 0
	var guard := 0
	while placed < 330 and guard < 9000:
		guard += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(15.0, 140.0 if placed > 200 else 70.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var near := r < 40.0
		var w := rng.randf_range(4.0, 9.0) if near else rng.randf_range(6.0, 14.0)
		var d := rng.randf_range(4.0, 9.0) if near else rng.randf_range(6.0, 12.0)
		if _blocked(p, maxf(w, d) * 0.5 + 0.5):
			continue
		# 軌道（半径 25・高さ 17）にぶつからないよう、近くは低く（2〜3 階建ての店・住宅）
		var h := rng.randf_range(3.5, 9.0) if near else (rng.randf_range(14.0, 42.0) if r > 70.0 else rng.randf_range(8.0, 22.0))
		if r > 20.0 and r < 40.0:
			h = minf(h, 9.0)
		var c := Color(0.5, 0.52, 0.58).lerp(Color(0.74, 0.64, 0.56), rng.randf())
		_box(world, Vector3(w, h, d), Vector3(p.x, h * 0.5, p.z), c)
		if rng.randf() < 0.6:
			_box(world, Vector3(w * 0.9, 0.5, d * 0.9), Vector3(p.x, h + 0.2, p.z), c.darkened(0.2))
		if near and rng.randf() < 0.5:   # 店先のひさし
			_box(world, Vector3(w * 0.9, 0.12, 1.2), Vector3(p.x, 2.6, p.z + d * 0.5 + 0.6), [Color(0.8, 0.3, 0.25), Color(0.25, 0.5, 0.45), Color(0.9, 0.75, 0.3)][rng.randi() % 3])
		placed += 1


func _build_clouds(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 7:
		var cloud := Node3D.new()
		cloud.position = Vector3(rng.randf_range(-130.0, 130.0), rng.randf_range(46.0, 60.0), rng.randf_range(-120.0, 120.0))
		world.add_child(cloud)
		for j in 4:
			var s := rng.randf_range(5.0, 9.0)
			var ball := _ball(cloud, s, Vector3(j * 6.0 - 9.0, rng.randf_range(-1.0, 1.0), rng.randf_range(-3.0, 3.0)), Color(1.0, 0.97, 0.94, 0.92))
			ball.scale = Vector3(1.0, 0.45, 0.8)
			ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_clouds.append({"node": cloud, "speed": rng.randf_range(0.6, 1.4)})
