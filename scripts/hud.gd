extends CanvasLayer
## 画面表示：照準・案内・メッセージ・所持品欄・持ち物の拡大表示・一時停止メニュー・クリア画面。

signal resume_pressed
signal quit_pressed
signal retry_pressed
signal eye_height_changed(value: float)
signal audio_changed(key: String, value: Variant)
signal head_bob_changed(on: bool)
signal body_visible_changed(on: bool)
signal sensitivity_changed(value: float)

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
var _carry_label: Label
var _bob_check: CheckButton
var _body_check: CheckButton
var _peep: Control
var _peep_tex: TextureRect
var _mj: Control
var _fade: ColorRect
var _stats_label: Label
var _quit_button: Button
var _quit_armed := false
var _intro: PanelContainer
var _intro_tween: Tween
var _dot: ColorRect
var _log: Control
var _log_label: Label
var _messages: Array[String] = []   # 最近のメッセージ（読み返せる）
var _sens_slider: HSlider
var _sens_value: Label
var _last_item_count := 0
var _pulse_tween: Tween
var _card_pop: TextureRect
var _card_tween: Tween
var _fade_tween: Tween
var _mj_tiles: Array = []   # [PanelContainer, TextureRect]
var _mj_info: Label
var _mj_river: Label
var _mj_status: Label
var _mj_help: Label
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

	_carry_label = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_carry_label.name = "CarryLabel"
	_carry_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_carry_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_carry_label.add_theme_constant_override("shadow_offset_x", 1)
	_carry_label.add_theme_constant_override("shadow_offset_y", 1)
	_place(_carry_label, 0.0, 1.0, 1.0, 1.0, 20.0, -140.0, -20.0, -112.0)   # 下端の説明文の少し上
	_carry_label.visible = false
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

	_build_peephole()
	_card_pop = TextureRect.new()
	_card_pop.name = "CardPop"
	_card_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_pop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_pop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_pop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_place(_card_pop, 0.5, 0.5, 0.5, 0.5, 90.0, -150.0, 270.0, 120.0)
	_card_pop.visible = false
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 0.0
	_build_mahjong()
	_log = PanelContainer.new()
	_log.name = "MessageLog"
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lstyle := StyleBoxFlat.new()
	lstyle.bg_color = Color(0.03, 0.04, 0.06, 0.88)
	lstyle.set_corner_radius_all(10)
	lstyle.content_margin_left = 22.0
	lstyle.content_margin_right = 22.0
	lstyle.content_margin_top = 14.0
	lstyle.content_margin_bottom = 14.0
	_log.add_theme_stylebox_override("panel", lstyle)
	_place(_log, 0.5, 0.0, 0.5, 1.0, -360.0, 60.0, 360.0, -100.0)
	var lbox := VBoxContainer.new()
	lbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_child(lbox)
	var ltitle := _make_label(18, HORIZONTAL_ALIGNMENT_LEFT)
	ltitle.text = "最近のメッセージ（新しい順）　H か Esc で閉じる"
	ltitle.modulate = Color(1, 1, 1, 0.7)
	lbox.add_child(ltitle)
	_log_label = _make_label(18, HORIZONTAL_ALIGNMENT_LEFT)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.clip_text = true
	lbox.add_child(_log_label)
	_log.visible = false
	_pause_menu = _make_menu("PauseMenu", "設定")
	_build_settings(_pause_menu)
	_stats_label = _make_label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_stats_label.name = "Stats"
	_stats_label.modulate = Color(1, 1, 1, 0.75)
	(_pause_menu.get_node("Center/Box") as VBoxContainer).add_child(_stats_label)
	_resume_button = _add_button(_pause_menu, "再開", func() -> void: resume_pressed.emit())
	_quit_button = _add_button(_pause_menu, "終了", _on_quit_clicked)
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
	if _messages.is_empty() or _messages[_messages.size() - 1] != text:
		_messages.append(text)
		if _messages.size() > 30:
			_messages.pop_front()
	_message_panel.visible = true
	_message_time_left = seconds


func set_prompt(text: String) -> void:
	if _prompt_label.text != text:
		_prompt_label.text = text
		_prompt_panel.visible = not text.is_empty()


