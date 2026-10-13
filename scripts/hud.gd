extends CanvasLayer
## 画面表示：照準・案内・メッセージ・所持品欄・持ち物の拡大表示・一時停止メニュー・クリア画面。

signal resume_pressed
signal quit_pressed
signal retry_pressed
signal eye_height_changed(value: float)
signal audio_changed(key: String, value: Variant)

const JP_FONTS := [
	"Hiragino Sans", "Hiragino Kaku Gothic ProN", "Hiragino Kaku Gothic Pro",
	"Yu Gothic UI", "Yu Gothic", "Meiryo", "MS Gothic",
	"Noto Sans CJK JP", "Noto Sans JP", "sans-serif",
]

var _root: Control
var _prompt_panel: PanelContainer
var _message_panel: PanelContainer
var _prompt_label: Label
var _message_label: Label
var _inventory_bar: HBoxContainer
var _slot_labels: Array[Label] = []
var _slot_panels: Array[PanelContainer] = []
var _zoom: Control
var _zoom_viewport: SubViewport
var _zoom_pivot: Node3D
var _zoom_name: Label
var _zoom_desc: Label
var _reader: Control
var _reader_cover: TextureRect
var _reader_tint: ColorRect
var _reader_tint_label: Label
var _reader_title: Label
var _reader_body: Label
var _reader_foot: Label
var _hint_label: Label
var _pause_menu: Control
var _clear_menu: Control
var _resume_button: Button
var _retry_button: Button
var _message_time_left := 0.0
var _height_slider: HSlider
var _height_value: Label
var _catch_label: Label
var audio_controls := {}   # key → HSlider／CheckButton（設定画面の音の欄）


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)

	# 配置（1280x720 基準、上から）：
	#   照準   … 画面中央
	#   操作   … 照準の 28px 下（中央）
	#   説明文 … 下端から 92px 上を底辺として上に伸びる（最大2〜3行）
	#   所持品欄 … 右下（下端から 16〜68px、スロット3つ）
	#   操作案内 … 上端（上から 12〜38px）
	#   拡大表示 … 画面中央（Q で開閉）
	_build_crosshair()
	_prompt_label = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_label.name = "PromptLabel"
	_prompt_panel = _make_panel("Prompt", _prompt_label, 0.55)
	_place(_prompt_panel, 0.5, 0.5, 0.5, 0.5, 0.0, 28.0, 0.0, 28.0)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_END
	_prompt_panel.visible = false

	_message_label = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_message_label.name = "MessageLabel"
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_panel = _make_panel("Message", _message_label, 0.65)
	_place(_message_panel, 0.08, 1.0, 0.92, 1.0, 0.0, -92.0, 0.0, -92.0)
	_message_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_message_panel.visible = false

	_build_inventory_bar()
	_build_zoom()
	_build_reader()

	_hint_label = _make_label(17, HORIZONTAL_ALIGNMENT_LEFT)
	_hint_label.name = "Hint"
	_hint_label.text = "Esc：設定（操作説明・身長）"
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	_hint_label.add_theme_font_size_override("font_size", 15)
	_place(_hint_label, 0.0, 0.0, 1.0, 0.0, 20.0, 12.0, -20.0, 38.0)   # 上端（所持品欄と重ならないよう、下から移した）

	_pause_menu = _make_menu("PauseMenu", "設定")
	_build_settings(_pause_menu)
	_resume_button = _add_button(_pause_menu, "再開", func() -> void: resume_pressed.emit())
	_add_button(_pause_menu, "終了", func() -> void: quit_pressed.emit())
	_pause_menu.visible = false

	_clear_menu = _make_menu("ClearMenu", "脱出成功")
	_retry_button = _add_button(_clear_menu, "もう一度", func() -> void: retry_pressed.emit())
	_add_button(_clear_menu, "終了", func() -> void: quit_pressed.emit())
	_clear_menu.visible = false


func _process(delta: float) -> void:
	if _zoom.visible:
		_zoom_pivot.rotation.y += delta * 0.8
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			_message_panel.visible = false


# ---------------------------------------------------------------- 公開API

## メッセージを表示する。新しいメッセージは前のものを置き換える（重ならない）。
func show_message(text: String, seconds: float = -1.0) -> void:
	if seconds <= 0.0:
		# 日本語を読める時間：最低2.5秒、1文字あたり約0.12秒
		seconds = maxf(2.5, 1.0 + text.length() * 0.12)
	_message_label.text = text
	_message_panel.visible = true
	_message_time_left = seconds


