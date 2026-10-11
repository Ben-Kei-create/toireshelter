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

	_build_crosshair()
	_prompt_label = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_label.name = "Prompt"
	_place(_prompt_label, 0.0, 0.5, 1.0, 0.5, 0.0, 22.0, 0.0, 60.0)

	_message_label = _make_label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_message_label.name = "Message"
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_message_label, 0.1, 1.0, 0.9, 1.0, 0.0, -190.0, 0.0, -110.0)
	_message_label.visible = false

	_inventory_label = _make_label(22, HORIZONTAL_ALIGNMENT_LEFT)
	_inventory_label.name = "Inventory"
	_place(_inventory_label, 0.0, 0.0, 0.5, 0.0, 24.0, 20.0, 0.0, 56.0)
	set_inventory("")

	_hint_label = _make_label(16, HORIZONTAL_ALIGNMENT_LEFT)
	_hint_label.name = "Hint"
	_hint_label.text = "WASD：移動　マウス：見回す　左クリック：調べる　Esc：一時停止"
	_hint_label.modulate = Color(1, 1, 1, 0.75)
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
			_message_label.visible = false


# ---------------------------------------------------------------- 公開API

## メッセージを表示する。新しいメッセージは前のものを置き換える（重ならない）。
func show_message(text: String, seconds: float = -1.0) -> void:
	if seconds <= 0.0:
		# 日本語を読める時間：最低2.5秒、1文字あたり約0.12秒
		seconds = maxf(2.5, 1.0 + text.length() * 0.12)
	_message_label.text = text
	_message_label.visible = true
	_message_time_left = seconds


func set_prompt(text: String) -> void:
	if _prompt_label.text != text:
		_prompt_label.text = text


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
	_message_label.visible = false
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
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	return label


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
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

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