## 所持品欄を更新する。names：持っている物の名前（最大6つ、順に 1〜6 キー）、selected：選択中の番号（なければ -1）。
func set_inventory(names: Array, selected: int) -> void:
	var new_count := names.size()
	if new_count > _last_item_count and selected >= 0 and selected < _slot_panels.size() and is_inside_tree():
		_pulse_slot(selected)   # 新しく持ち物に加わった欄を、ちょっと光らせる
	_last_item_count = new_count
	for i in _slot_labels.size():
		var has := i < names.size()
		_slot_labels[i].text = "%d  %s" % [i + 1, names[i] if has else "―"]
		_slot_labels[i].modulate = Color(1, 1, 1, 1.0 if has else 0.45)
		var style := _slot_panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		var on := has and i == selected
		style.bg_color = Color(0.0, 0.0, 0.0, 0.72 if on else 0.45)
		style.border_color = Color(1.0, 0.86, 0.55) if on else Color(1, 1, 1, 0.0)
		style.set_border_width_all(2 if on else 0)


func _pulse_slot(i: int) -> void:
	var p := _slot_panels[i]
	if _pulse_tween:
		_pulse_tween.kill()
		for q in _slot_panels:
			q.scale = Vector2.ONE
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(1.18, 1.18)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(p, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 照準が調べられる物に乗っているとき、点を少し大きく温かい色にする。
func set_aim(on: bool) -> void:
	if _dot == null:
		return
	var target_color := Color(1.0, 0.86, 0.45, 1.0) if on else Color(1, 1, 1, 0.9)
	if _dot.color != target_color:
		_dot.color = target_color
		var h := 3.5 if on else 2.0
		_dot.offset_left = -h
		_dot.offset_top = -h
		_dot.offset_right = h
		_dot.offset_bottom = h


## メッセージの履歴（H）。
func toggle_log() -> void:
	_log.visible = not _log.visible
	if _log.visible:
		var lines := PackedStringArray()
		for i in range(_messages.size() - 1, -1, -1):
			lines.append("・" + _messages[i])
		_log_label.text = "\n\n".join(lines) if not lines.is_empty() else "（まだ何もない）"


func is_log_open() -> bool:
	return _log.visible


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
	for i in 8:
		var label := _make_label(15, HORIZONTAL_ALIGNMENT_LEFT)
		label.name = "Slot%dLabel" % (i + 1)
		var panel := _make_panel("Slot%d" % (i + 1), label, 0.45)
		panel.custom_minimum_size = Vector2(84, 46)
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
	_dot = dot
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
	# 主人公の肖像（設定画面の左）：ユーザーのキャラクター画を切り抜いたもの
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = load("res://assets/textures/character/body_three_quarter.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(portrait)
	portrait.anchor_left = 0.0
	portrait.anchor_right = 0.0
	portrait.anchor_top = 0.5
	portrait.anchor_bottom = 0.5
	portrait.offset_left = 24.0
	portrait.offset_right = 250.0
	portrait.offset_top = -250.0
	portrait.offset_bottom = 250.0
	var box := menu.get_node("Center/Box") as VBoxContainer
	var help := _make_label(20, HORIZONTAL_ALIGNMENT_LEFT)
	help.name = "Controls"
	help.text = "操作説明\n移動：W A S D（矢印キーも可）　　視点：マウス\n調べる・使う：左クリック　　座る・入る・立つ：E\nしゃがむ：C　　持ち物を使う：F　　選ぶ：1〜8・ホイール　　拡大：Q　　メッセージの履歴：H\n釣り：釣り竿を拾い、ベランダの手すりを狙ってクリック。浮きが跳ねたらもう一度\nテレビゲーム中：W／A／S／D で操作、E でやめる\n設定を開く・閉じる：Esc"
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
	_bob_check = CheckButton.new()
	_bob_check.name = "BobToggle"
	_bob_check.text = "視点のゆれ（歩くとき・呼吸）オン"
	_bob_check.button_pressed = true
	_bob_check.add_theme_font_size_override("font_size", 20)
	_bob_check.toggled.connect(func(on: bool) -> void:
		_bob_check.text = "視点のゆれ（歩くとき・呼吸）%s" % ("オン" if on else "オフ")
		head_bob_changed.emit(on))
	box.add_child(_bob_check)
	var srow := HBoxContainer.new()
	srow.name = "SensitivityRow"
	box.add_child(srow)
	var slabel := _make_label(20, HORIZONTAL_ALIGNMENT_LEFT)
	slabel.text = "視点の感度"
	srow.add_child(slabel)
	_sens_slider = HSlider.new()
	_sens_slider.name = "Slider_sensitivity"
	_sens_slider.min_value = 40.0
	_sens_slider.max_value = 250.0
	_sens_slider.step = 5.0
	_sens_slider.value = 100.0
	_sens_slider.custom_minimum_size = Vector2(240, 28)
	_sens_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(_sens_slider)
	_sens_value = _make_label(20, HORIZONTAL_ALIGNMENT_LEFT)
	_sens_value.text = "100 %"
	srow.add_child(_sens_value)
	_sens_slider.value_changed.connect(func(v: float) -> void:
		_sens_value.text = "%d %%" % int(v)
		sensitivity_changed.emit(v / 100.0))
	_body_check = CheckButton.new()
	_body_check.name = "BodyToggle"
	_body_check.text = "自分の体（雑な3D）オフ"
	_body_check.add_theme_font_size_override("font_size", 20)
	_body_check.toggled.connect(func(on: bool) -> void:
		_body_check.text = "自分の体（雑な3D）%s" % ("オン" if on else "オフ")
		body_visible_changed.emit(on))
	box.add_child(_body_check)


func set_sensitivity_ui(mult: float) -> void:
	_sens_slider.set_value_no_signal(mult * 100.0)
	_sens_value.text = "%d %%" % int(mult * 100.0)


func set_body_ui(on: bool) -> void:
	_body_check.set_pressed_no_signal(on)
	_body_check.text = "自分の体（雑な3D）%s" % ("オン" if on else "オフ")


func set_head_bob_ui(on: bool) -> void:
	_bob_check.set_pressed_no_signal(on)
	_bob_check.text = "視点のゆれ（歩くとき・呼吸）%s" % ("オン" if on else "オフ")


## のぞき穴の画面：暗い背景の中央に、丸くぼんやりした景色（tex は丸く切り抜いた絵）。
func show_peephole(tex: Texture2D) -> void:
	_peep_tex.texture = tex
	_peep.visible = true


func hide_peephole() -> void:
	_peep.visible = false


func is_peephole_open() -> bool:
	return _peep.visible


func _build_peephole() -> void:
	_peep = ColorRect.new()
	(_peep as ColorRect).color = Color(0.0, 0.0, 0.0, 0.92)
	_peep.name = "Peephole"
	_peep.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_peep)
	_peep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peep.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	_peep_tex = TextureRect.new()
	_peep_tex.custom_minimum_size = Vector2(520, 520)
	_peep_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_peep_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_peep_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	box.add_child(_peep_tex)
	var cap := _make_label(18, HORIZONTAL_ALIGNMENT_CENTER)
	cap.text = "のぞき穴　（クリックか Esc でやめる）"
	box.add_child(cap)
	_peep.visible = false


## 運んでいる食べ物の表示（空なら隠す）。
func set_carry(text: String) -> void:
	_carry_label.text = text
	_carry_label.visible = not text.is_empty()


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


## 「終了」は 2 回押さないと終わらない（押し間違いで、遊んだ分が消えないように）。3 秒たつと元に戻る。
func _on_quit_clicked() -> void:
	if _quit_armed:
		quit_pressed.emit()
		return
	_quit_armed = true
	_quit_button.text = "もう一度押すと終了"
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void:
		_quit_armed = false
		if is_instance_valid(_quit_button):
			_quit_button.text = "終了")


