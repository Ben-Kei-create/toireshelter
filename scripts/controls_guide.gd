extends RefCounted
## 操作の案内：はじめから全部は見せない。その操作が初めて必要になったとき小さな案内を出し、実際にその操作をすると「覚えた」になる。
## 設定画面の操作説明には、覚えた操作だけが書かれ、まだの操作は「????」と出る。キーボードとコントローラの両方の呼び名を持つ。
## 覚えた操作は user://settings.cfg の [tutorial] に保存する。

const CONTROLS := [
	{"id": "move", "name": "移動", "key": "W A S D（矢印キー）", "pad": "左スティック", "actions": ["move_forward", "move_back", "move_left", "move_right"], "tip": "歩く：W A S D（コントローラ：左スティック）"},
	{"id": "look", "name": "視点", "key": "マウス", "pad": "右スティック", "actions": [], "tip": "見回す：マウス（コントローラ：右スティック）"},
	{"id": "interact", "name": "調べる・使う", "key": "左クリック", "pad": "Aボタン", "actions": ["interact"], "tip": "光る点が変わったら、調べられる：左クリック（A）"},
	{"id": "action", "name": "座る・入る・立つ", "key": "E", "pad": "Yボタン", "actions": ["action"], "tip": "画面の下に出た操作：E（Y）で、座る・入る・立つ"},
	{"id": "crouch", "name": "しゃがむ", "key": "C", "pad": "Bボタン", "actions": ["crouch"], "tip": "低い所は、しゃがんで見られる：C（B）"},
	{"id": "use_item", "name": "持ち物を使う", "key": "F", "pad": "Xボタン", "actions": ["use_item"], "tip": "持ち物を手に持って、狙った先に：F（X）"},
	{"id": "select", "name": "持ち物を選ぶ", "key": "1〜8・ホイール", "pad": "LB／RB", "actions": ["item_1", "item_2", "item_3", "item_4", "item_5", "item_6", "item_7", "item_8", "item_prev", "item_next"], "tip": "持ち物を選ぶ：1〜8かホイール（LB／RB）"},
	{"id": "inspect", "name": "拡大して見る", "key": "Q", "pad": "十字キー上", "actions": ["inspect_item"], "tip": "手に持った物を拡大して見る：Q（十字キー上）"},
	{"id": "drop", "name": "置く", "key": "G", "pad": "十字キー下", "actions": ["drop_item"], "tip": "手に持った物を置く：G（十字キー下）"},
	{"id": "log", "name": "メッセージの履歴", "key": "H", "pad": "十字キー左", "actions": ["message_log"], "tip": "読み逃したメッセージ：H（十字キー左）"},
	{"id": "notebook", "name": "推理ノート", "key": "N", "pad": "BACK／SELECT", "actions": ["notebook"], "tip": "手がかりはノートに残る：N（BACK）"},
	{"id": "eye", "name": "目の高さ", "key": "[ と ]", "pad": "スティック押し込み", "actions": ["eye_down", "eye_up"], "tip": "目の高さを変えられる：[ と ]（スティックを押し込む）"},
	{"id": "pause", "name": "設定", "key": "Esc", "pad": "START", "actions": ["pause"], "tip": "設定・保存：Esc（START）"},
]

var learned := {}        # id → true
var tip_shown := {}      # 案内を出した操作
var using_pad := false


func load_from(cfg: ConfigFile) -> void:
	for id in Array(cfg.get_value("tutorial", "learned", [])):
		learned[String(id)] = true
	for id in Array(cfg.get_value("tutorial", "tips", [])):
		tip_shown[String(id)] = true


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("tutorial", "learned", learned.keys())
	cfg.set_value("tutorial", "tips", tip_shown.keys())


func entry(id: String) -> Dictionary:
	for c in CONTROLS:
		if c.id == id:
			return c
	return {}


## 入力を見て、覚えた操作があれば id を返す（なければ ""）。
func learn_from(event: InputEvent) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadButton or absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false
	for c in CONTROLS:
		for a in c.actions:
			if InputMap.has_action(a) and event.is_action_pressed(a):
				return _learn(String(c.id))
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 3.0:
		return _learn("look")
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return _learn("select")
	return ""


func _learn(id: String) -> String:
	if learned.has(id):
		return ""
	learned[id] = true
	return id


## スティックで見回した（毎フレームの確認から）。
func learn_look_from_pad() -> String:
	return _learn("look")


func learn_move_from_axes() -> String:
	return _learn("move")


## 設定画面の操作説明：覚えた操作だけ書く。まだの操作は「????」。
func help_text() -> String:
	var lines := ["操作（やってみた操作から、増えていく）"]
	var unknown := 0
	for c in CONTROLS:
		if learned.has(c.id):
			lines.append("%s：%s／%s" % [c.name, _key_text(c), c.pad])
		else:
			unknown += 1
	if unknown > 0:
		lines.append("???? × %d（まだ、やっていない操作）" % unknown)
	return "\n".join(lines)


## 操作のキーの名前。キーを割り当て直していたら、いまのキー（一つの動作だけの操作のみ）。
func _key_text(c: Dictionary) -> String:
	var acts: Array = c.actions
	if acts.size() == 1 and c.id != "interact" and c.id != "pause" and InputMap.has_action(acts[0]):
		var names := []
		for ev in InputMap.action_get_events(acts[0]):
			if ev is InputEventKey:
				var k := ev as InputEventKey
				names.append(OS.get_keycode_string(k.physical_keycode if k.physical_keycode != 0 else k.keycode))
		if not names.is_empty():
			return " / ".join(names)
	return String(c.key)


## 案内を出すべきか（まだ覚えておらず、まだ案内していない）。
func should_tip(id: String) -> bool:
	return not learned.has(id) and not tip_shown.has(id)


func tip_text(id: String) -> String:
	var c := entry(id)
	if c.is_empty():
		return ""
	tip_shown[id] = true
	return String(c.tip)
