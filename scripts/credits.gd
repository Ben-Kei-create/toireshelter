extends Control
## エンドロール。黒い画面を、下から上へ文字がゆっくり流れる。流れ終わると finished を出す（そのあとクリア画面）。
## 行は [種類, 文字] の配列：title（大見出し）・head（見出し）・text（本文）・space（空き）。
## Enter・スペース・Esc・クリックで、2 秒たったあとなら飛ばせる。

signal finished

const SCROLL_SECONDS := 42.0
const SKIP_AFTER := 2.0

var _box: VBoxContainer
var _tween: Tween
var _t := 0.0
var _done := false


func _ready() -> void:
	name = "Credits"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_box = VBoxContainer.new()
	_box.name = "Lines"
	_box.add_theme_constant_override("separation", 14)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var hint := Label.new()
	hint.name = "SkipHint"
	hint.text = "Enter：飛ばす"
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.35)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.position = Vector2(-24, -20)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


## 行を並べて、流しはじめる。
func play(lines: Array) -> void:
	for l in lines:
		var kind: String = l[0]
		var label := Label.new()
		label.text = l[1]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match kind:
			"title":
				label.add_theme_font_size_override("font_size", 76)
				label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
			"head":
				label.add_theme_font_size_override("font_size", 30)
				label.add_theme_color_override("font_color", Color(0.78, 0.82, 1.0))
			"space":
				label.text = " "
				label.add_theme_font_size_override("font_size", 40)
			_:
				label.add_theme_font_size_override("font_size", 26)
				label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
		_box.add_child(label)
	await get_tree().process_frame
	await get_tree().process_frame
	var h := get_viewport_rect().size
	_box.size = Vector2(h.x, 0.0)
	_box.position = Vector2(0.0, h.y)
	var total := _box.get_combined_minimum_size().y
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_box, "position:y", -total - 40.0, SCROLL_SECONDS)
	_tween.tween_callback(_finish)


func _process(delta: float) -> void:
	_t += delta


func _input(event: InputEvent) -> void:
	if _done or _t < SKIP_AFTER:
		return
	var skip := false
	if event is InputEventKey and event.pressed and not event.echo:
		skip = event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]
	elif event is InputEventMouseButton and event.pressed:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_finish()


## 飛ばす（テストや「もう一度」からも使う）。
func skip() -> void:
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween:
		_tween.kill()
	finished.emit()