## 設定画面の下に出す、遊んだ記録（プレイ時間・調べた物の数）。
func set_stats(text: String) -> void:
	_stats_label.text = text


## はじめて遊ぶときだけ出す、最小限の操作のヒント（数秒で薄れて消える）。
func show_intro(text: String, seconds := 9.0) -> void:
	if _intro == null:
		var lab := _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
		lab.name = "IntroText"
		_intro = _make_panel("Intro", lab, 0.6)
		_place(_intro, 0.5, 0.0, 0.5, 0.0, -330.0, 70.0, 330.0, 150.0)
	((_intro.get_child(0)) as Label).text = text
	_intro.visible = true
	_intro.modulate.a = 1.0
	if _intro_tween:
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_interval(seconds)
	_intro_tween.tween_property(_intro, "modulate:a", 0.0, 1.2)
	_intro_tween.tween_callback(func() -> void: _intro.visible = false)


func _add_button(menu: Control, text: String, callback: Callable) -> Button:
	var box := menu.get_node("Center/Box") as VBoxContainer
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 48)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(callback)
	box.add_child(button)
	return button


# ---------------------------------------------------------------- 一人麻雀

func _build_mahjong() -> void:
	_mj = PanelContainer.new()
	_mj.name = "Mahjong"
	_mj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.22, 0.14, 0.88)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_mj.add_theme_stylebox_override("panel", style)
	_place(_mj, 0.5, 0.0, 0.5, 0.0, -420.0, 56.0, 420.0, 290.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mj.add_child(box)
	_mj_info = _make_label(16, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_mj_info)
	_mj_river = _make_label(14, HORIZONTAL_ALIGNMENT_LEFT)
	_mj_river.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_mj_river.custom_minimum_size = Vector2(800, 40)
	box.add_child(_mj_river)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	for i in 14:
		if i == 13:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(14, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
		var tp := PanelContainer.new()
		tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tp.custom_minimum_size = Vector2(50, 70)
		var timg := TextureRect.new()   # 牌の絵（ユーザー作成。assets/textures/props/mj_*.png）
		timg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		timg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		timg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		timg.custom_minimum_size = Vector2(44, 64)
		tp.add_child(timg)
		row.add_child(tp)
		_mj_tiles.append([tp, timg])
	_mj_status = _make_label(17, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_mj_status)
	_mj_help = _make_label(13, HORIZONTAL_ALIGNMENT_CENTER)
	_mj_help.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_mj_help)
	_mj.visible = false


func is_mahjong_open() -> bool:
	return _mj.visible


func hide_mahjong() -> void:
	_mj.visible = false


## 麻雀の画面を更新して出す。cursor は 0〜13（13 が引いた牌）。
func show_mahjong(g: RefCounted, cursor: int, help: String) -> void:
	_mj.visible = true
	_mj_info.text = "一人麻雀　第%d局　山 残り%d　累計 %d点　和了 %d回" % [g.games, g.MAX_DRAWS - g.draws, g.total_points, g.wins]
	var river := "河："
	for t in g.discards:
		river += g.tile_name(t) + " "
	_mj_river.text = river
	var all: Array = g.hand + ([g.drawn] if g.drawn >= 0 else [])
	for i in 14:
		var e: Array = _mj_tiles[i]
		var tp: PanelContainer = e[0]
		tp.visible = i < all.size()
		if i >= all.size():
			continue
		(e[1] as TextureRect).texture = load("res://assets/textures/props/mj_%d.png" % all[i])
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.06, 0.25, 0.16, 0.0) if i != cursor else Color(1.0, 0.85, 0.35)
		st.set_corner_radius_all(4)
		st.border_color = Color(1, 0.4, 0.1)
		st.set_border_width_all(3 if i == cursor else 0)
		tp.add_theme_stylebox_override("panel", st)
		tp.custom_minimum_size.y = 70 if i != cursor else 80
	match g.state:
		"playing":
			var w: Array = []
			if g.drawn >= 0:
				# 引いた牌を含む14枚のとき、どれを切ると何待ちか
				var idx := cursor
				var t14: Array = g.hand + [g.drawn]
				var rest := t14.duplicate()
				rest.remove_at(idx)
				var probe: RefCounted = g.get_script().new(1)
				probe.hand = rest
				w = probe.waits()
			var wt := "待ち：" + ("　".join(w.map(func(k): return g.tile_name(k))) if w.size() > 0 else "なし")
			_mj_status.text = "選んだ牌を切ると　" + wt
		"won":
			_mj_status.text = "ツモ！　%s　%d点（簡易採点：符・翻の計算なし）" % ["・".join(g.yaku), g.points]
		"exhausted":
			_mj_status.text = "流局。山がなくなった。"
	_mj_help.text = help


## 画面を暗くする／戻す（階段の昇り降りなど）。alpha 1 で真っ暗。
func fade_to(alpha: float, seconds: float) -> Tween:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_fade, "modulate:a", alpha, seconds)
	return _fade_tween


func fade_alpha() -> float:
	return _fade.modulate.a


## 引いたトランプの絵を、照準の横にしばらく見せる。
func show_card(tex: Texture2D, seconds := 2.4) -> void:
	if tex == null:
		return
	_card_pop.texture = tex
	_card_pop.visible = true
	_card_pop.modulate.a = 1.0
	if _card_tween:
		_card_tween.kill()
	_card_tween = create_tween()
	_card_tween.tween_interval(seconds)
	_card_tween.tween_property(_card_pop, "modulate:a", 0.0, 0.4)
	_card_tween.tween_callback(func() -> void: _card_pop.visible = false)
