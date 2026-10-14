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
signal typing_changed(on: bool)
signal hints_changed(on: bool)
signal hint_requested
signal restart_pressed

const SfxScript := preload("res://scripts/sfx.gd")

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
var _clear_stats: Label
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
var _settings_scroll: ScrollContainer
var _disc_panel: PanelContainer
var _disc_tween: Tween
var _hints_check: CheckButton
var _hint_ask: Button
var _hint_note: Label
var _clear_rank: Label
var _restart_button: Button
var _restart_armed := false
var typing_on := true               # 文字を 1 文字ずつ出す（設定で切れる）
var _type_pos := 0.0                # いま見せている文字数（小数）
var _type_total := 0
var _typing_check: CheckButton
const TYPE_SPEED := 38.0            # 1 秒に出す文字数
const VOICE_COLOR := Color(0.8, 0.78, 1.0)   # 神の声の色（うすい紫）
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
	_build_notebook()
	_pause_menu = _make_menu("PauseMenu", "設定")
	_build_settings(_pause_menu)
	_stats_label = _make_label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_stats_label.name = "Stats"
	_stats_label.modulate = Color(1, 1, 1, 0.75)
	(_pause_menu.get_node("Center/Box") as VBoxContainer).add_child(_stats_label)
	_resume_button = _add_button(_pause_menu, "再開", func() -> void: resume_pressed.emit())
	_restart_button = _add_button(_pause_menu, "はじめから", _on_restart_clicked)
	_quit_button = _add_button(_pause_menu, "終了", _on_quit_clicked)
	_pause_menu.visible = false

	_clear_menu = _make_menu("ClearMenu", "脱出成功")
	_clear_rank = _make_label(84, HORIZONTAL_ALIGNMENT_CENTER)
	_clear_rank.name = "ClearRank"
	_clear_rank.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_clear_rank.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.02, 0.9))
	_clear_rank.add_theme_constant_override("outline_size", 10)
	(_clear_menu.get_node("Center/Box") as VBoxContainer).add_child(_clear_rank)
	_clear_stats = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_clear_stats.name = "ClearStats"
	_clear_stats.modulate = Color(1.0, 0.95, 0.8)
	(_clear_menu.get_node("Center/Box") as VBoxContainer).add_child(_clear_stats)
	_retry_button = _add_button(_clear_menu, "もう一度", func() -> void: retry_pressed.emit())
	_add_button(_clear_menu, "終了", func() -> void: quit_pressed.emit())
	_clear_menu.visible = false


func _process(delta: float) -> void:
	if _zoom.visible:
		_zoom_pivot.rotation.y += delta * 0.8
	if _type_pos < _type_total:
		_type_pos = minf(_type_pos + delta * TYPE_SPEED, float(_type_total))
		_message_label.visible_characters = int(_type_pos)
	if _message_time_left > 0.0 and _type_pos >= _type_total:   # 読む時間は、出そろってから数える
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			_message_panel.visible = false


# ---------------------------------------------------------------- 公開API

## メッセージを表示する。新しいメッセージは前のものを置き換える（重ならない）。
## kind="voice" は、神の声（うすい紫の字、かぎ括弧つき。独り言のヒントなど）。
func show_message(text: String, seconds: float = -1.0, kind := "") -> void:
	if seconds <= 0.0:
		# 日本語を読める時間：最低2.5秒、1文字あたり約0.12秒
		seconds = maxf(2.5, 1.0 + text.length() * 0.12)
	var shown := text
	if kind == "voice":
		shown = "『%s』" % text
		seconds += 1.5
		SfxScript.play("voice", 1.0, -2.0)   # 神の声の音（ラジオの謎の声とは別に作った、やわらかい声のような響き）
	_message_label.text = shown
	_message_label.add_theme_color_override("font_color", VOICE_COLOR if kind == "voice" else Color(1, 1, 1))
	_message_label.visible_characters = 0 if typing_on else -1
	_type_total = shown.length() if typing_on else 0
	_type_pos = 0.0
	if _messages.is_empty() or _messages[_messages.size() - 1] != shown:
		_messages.append(shown)
		if _messages.size() > 30:
			_messages.pop_front()
	_message_panel.visible = true
	_message_time_left = seconds


## 文字送りの途中なら、全部を一気に見せる（読み飛ばし用）。
func finish_typing() -> void:
	_type_pos = float(_type_total)
	_message_label.visible_characters = -1


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


# ---------------------------------------------------------------- 推理ノート

var _notebook: PanelContainer
var _notebook_chapters: Label
var _notebook_body: Label


