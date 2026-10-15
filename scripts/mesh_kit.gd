extends RefCounted
## 基本形状とマテリアルを作る共通ヘルパー（room.gd と各設備スクリプトで共用）。
## 物理レイヤーの値もここに置き、設備スクリプトから参照する。

const LAYER_WORLD := 1      # 壁・設備（プレイヤーがぶつかる）
const LAYER_INTERACT := 2   # 照準だけ当たる（ぶつからない）
const LAYER_BODY_ONLY := 16 # 体だけを止める透明な板（照準のレイは通す。layer 5）

static var _mat_cache := {}
static var _round_cache := {}
## 箱の角を丸めるか。壁・床・換気経路などの外殻を作る間は false にする（角の合わせ目に溝が出ないように）
static var auto_round := true
const ROUND_MAX := 0.015          # 角の半径の上限（m）
const ROUND_MIN := 0.002          # これより小さくなる薄い板は丸めない
const ROUND_LONG_LIMIT := 2.0     # 長い辺がこれより長い箱（本棚の長い板など）は丸めない
static var _water_noise: NoiseTexture2D


static func box(parent: Node, size: Vector3, center: Vector3, material: Material, node_name := "") -> MeshInstance3D:
	var r := minf(ROUND_MAX, minf(size.x, minf(size.y, size.z)) * 0.25)
	if auto_round and r >= ROUND_MIN and maxf(size.x, maxf(size.y, size.z)) <= ROUND_LONG_LIMIT:
		return _instance(parent, rounded_box_mesh(size, r), center, material, node_name)
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, center, material, node_name)


## 角を半径 r で丸めた箱（各面を格子に分け、角の部分だけ内側の箱からの球面へ押し出す）。大きさごとに使い回す。
static func rounded_box_mesh(size: Vector3, r: float) -> ArrayMesh:
	var key := "%.4f_%.4f_%.4f_%.4f" % [size.x, size.y, size.z, r]
	if _round_cache.has(key):
		return _round_cache[key]
	var seg := 3
	var h := size * 0.5
	var inner := h - Vector3(r, r, r)
	var coords := []   # 軸ごとの格子の座標
	for ax in 3:
		var c := []
		for k in seg + 1:
			c.append(-inner[ax] - r * cos(k * PI * 0.5 / seg))
		for k in range(seg, -1, -1):
			c.append(inner[ax] + r * cos(k * PI * 0.5 / seg))
		coords.append(c)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for ax in 3:
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		for sgn in [-1.0, 1.0]:
			var base := verts.size()
			var cu: Array = coords[u]
			var cv: Array = coords[v]
			for i in cu.size():
				for j in cv.size():
					var p := Vector3.ZERO
					p[ax] = sgn * h[ax]
					p[u] = cu[i]
					p[v] = cv[j]
					var q := p.clamp(-inner, inner)
					var n := (p - q).normalized()
					verts.append(q + n * r)
					normals.append(n)
					uvs.append(Vector2(float(i) / (cu.size() - 1), float(j) / (cv.size() - 1)))
			var nv: int = cv.size()
			for i in cu.size() - 1:
				for j in nv - 1:
					var a := base + i * nv + j
					var b := a + nv
					for tri in [[a, b, a + 1], [b, b + 1, a + 1]]:
						# Godot の表面は時計回り：外向きの法線と外積が逆向きになるようにそろえる
						var A := verts[tri[0]]
						var B := verts[tri[1]]
						var C := verts[tri[2]]
						var nn := normals[tri[0]] + normals[tri[1]] + normals[tri[2]]
						if (B - A).cross(C - A).dot(nn) > 0.0:
							indices.append_array([tri[0], tri[2], tri[1]])
						else:
							indices.append_array(tri)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_round_cache[key] = mesh
	return mesh