func set_prompt(text: String) -> void:
	if _prompt_label.text != text:
		_prompt_label.text = text
		_prompt_panel.visible = not text.is_empty()


## 所持品欄を更新する。names：持っている物の名前（最大4つ、順に 1〜4 キー）、selected：選択中の番号（なければ -1）。
func set_inventory(names: Array, selected: int) -> void:
	for i in _slot_labels.size():
		var has := i < names.size()
		_slot_labels[i].text = "%d  %s" % [i + 1, names[i] if has else "―"]
		_slot_labels[i].modulate = Color(1, 1, 1, 1.0 if has else 0.45)
		var style := _slot_panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		var on := has and i == selected
		style.bg_color = Color(0.0, 0.0, 0.0, 0.72 if on else 0.45)
		style.border_color = Color(1.0, 0.86, 0.55) if on else Color(1, 1, 1, 0.0)
		style.set_border_width_all(2 if on else 0)


## 持ち物の拡大表示。model：表示する3Dモデル（複製して使う）。null なら閉じる。
func show_item_zoom(model: Node3D, item_name: String, desc: String) -> void:
	for c in _zoom_pivot.get_children():
		c.queue_free()
	if model == null:
		_zoom.visible = false
		return
	var m := model.duplicate()
	_zoom_pivot.add_child(m)
	m.position = Vector3.ZERO
	m.rotation = Vector3.ZERO
	_zoom_name.text = item_name
	_zoom_desc.text = desc
	_zoom.visible = true


func is_zoom_open() -> bool:
	return _zoom.visible


## 本を読む画面（本棚の本）。cover があれば表紙、なければ tint の色の無地の背表紙に題名。
## page は 0 始まり、pages は総ページ数。最後のページでは「閉じる」の案内にする。
func show_reader(title: String, body: String, cover: Texture2D, tint: Color, page: int, pages: int) -> void:
	_zoom.visible = false
	_message_panel.visible = false
	_reader_cover.texture = cover
	_reader_cover.visible = cover != null
	_reader_tint.visible = cover == null
	_reader_tint.color = tint
	_reader_tint_label.text = title
	_reader_title.text = title
	_reader_body.text = body
	var more := page < pages - 1
	_reader_foot.text = "%s左クリック：%s　／　Esc：閉じる" % ["%d / %d　　" % [page + 1, pages] if pages > 1 else "", "次のページ" if more else "閉じる"]
	_reader.visible = true


func hide_reader() -> void:
	_reader.visible = false


func is_reader_open() -> bool:
	return _reader.visible


func show_pause(is_paused: bool) -> void:
	_pause_menu.visible = is_paused
	if is_paused:
		_message_panel.visible = false   # 設定の下に文章が透けて重ならないように
	if is_paused:
		_resume_button.grab_focus()


func show_clear(title: String = "脱出成功") -> void:
	(_clear_menu.get_node("Center/Box").get_child(0) as Label).text = title
	set_prompt("")
	_message_panel.visible = false
	_message_time_left = 0.0
	_hint_label.visible = false
	_zoom.visible = false
	_clear_menu.visible = true
	_retry_button.grab_focus()


# ---------------------------------------------------------------- 構築ヘルパー

func _build_inventory_bar() -> void:
	_inventory_bar = HBoxContainer.new()
	_inventory_bar.name = "Inventory"
	_inventory_bar.add_theme_constant_override("separation", 8)
	_inventory_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_inventory_bar, 1.0, 1.0, 1.0, 1.0, -20.0, -16.0, -20.0, -16.0)
	_inventory_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_inventory_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var title := _make_label(15, HORIZONTAL_ALIGNMENT_RIGHT)
	title.text = "所持品"
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	_inventory_bar.add_child(title)
	for i in 4:
		var label := _make_label(17, HORIZONTAL_ALIGNMENT_LEFT)
		label.name = "Slot%dLabel" % (i + 1)
		var panel := _make_panel("Slot%d" % (i + 1), label, 0.45)
		panel.custom_minimum_size = Vector2(104, 46)
		var style := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		panel.add_theme_stylebox_override("panel", style)
		_inventory_bar.add_child(panel)
		_slot_labels.append(label)
		_slot_panels.append(panel)
	set_inventory([], -1)


