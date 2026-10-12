extends RefCounted
## 基本形状とマテリアルを作る共通ヘルパー（room.gd と各設備スクリプトで共用）。
## 物理レイヤーの値もここに置き、設備スクリプトから参照する。

const LAYER_WORLD := 1      # 壁・設備（プレイヤーがぶつかる）
const LAYER_INTERACT := 2   # 照準だけ当たる（ぶつからない）

static var _mat_cache := {}
static var _water_noise: NoiseTexture2D


static func box(parent: Node, size: Vector3, center: Vector3, material: Material, node_name := "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, center, material, node_name)


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
	_mat_cache[key] = m
	return m


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
static func tiled_mat(key: String, tex: Texture2D, tile_m: float, tint := Color.WHITE, roughness := 1.0) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = roughness
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[key] = m
	return m


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