## Y 軸方向の円柱。top_radius を変えると円すい台になる。
static func cylinder(parent: Node, radius: float, height: float, center: Vector3, material: Material,
		node_name := "", top_radius := -1.0, segments := 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _instance(parent, mesh, center, material, node_name)


## 十円玉のふた（排水口にはめる円盤）。縁が少し盛り上がり、中央に飾りの円がある。原点が円盤の中心。
static func coin10_disc(parent: Node, radius: float, thickness := 0.0016) -> Node3D:
	var n := Node3D.new()
	n.name = "Coin"
	parent.add_child(n)
	var body := mat("coin10", Color(0.62, 0.36, 0.2), 0.4, 0.7)
	var light := mat("coin10_rim", Color(0.74, 0.46, 0.27), 0.3, 0.8)
	cylinder(n, radius, thickness, Vector3.ZERO, body, "Disc", -1.0, 32)
	var rim := TorusMesh.new()
	rim.inner_radius = radius * 0.86
	rim.outer_radius = radius * 0.995
	rim.rings = 32
	rim.ring_segments = 6
	var rim_mi := MeshInstance3D.new()
	rim_mi.name = "Rim"
	rim_mi.mesh = rim
	rim_mi.material_override = light
	rim_mi.position = Vector3(0, thickness * 0.5, 0)
	rim_mi.scale = Vector3(1, 0.12, 1)
	n.add_child(rim_mi)
	cylinder(n, radius * 0.42, 0.0003, Vector3(0, thickness * 0.5 + 0.00005, 0), light, "Emblem", -1.0, 24)
	return n


## 点列を細い円柱でつないだ管（排水管・トラップ・タオル掛けなど）。継ぎ目は小さな球で埋める。
static func pipe(parent: Node, points: Array, radius: float, material: Material) -> void:
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg := cylinder(parent, radius, a.distance_to(b), (a + b) * 0.5, material, "", -1.0, 12)
		var dir := (b - a).normalized()
		if absf(dir.dot(Vector3.UP)) < 0.999:
			seg.basis = Basis(Quaternion(Vector3.UP, dir))
		if i > 0:
			sphere(parent, radius, a, material)


static func sphere(parent: Node, radius: float, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _instance(parent, mesh, center, material, "")


## 蓋のない円筒の帯（ラベル用）。u は円周方向 0〜1、v は上 0〜下 1。
## a_center：u=0.5 が向く角度（法線 = (cos a, 0, -sin a)。0 なら +x）／span：帯が覆う角度（TAU で一周）。
## r_bottom と r_top を変えると先細りの筒（チューブ）に沿わせられる。外側から見て画像が左右反転しない向きに巻く。
static func band(r_bottom: float, r_top: float, height: float, a_center: float, span: float, segments: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in segments + 1:
		var u := float(i) / segments
		var a := a_center + span * (u - 0.5)
		var n := Vector3(cos(a), 0.0, -sin(a))
		for row in 2:
			var r := r_top if row == 0 else r_bottom
			verts.append(n * r + Vector3(0.0, height * (0.5 - row), 0.0))
			normals.append(n)
			uvs.append(Vector2(u, row))
	for i in segments:
		var t0 := i * 2      # 上
		var b0 := i * 2 + 1  # 下
		indices.append_array([t0, t0 + 2, b0, t0 + 2, b0 + 2, b0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func shape_box(body: CollisionObject3D, size: Vector3, center: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = center
	body.add_child(cs)
	return cs


## 照準だけが当たる「調べる」判定（interact レイヤー、ぶつからない）。
## fixture を渡すと、main.gd はその設備の get_prompt()／interact() に処理を任せる。
static func interact_area(parent: Node, area_name: String, interact_id: String, fixture: Object = null) -> Area3D:
	var area := Area3D.new()
	area.name = area_name
	area.collision_layer = LAYER_INTERACT
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("interact_id", interact_id)
	if fixture:
		area.set_meta("fixture", fixture)
	parent.add_child(area)
	return area


static func mat(key: String, color: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_add_surface_detail(m, key, color)
	_mat_cache[key] = m
	return m


# ---------------------------------------------------------------- 面の細かな表情（ただの単色にしない）

## 単色の物にも、木目・しわ・汚れの薄い模様を重ねる（トリプラナー。色は元の色のまま、明るさだけがゆらぐ）。
## 光る物・透ける物・発光する物は、そのままにする。
const _NO_DETAIL := ["glass", "water", "glow", "lamp", "lit", "emiss", "screen", "sky", "flame", "star", "light", "bulb", "led", "shadow", "dot", "crack", "mist", "smoke", "beam"]
static var _detail_tex := {}


static func _add_surface_detail(m: StandardMaterial3D, key: String, color: Color) -> void:
	if color.a < 0.99:
		return
	for w in _NO_DETAIL:
		if key.contains(w):
			return
	var kind := "grime"
	var tile := 0.8
	for w in ["wood", "desk", "shelf", "closet", "table", "chair", "rail", "door", "floor", "plank", "frame", "stand", "cabinet", "butsudan", "lacquer", "board"]:
		if key.contains(w):
			kind = "grain"
			tile = 0.5
			break
	if kind == "grime":
		for w in ["futon", "fab", "cloth", "cushion", "zabuton", "blanket", "towel", "curtain", "sheet", "rug", "mat_", "pillow", "tatami", "paper", "cover", "bag", "teddy"]:
			if key.contains(w):
				kind = "wrinkle"
				tile = 0.4
				break
	if kind == "grime" and m.metallic > 0.3:
		kind = "scratch"
		tile = 0.3
	m.albedo_texture = _detail_texture(kind)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE / tile
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.albedo_color = Color(minf(color.r * 1.07, 1.0), minf(color.g * 1.07, 1.0), minf(color.b * 1.07, 1.0), color.a)


static func _detail_texture(kind: String) -> ImageTexture:
	if _detail_tex.has(kind):
		return _detail_tex[kind]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 11 + kind.length()
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	var base := noise.get_seamless_image(n, n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90 + kind.length()
	for y in n:
		for x in n:
			var v := base.get_pixel(x, y).r   # 0〜1
			var g := 0.9 + 0.1 * v
			match kind:
				"grain":
					# 木目：縦に細長い筋（x が細かく、y がゆるく変わる）
					var u := sin(float(x) * 0.55 + v * 7.0) * 0.5 + 0.5
					g = 0.84 + 0.09 * v + 0.07 * u
				"wrinkle":
					# しわ：やわらかい斜めの谷
					var r := absf(sin((float(x) + float(y) * 0.6) * 0.17 + v * 6.0))
					g = 0.84 + 0.1 * r + 0.06 * v
				"scratch":
					g = 0.9 + 0.08 * v - (0.1 if rng.randf() < 0.012 else 0.0)
				_:
					# 汚れ：ぼんやりした濃淡と、点々としたよごれ
					g = 0.82 + 0.15 * v - (0.12 if rng.randf() < 0.01 else 0.0)
			img.set_pixel(x, y, Color(g, g, g * 0.985))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_detail_tex[kind] = t
	return t


## 画像を貼るマテリアル。照明の陰影は通常どおり受けるが、画像側に陰影は焼き込まない。
static func texture_mat(key: String, tex: Texture2D, roughness: float) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[key] = m
	return m


## 繰り返し模様（布地など）を、面ごとの UV に関係なく一定の細かさで貼る（トリプラナー投影）。
## tile_m：画像1枚がゲーム内で何 m 四方になるか。
## 画像が正方形でないときは、縦の長さを画像の縦横比に合わせる（壁のような縦の面で、模様が伸びないように）。
static func tiled_mat(key: String, tex: Texture2D, tile_m: float, tint := Color.WHITE, roughness := 1.0) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = roughness
	m.uv1_triplanar = true
	var tile_h := tile_m * float(tex.get_height()) / float(tex.get_width())
	m.uv1_scale = Vector3(1.0 / tile_m, 1.0 / tile_h, 1.0 / tile_m)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[key] = m
	return m


## 隠し場所の小さな紙（仮の無地）。影の中でも紙だと分かるよう、ごく弱く自己発光させる。
static func note_mat() -> StandardMaterial3D:
	if _mat_cache.has("note_paper"):
		return _mat_cache["note_paper"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.93, 0.86)
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission = Color(0.95, 0.93, 0.86)
	m.emission_energy_multiplier = 0.3
	_mat_cache["note_paper"] = m
	return m


## 模様を弱めたテクスチャ（各画素を画像の平均色へ 1-strength だけ寄せる）。元の画像ファイルは変えない。
static func faded_texture(tex: Texture2D, strength: float) -> Texture2D:
	var key := "faded_%s_%.2f" % [tex.resource_path, strength]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img = img.duplicate()
	img.clear_mipmaps()
	var acc := Color(0, 0, 0)
	for y in img.get_height():
		for x in img.get_width():
			acc += img.get_pixel(x, y)
	var avg := acc / float(img.get_width() * img.get_height())
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, avg.lerp(img.get_pixel(x, y), strength))
	img.generate_mipmaps()
	var out := ImageTexture.create_from_image(img)
	_mat_cache[key] = out
	return out


## ステッカー（assets/textures/stickers/sticker_NN.png）を、面の法線 normal の向きに、面から 1.5mm 浮かせて貼る。
## h：高さ（m、幅は画像の比率から）、roll：面の中での傾き（度）。透過部分は alpha scissor で抜く。見た目だけ。
## assets/textures/props/ の絵（ユーザー作成・生成 AI 使用。透過 PNG）。
static func prop_tex(n: String) -> Texture2D:
	return load("res://assets/textures/props/%s.png" % n)


## 絵を貼った板（面の向き normal、大きさ size）。透過は切り抜き。double で裏からも見える。
static func image_quad(parent: Node3D, tex: Texture2D, size: Vector2, pos: Vector3, normal: Vector3, node_name := "Image", double := false, rough := 0.8) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = rough
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if double:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nn := normal.normalized()
	var up := Vector3.UP if absf(nn.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	mi.basis = Basis.looking_at(-nn, up)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sticker(parent: Node3D, n: int, h: float, pos: Vector3, normal: Vector3, roll := 0.0) -> MeshInstance3D:
	var tex: Texture2D = load("res://assets/textures/stickers/sticker_%02d.png" % n)
	var key := "sticker_%02d" % n
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.roughness = 0.8
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mat_cache[key] = m
	var q := QuadMesh.new()
	q.size = Vector2(h * tex.get_width() / tex.get_height(), h)
	var mi := MeshInstance3D.new()
	mi.name = "Sticker%02d" % n
	mi.mesh = q
	mi.material_override = _mat_cache[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nn := normal.normalized()
	var up := Vector3.UP if absf(nn.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	mi.basis = Basis.looking_at(-nn, up) * Basis(Vector3.BACK, deg_to_rad(roll))
	mi.position = pos + nn * 0.0015
	parent.add_child(mi)
	return mi


## スリッパ1足（左右2つ）。pos は足の中心（床の上）、yaw は つま先の向き（度。0 で +z、90 で +x）。
## 底（sole_col）と甲の覆い（col）の2色。0.255m の足型で、左右の間隔 0.11m。見た目だけ（当たり判定なし）。
static func slipper_pair(parent: Node3D, pos: Vector3, yaw: float, col: Color, sole_col: Color, node_name := "Slippers") -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation.y = deg_to_rad(yaw)
	parent.add_child(root)
	var sole_m := mat("slipper_sole_%s" % sole_col.to_html(false), sole_col, 0.9)
	var top_m := mat("slipper_top_%s" % col.to_html(false), col, 0.95)
	for side in [-1.0, 1.0]:
		var foot := Node3D.new()
		foot.name = "Left" if side < 0.0 else "Right"
		foot.position = Vector3(side * 0.055, 0.0, 0.0)
		foot.rotation.y = deg_to_rad(side * 3.5)
		root.add_child(foot)
		var sole := box(foot, Vector3(0.095, 0.014, 0.255), Vector3(0, 0.007, 0), sole_m, "Sole")
		sole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box(foot, Vector3(0.092, 0.03, 0.125), Vector3(0, 0.029, 0.062), top_m, "Cover")
		box(foot, Vector3(0.088, 0.018, 0.05), Vector3(0, 0.022, -0.1), top_m, "Heel")
	return root


## 水面用の半透明マテリアル（共有）。
static func water_surface_mat() -> StandardMaterial3D:
	if _mat_cache.has("water_surface"):
		return _mat_cache["water_surface"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.8, 0.9, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	_mat_cache["water_surface"] = m
	return m


## 水流用の半透明マテリアル。流れて見えるよう uv1_offset を動かすので、蛇口ごとに別のインスタンスを返す。
static func new_stream_mat() -> StandardMaterial3D:
	if _water_noise == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.08
		_water_noise = NoiseTexture2D.new()
		_water_noise.width = 32
		_water_noise.height = 64
		_water_noise.seamless = true
		_water_noise.noise = noise
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.94, 1.0, 0.6)
	m.albedo_texture = _water_noise
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.uv1_scale = Vector3(1.0, 3.0, 1.0)
	return m


static func _instance(parent: Node, mesh: Mesh, center: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not node_name.is_empty():
		mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = center
	parent.add_child(mi)
	return mi