func _build_zoom() -> void:
	# 中央のパネルに、別の3D空間（SubViewport）で持ち物をゆっくり回して見せる
	var label_name := _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(420, 260)
	_zoom_viewport = SubViewport.new()
	_zoom_viewport.own_world_3d = true
	_zoom_viewport.transparent_bg = true
	container.add_child(_zoom_viewport)
	var cam := Camera3D.new()
	var cam_pos := Vector3(0, 0.06, 0.32)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.02, 0) - cam_pos), cam_pos)
	cam.fov = 40.0
	cam.near = 0.01
	_zoom_viewport.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(30.0), 0.0)
	light.light_color = Color(1.0, 0.92, 0.82)
	_zoom_viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.78, 0.74)
	env.environment.ambient_light_energy = 0.6
	_zoom_viewport.add_child(env)
	_zoom_pivot = Node3D.new()
	_zoom_pivot.name = "ZoomPivot"
	_zoom_viewport.add_child(_zoom_pivot)
	box.add_child(container)
	_zoom_name = label_name
	box.add_child(label_name)
	_zoom_desc = _make_label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_zoom_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zoom_desc.custom_minimum_size = Vector2(420, 0)
	box.add_child(_zoom_desc)
	var close_hint := _make_label(15, HORIZONTAL_ALIGNMENT_CENTER)
	close_hint.text = "Q：閉じる"
	close_hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(close_hint)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	var panel := PanelContainer.new()
	panel.name = "ItemZoom"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(box)
	_place(panel, 0.5, 0.5, 0.5, 0.5, 0.0, -40.0, 0.0, -40.0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_zoom = panel
	_zoom.visible = false


func _build_reader() -> void:
	var left := Control.new()
	left.custom_minimum_size = Vector2(210, 300)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reader_cover = TextureRect.new()
	_reader_cover.name = "Cover"
	_reader_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reader_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reader_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reader_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_reader_cover)
	_reader_tint = ColorRect.new()
	_reader_tint.name = "Spine"
	_reader_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reader_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_reader_tint)
	_reader_tint_label = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_reader_tint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reader_tint_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_reader_tint.add_child(_reader_tint_label)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	_reader_title = _make_label(26, HORIZONTAL_ALIGNMENT_LEFT)
	right.add_child(_reader_title)
	_reader_body = _make_label(22, HORIZONTAL_ALIGNMENT_LEFT)
	_reader_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_reader_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reader_body.custom_minimum_size = Vector2(400, 200)
	right.add_child(_reader_body)
	_reader_foot = _make_label(15, HORIZONTAL_ALIGNMENT_LEFT)
	_reader_foot.modulate = Color(1, 1, 1, 0.7)
	right.add_child(_reader_foot)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.add_child(left)
	box.add_child(right)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.88)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	var panel := PanelContainer.new()
	panel.name = "Reader"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(box)
	_place(panel, 0.5, 0.5, 0.5, 0.5, 0.0, -20.0, 0.0, -20.0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_reader = panel
	_reader.visible = false


func _make_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(JP_FONTS)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	return theme


func _build_crosshair() -> void:
	var outline := ColorRect.new()
	outline.name = "CrosshairOutline"
	outline.color = Color(0, 0, 0, 0.6)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(outline, 0.5, 0.5, 0.5, 0.5, -4.0, -4.0, 4.0, 4.0)
	var dot := ColorRect.new()
	dot.name = "Crosshair"
	dot.color = Color(1, 1, 1, 0.9)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(dot, 0.5, 0.5, 0.5, 0.5, -2.0, -2.0, 2.0, 2.0)


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	return label


## 半透明の暗い背景つきパネルに label を入れる（強い縁取りの代わり）。
func _make_panel(panel_name: String, label: Label, alpha: float) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, alpha)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label)
	return panel


