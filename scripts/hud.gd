extends CanvasLayer
## 画面表示：照準・案内・メッセージ・所持品・一時停止メニュー・クリア画面。

signal resume_pressed
signal quit_pressed
signal retry_pressed

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
var _inventory_label: Label
var _hint_label: Label
var _pause_menu: Control
var _clear_menu: Control
var _resume_button: Button
var _retry_button: Button
var _message_time_left := 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)

	# 配置（1280x720 基準、上から）：
	#   所持品 … 左上
	#   照準   … 画面中央
	#   操作   … 照準の 28px 下（中央）
	#   説明文 … 下端から 52px 上を底辺として上に伸びる（最大2〜3行）
	#   操作案内 … 最下段（下端から 12〜40px）
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
	_place(_message_panel, 0.08, 1.0, 0.92, 1.0, 0.0, -52.0, 0.0, -52.0)
	_message_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_message_panel.visible = false

	_inventory_label = _make_label(20, HORIZONTAL_ALIGNMENT_LEFT)
	_inventory_label.name = "InventoryLabel"
	var inventory_panel := _make_panel("Inventory", _inventory_label, 0.55)
	_place(inventory_panel, 0.0, 0.0, 0.0, 0.0, 20.0, 18.0, 20.0, 18.0)
	set_inventory("")

	_hint_label = _make_label(17, HORIZONTAL_ALIGNMENT_LEFT)
	_hint_label.name = "Hint"
	_hint_label.text = "WASD：移動　マウス：見回す　左クリック：調べる　Esc：一時停止"
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	_place(_hint_label, 0.0, 1.0, 1.0, 1.0, 24.0, -40.0, 0.0, -12.0)

	_pause_menu = _make_menu("PauseMenu", "一時停止")
	_resume_button = _add_button(_pause_menu, "再開", func() -> void: resume_pressed.emit())
	_add_button(_pause_menu, "終了", func() -> void: quit_pressed.emit())
	_pause_menu.visible = false

	_clear_menu = _make_menu("ClearMenu", "脱出成功")
	_retry_button = _add_button(_clear_menu, "もう一度", func() -> void: retry_pressed.emit())
	_add_button(_clear_menu, "終了", func() -> void: quit_pressed.emit())
	_clear_menu.visible = false


func _process(delta: float) -> void:
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


func set_inventory(item_name: String) -> void:
	if item_name.is_empty():
		_inventory_label.text = "所持品：なし"
	else:
		_inventory_label.text = "所持品：" + item_name


func show_pause(is_paused: bool) -> void:
	_pause_menu.visible = is_paused
	if is_paused:
		_resume_button.grab_focus()


func show_clear() -> void:
	set_prompt("")
	_message_panel.visible = false
	_message_time_left = 0.0
	_hint_label.visible = false
	_clear_menu.visible = true
	_retry_button.grab_focus()


# ---------------------------------------------------------------- 構築ヘルパー

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


func _add_button(menu: Control, text: String, callback: Callable) -> Button:
	var box := menu.get_node("Center/Box") as VBoxContainer
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 56)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(callback)
	box.add_child(button)
	return button