func _build_notebook() -> void:
	_notebook = PanelContainer.new()
	_notebook.name = "Notebook"
	_notebook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.08, 0.05, 0.92)
	st.border_color = Color(0.85, 0.7, 0.4, 0.8)
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.content_margin_left = 26.0
	st.content_margin_right = 26.0
	st.content_margin_top = 16.0
	st.content_margin_bottom = 16.0
	_notebook.add_theme_stylebox_override("panel", st)
	_place(_notebook, 0.5, 0.0, 0.5, 1.0, -420.0, 56.0, 420.0, -160.0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notebook.add_child(box)
	var title := _make_label(24, HORIZONTAL_ALIGNMENT_LEFT)
	title.text = "推理ノート　　N か Esc で閉じる"
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	box.add_child(title)
	_notebook_chapters = _make_label(18, HORIZONTAL_ALIGNMENT_LEFT)
	_notebook_chapters.name = "Chapters"
	_notebook_chapters.modulate = Color(1, 1, 1, 0.8)
	box.add_child(_notebook_chapters)
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sep)
	_notebook_body = _make_label(19, HORIZONTAL_ALIGNMENT_LEFT)
	_notebook_body.name = "Body"
	_notebook_body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_notebook_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_notebook_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notebook_body.clip_text = true
	box.add_child(_notebook_body)
	_notebook.visible = false


func toggle_notebook(chapters: String, body: String) -> void:
	_notebook.visible = not _notebook.visible
	if _notebook.visible:
		_notebook_chapters.text = chapters
		_notebook_body.text = body


func close_notebook() -> void:
	_notebook.visible = false


func is_notebook_open() -> bool:
	return _notebook != null and _notebook.visible


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


## 設定の項目の箱の高さを、画面の高さに合わせる（見出し・ボタン 3 つ・記録の行ぶんを空ける）。
func _fit_settings() -> void:
	if _settings_scroll == null:
		return
	var h := get_viewport().get_visible_rect().size.y
	_settings_scroll.custom_minimum_size = Vector2(900.0, clampf(h - 400.0, 150.0, 560.0))


## タイトル画面の間：照準・操作案内・所持品欄を隠し、設定画面は「もどる」だけにする（再開・はじめから・終了・記録は出さない）。
var _title_hidden := {}


func set_title_mode(on: bool) -> void:
	var nodes: Array = [_dot, _hint_label, _inventory_bar, _prompt_panel, _message_panel, _root.get_node_or_null("CrosshairOutline")]
	for n in nodes:
		if n == null:
			continue
		if on:
			_title_hidden[n] = n.visible
			n.visible = false
		elif _title_hidden.has(n):
			n.visible = _title_hidden[n]
	if not on:
		_title_hidden.clear()
	_resume_button.text = "もどる" if on else "再開"
	_restart_button.visible = not on
	_quit_button.visible = not on
	_stats_label.visible = not on


## 設定を開いている間は、セリフ・操作の案内・発見の知らせ・持ち物欄など、ほかの表示をすべて隠す（設定の文字と重ならないように）。閉じると戻す。
var _overlay_state := {}


func _set_overlays_hidden(on: bool) -> void:
	var nodes: Array = [_prompt_panel, _message_panel, _carry_label, _disc_panel, _intro, _hint_label, _inventory_bar]
	for n in nodes:
		if n == null:
			continue
		if on:
			_overlay_state[n] = n.visible
			n.visible = false
		elif _overlay_state.has(n):
			# 閉じている間に消えるはずだったもの（読み終えた文・消えた知らせ）は、戻さない
			var keep: bool = _overlay_state[n] and n.modulate.a > 0.01
			if n == _message_panel:
				keep = keep and _message_time_left > 0.0
			n.visible = keep
	if not on:
		_overlay_state.clear()


func show_pause(is_paused: bool) -> void:
	_fit_settings()
	if is_paused != _pause_menu.visible:
		_set_overlays_hidden(is_paused)
	_pause_menu.visible = is_paused
	if is_paused:
		_resume_button.grab_focus()