## アンカーとオフセットを指定して _root に追加する。
func _place(c: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, orr: float, ob: float) -> void:
	_root.add_child(c)
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _make_menu(menu_name: String, title: String) -> Control:
	var overlay := ColorRect.new()
	overlay.name = menu_name
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title_label := _make_label(44, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.text = title
	box.add_child(title_label)
	return overlay


## 設定画面の中身：操作説明と、身長（立っているときの目の高さ）のスライダー。
func _build_settings(menu: Control) -> void:
	var box := menu.get_node("Center/Box") as VBoxContainer
	var help := _make_label(20, HORIZONTAL_ALIGNMENT_LEFT)
	help.name = "Controls"
	help.text = "操作説明\n移動：W A S D（矢印キーも可）　　視点：マウス\n調べる・使う：左クリック　　座る・入る・立つ：E\nしゃがむ：C　　持ち物を使う：F　　選ぶ：1〜4・ホイール　　拡大：Q\n釣り：釣り竿を拾い、ベランダの手すりを狙ってクリック。浮きが跳ねたらもう一度\nテレビゲーム中：W／S でラケット、E でやめる\n設定を開く・閉じる：Esc"
	box.add_child(help)
	_catch_label = _make_label(18, HORIZONTAL_ALIGNMENT_LEFT)
	_catch_label.name = "CatchLabel"
	_catch_label.text = "釣果：まだ何も釣っていない"
	_catch_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	box.add_child(_catch_label)
	box.add_theme_constant_override("separation", 8)
	var grid := GridContainer.new()
	grid.name = "AudioGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	box.add_child(grid)
	for def in [["master", "全体の音量", ""], ["sfx", "効果音", "sfx_on"], ["ambient", "環境音", "ambient_on"]]:
		var name_label := _make_label(20, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.text = def[1]
		grid.add_child(name_label)
		var sl := HSlider.new()
		sl.name = "Slider_" + def[0]
		sl.min_value = 0.0
		sl.max_value = 100.0
		sl.step = 1.0
		sl.value = 100.0
		sl.custom_minimum_size = Vector2(260, 28)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = def[0]
		sl.value_changed.connect(func(v: float) -> void: audio_changed.emit(key, v / 100.0))
		grid.add_child(sl)
		audio_controls[key] = sl
		if def[2] == "":
			grid.add_child(Control.new())
		else:
			var cb := CheckButton.new()
			cb.name = "Toggle_" + def[2]
			cb.text = "オン"
			cb.button_pressed = true
			cb.add_theme_font_size_override("font_size", 20)
			var tkey: String = def[2]
			cb.toggled.connect(func(on: bool) -> void:
				cb.text = "オン" if on else "オフ"
				audio_changed.emit(tkey, on))
			grid.add_child(cb)
			audio_controls[tkey] = cb
	var row := HBoxContainer.new()
	row.name = "HeightRow"
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var label := _make_label(20, HORIZONTAL_ALIGNMENT_LEFT)
	label.text = "身長（目の高さ）"
	row.add_child(label)
	_height_slider = HSlider.new()
	_height_slider.name = "HeightSlider"
	_height_slider.min_value = 130.0
	_height_slider.max_value = 170.0
	_height_slider.step = 1.0
	_height_slider.value = 150.0
	_height_slider.custom_minimum_size = Vector2(260, 32)
	_height_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_height_slider)
	_height_value = _make_label(20, HORIZONTAL_ALIGNMENT_LEFT)
	_height_value.text = "150 cm"
	row.add_child(_height_value)
	_height_slider.value_changed.connect(func(v: float) -> void:
		_height_value.text = "%d cm" % int(v)
		eye_height_changed.emit(v / 100.0))


## 設定画面の「釣果」の行。
func set_catch_text(text: String) -> void:
	_catch_label.text = text


## 設定画面の音の欄を、保存されていた値に合わせる（信号は出さない）。
func set_audio_ui(values: Dictionary) -> void:
	for key in values:
		var c: Control = audio_controls[key]
		if c is HSlider:
			(c as HSlider).set_value_no_signal(float(values[key]) * 100.0)
		else:
			(c as CheckButton).set_pressed_no_signal(bool(values[key]))
			(c as CheckButton).text = "オン" if bool(values[key]) else "オフ"


## 設定画面のスライダーを、保存されていた値に合わせる（信号は出さない）。
func set_eye_height_ui(meters: float) -> void:
	_height_slider.set_value_no_signal(meters * 100.0)
	_height_value.text = "%d cm" % int(round(meters * 100.0))


func _add_button(menu: Control, text: String, callback: Callable) -> Button:
	var box := menu.get_node("Center/Box") as VBoxContainer
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 48)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(callback)
	box.add_child(button)
	return button
