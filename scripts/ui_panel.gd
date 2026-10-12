extends RefCounted
## 3D の小さな操作パネル用：Godot の UI（Control）を SubViewport に描き、平面に貼る。
## 文字やボタンの絵は UI で作るので、生成画像は使わない。

const JP_FONTS := ["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Yu Gothic UI", "Meiryo", "Noto Sans CJK JP", "sans-serif"]


## SubViewport（size px）と、それを貼った平面（size_m、表は +z）を作る。戻り値 [viewport, root Control, quad]。
static func make(parent: Node3D, node_name: String, size_px: Vector2i, size_m: Vector2) -> Array:
	var vp := SubViewport.new()
	vp.name = node_name + "Viewport"
	vp.size = size_px
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	parent.add_child(vp)
	var root := Control.new()
	root.size = Vector2(size_px)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(JP_FONTS)
	var theme := Theme.new()
	theme.default_font = font
	root.theme = theme
	vp.add_child(root)
	var quad := QuadMesh.new()
	quad.size = size_m
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # 液晶・印刷面なので照明で暗くしすぎない
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mi.material_override = m
	parent.add_child(mi)
	return [vp, root, mi]


static func rect(parent: Control, pos: Vector2, size: Vector2, color: Color, radius := 6) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", st)
	parent.add_child(p)
	return p


static func set_rect_color(p: Panel, color: Color) -> void:
	(p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = color


static func label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