func show_clear(title: String = "脱出成功", stats := "", rank := "") -> void:
	_clear_rank.text = ("ランク　" + rank) if not rank.is_empty() else ""
	_clear_rank.visible = not rank.is_empty()
	(_clear_menu.get_node("Center/Box").get_child(0) as Label).text = title
	_clear_stats.text = stats
	_clear_stats.visible = not stats.is_empty()
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
	var outer := menu.get_node("Center/Box") as VBoxContainer
	# 設定の項目が増えても、ボタンが画面の外へ出ないよう、項目はスクロールできる箱に入れる（高さは画面に合わせる）
	_settings_scroll = ScrollContainer.new()
	_settings_scroll.name = "SettingsScroll"
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_settings_scroll)
	var box := VBoxContainer.new()
	box.name = "Items"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_scroll.add_child(box)
	get_viewport().size_changed.connect(_fit_settings)
	_fit_settings()
	var help := _make_label(20, HORIZONTAL_ALIGNMENT_LEFT)
	help.name = "Controls"
	help.text = "操作説明\n移動：W A S D（矢印キーも可）　　視点：マウス\n調べる・使う：左クリック　　座る・入る・立つ：E\nしゃがむ：C　　持ち物を使う：F　　選ぶ：1〜8・ホイール　　拡大：Q　　メッセージの履歴：H\n推理ノート（手がかり・パスワード・幕の目次）：N　　目の高さを変える：[ と ]\n釣り：釣り竿を拾い、ベランダの手すりを狙ってクリック。浮きが跳ねたらもう一度\nテレビゲーム中：W／A／S／D で操作、E でやめる\n設定を開く・閉じる：Esc"
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
	_hints_check = CheckButton.new()
	_hints_check.name = "HintsToggle"
	_hints_check.text = "神の声モード（ヒント）オン"
	_hints_check.button_pressed = true
	_hints_check.add_theme_font_size_override("font_size", 20)
	_hints_check.toggled.connect(func(on: bool) -> void:
		_hints_check.text = "神の声モード（ヒント）%s" % ("オン" if on else "オフ")
		hints_changed.emit(on))
	box.add_child(_hints_check)
	_hint_ask = Button.new()
	_hint_ask.name = "HintAskButton"
	_hint_ask.text = "神の声にきく"
	_hint_ask.add_theme_font_size_override("font_size", 20)
	_hint_ask.pressed.connect(func() -> void: hint_requested.emit())
	box.add_child(_hint_ask)
	_hint_note = _make_label(16, HORIZONTAL_ALIGNMENT_LEFT)
	_hint_note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(_hint_note)
	_typing_check = CheckButton.new()
	_typing_check.name = "TypingToggle"
	_typing_check.text = "文字を 1 文字ずつ表示（文字送り）オン"
	_typing_check.button_pressed = true
	_typing_check.add_theme_font_size_override("font_size", 20)
	_typing_check.toggled.connect(func(on: bool) -> void:
		_typing_check.text = "文字を 1 文字ずつ表示（文字送り）%s" % ("オン" if on else "オフ")
		typing_on = on
		typing_changed.emit(on))
	box.add_child(_typing_check)
	_body_check = CheckButton.new()
	_body_check.name = "BodyToggle"
	_body_check.text = "自分の体（雑な3D）オフ"
	_body_check.add_theme_font_size_override("font_size", 20)
	_body_check.toggled.connect(func(on: bool) -> void:
		_body_check.text = "自分の体（雑な3D）%s" % ("オン" if on else "オフ")
		body_visible_changed.emit(on))
	box.add_child(_body_check)


## 「神の声にきく」の表示：のこりの回数。神の声モードがオフか、回数がないと押せない。
func set_hint_ask_ui(left: int, enabled: bool, limit := 5) -> void:
	_hint_note.text = "※ きけるのは %d 回まで。ヒントを使うほど、クリアのランクが下がる（SSS はヒントなしのときだけ）。" % limit
	_hint_ask.text = "神の声にきく（のこり %d 回）" % left
	_hint_ask.disabled = not enabled or left <= 0


func set_hints_ui(on: bool) -> void:
	_hints_check.set_pressed_no_signal(on)
	_hints_check.text = "神の声モード（ヒント）%s" % ("オン" if on else "オフ")


func set_typing_ui(on: bool) -> void:
	typing_on = on
	_typing_check.set_pressed_no_signal(on)
	_typing_check.text = "文字を 1 文字ずつ表示（文字送り）%s" % ("オン" if on else "オフ")


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
## 見つけた物の知らせ：右上に小さく出て、すぐ消える（目的を押しつけない）。
func show_discovery(label: String, n: int, total: int) -> void:
	_flash_disc("発見　%s　%d / %d" % [label, n, total])


## ノートに書き足したときの、右上の小さな知らせ。
func show_note_toast(title: String) -> void:
	_flash_disc("ノートに追加　%s　（N で開く）" % title)


## 目の高さを変えたときの、右上の小さな知らせ。
func show_height_toast(cm: int) -> void:
	_flash_disc("目の高さ　%d cm" % cm)


func _flash_disc(text: String) -> void:
	if _disc_panel == null:
		var lab := _make_label(17, HORIZONTAL_ALIGNMENT_RIGHT)
		lab.name = "DiscoveryText"
		lab.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
		_disc_panel = _make_panel("Discovery", lab, 0.5)
		_place(_disc_panel, 1.0, 0.0, 1.0, 0.0, -330.0, 46.0, -16.0, 80.0)
		_disc_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	(_disc_panel.get_child(0) as Label).text = text
	_disc_panel.visible = true
	_disc_panel.modulate.a = 0.0
	if _disc_tween:
		_disc_tween.kill()
	_disc_tween = create_tween()
	_disc_tween.tween_property(_disc_panel, "modulate:a", 1.0, 0.25)
	_disc_tween.tween_interval(3.2)
	_disc_tween.tween_property(_disc_panel, "modulate:a", 0.0, 0.8)
	_disc_tween.tween_callback(func() -> void: _disc_panel.visible = false)


## 「はじめから」も 2 回押さないと始まらない（保存した記録を消すので）。
func _on_restart_clicked() -> void:
	if _restart_armed:
		restart_pressed.emit()
		return
	_restart_armed = true
	_restart_button.text = "記録を消して、はじめから？（もう一度）"
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void:
		_restart_armed = false
		if is_instance_valid(_restart_button):
			_restart_button.text = "はじめから")


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


## 暗幕をすぐ指定の濃さにする（アニメーションなし）。
func set_fade_now(alpha: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade.modulate.a = alpha


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
