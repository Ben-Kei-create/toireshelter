extends Node
## 進み具合のまわり：①やさしいヒント（神の声の独り言）②見つけた物の記録と、画面の端の小さな知らせ ③簡易セーブ。
## main.gd の子として置く（main が `main` を設定する）。毎フレームの処理は、止まっている時間の加算と、位置の比較だけ。
##
## ヒント：同じ場所で何もしない時間が IDLE_TIME を超えると、状況にあった独り言を 1 つ出す（強制ではない。出したヒントは二度と出さない。
##         つぎのヒントまで HINT_GAP 秒あける。設定で切れる）。
## 発見：DISCOVERIES の物を初めて見つけたとき、画面の右上に「発見　○○　3 / 22」と小さく出す。
## セーブ：user://save.json。持ち物・拾った物・床下の食べ物・階段・レコード・調べた物・発見・出したヒント・プレイ時間だけ。
##         一時停止・終了・発見・食べ物を入れたとき・持ち物が増えたときに書く。起動時に自動で続きから。ヘッドレス（テスト）と撮影では動かさない。

const SAVE_PATH := "user://save.json"
const VERSION := 1
const IDLE_TIME := 55.0
const HINT_GAP := 90.0

## 発見の名前（調べた id またはイベント名 → 表示名）
const DISCOVERIES := {
	"cellar": "床下の貯蔵庫", "stairs": "地下への階段", "basement_letter": "地下の手紙",
	"mahjong": "麻雀牌", "mahjong_play": "一人麻雀", "record_disc": "レコード盤", "record_set": "レコードの音",
	"fishing_rod": "釣り竿", "cork_gun": "コルク銃", "tank_coin": "UFOコイン", "peephole": "のぞき穴",
	"intercom": "インターホン", "kotatsu_in": "こたつの中", "bed_sleep": "ふとんで眠る", "radio": "ラジオ",
	"tv_play": "テレビゲーム", "aquarium": "水槽", "bath_powder": "入浴剤", "phone_black": "黒電話",
	"driver": "ドライバー", "microwave": "電子レンジ", "calendar": "カレンダー",
}

var main: Node
var enabled := true
var hints_on := true
var discovered := {}
var hints_shown := {}
var idle_t := 0.0
var since_hint := 0.0
var _last_pos := Vector3.ZERO
var _loading := false


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless" or OS.get_environment("TOIRE_SAVE_TEST") == "1"
	if OS.get_environment("SHOT_DIR") != "":
		enabled = false
	since_hint = HINT_GAP * 0.5   # 最初のヒントは、止まってから 55 秒（さらに少し余裕を見る）


func total() -> int:
	return DISCOVERIES.size()


func note_activity() -> void:
	idle_t = 0.0


# ---------------------------------------------------------------- 発見

func discover(id: String) -> void:
	if _loading or not DISCOVERIES.has(id) or discovered.has(id):
		return
	discovered[id] = true
	idle_t = 0.0
	main.hud.show_discovery(DISCOVERIES[id], discovered.size(), total())
	save()


# ---------------------------------------------------------------- ヒント

## 状況にあった独り言の候補（先に並べた物ほど優先）。{id, ok: 今出してよいか, text}
func _hints() -> Array:
	var apt = main.room.apartment
	var cel = apt.cellar
	return [
		{"id": "floor", "ok": not discovered.has("cellar"), "text": "そういえば、床の一部が……少しだけ、色が違う気がする。"},
		{"id": "stairs", "ok": discovered.has("stairs") and not discovered.has("basement_letter"), "text": "階段の下に、何かある。降りてみようか。"},
		{"id": "food", "ok": discovered.has("cellar") and not cel.stairs_open and cel.carrying_id.is_empty() and cel.stored.size() < cel.FOODS.size(), "text": "床下の食べ物、ずいぶんたくさん入っている。冷蔵庫へ運んだら……どうなるんだろう。"},
		{"id": "mj_box", "ok": not discovered.has("mahjong"), "text": "押入れの襖を、右へ寄せたことはあっただろうか。ふとんの上に、何か置いてあった気がする。"},
		{"id": "mj_play", "ok": main.inventory.has("mahjong") and not discovered.has("mahjong_play"), "text": "麻雀牌を持っている。こたつの中なら、ひとりでも打てそうだ。"},
		{"id": "disc_see", "ok": not discovered.has("record_disc"), "text": "プレーヤーの横の、丸い額。……あれは、レコード盤じゃないか。"},
		{"id": "disc_put", "ok": main.inventory.has("record_disc") and not discovered.has("record_set"), "text": "レコード盤を持っている。ターンテーブルが、さみしそうだ。"},
		{"id": "bed", "ok": not discovered.has("bed_sleep"), "text": "ふとんが、敷きっぱなしだ。……少しだけ、横になりたい。"},
		{"id": "calm", "ok": true, "text": "焦らなくていい。この部屋は、どこへも行かない。"},
	]


func _next_hint() -> Dictionary:
	for h in _hints():
		if h.ok and not hints_shown.has(h.id):
			return h
	return {}


func force_hint() -> bool:
	var h := _next_hint()
	if h.is_empty():
		return false
	hints_shown[h.id] = true
	since_hint = 0.0
	idle_t = 0.0
	main.hud.show_message(h.text, -1.0, "voice")
	save()
	return true


func _process(delta: float) -> void:
	if main == null or main.player == null or main.title_active():
		return
	var busy: bool = main.paused or main.cleared or main.reading or main.gaming or main.peeping or main.mj_playing \
			or main.player.pose == main.PlayerScript.Pose.TRANSITION or main.player.pose == main.PlayerScript.Pose.LYING
	var pos: Vector3 = main.player.global_position
	if busy or pos.distance_to(_last_pos) > 0.05:
		idle_t = 0.0
	else:
		idle_t += delta
	_last_pos = pos
	since_hint += delta
	if hints_on and not busy and idle_t >= IDLE_TIME and since_hint >= HINT_GAP:
		force_hint()


# ---------------------------------------------------------------- セーブ・ロード

func has_save() -> bool:
	return enabled and FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func snapshot() -> Dictionary:
	var room = main.room
	var apt = room.apartment
	var cel = apt.cellar
	var removed: Array = cel.removed.duplicate()
	if not cel.carrying_id.is_empty():
		removed.erase(cel.carrying_id)   # 手に持っていた物は、床下の棚へ戻す
	return {
		"version": VERSION,
		"play_time": main.play_time,
		"inventory": main.inventory.duplicate(),
		"coin_count": main.coin_count,
		"has_driver": main.has_driver,
		"door_open": main.door_open,
		"powder_used": main.powder_used,
		"cellar": {"open": cel.is_open, "removed": removed, "stored": cel.stored.duplicate(), "stairs_open": cel.stairs_open},
		"mahjong_taken": apt.closet.mahjong_box == null,
		"disc_taken": apt.record_player.display_taken,
		"disc_loaded": apt.record_player.loaded,
		"tank_coin_taken": room.toilet.coin_taken_already,
		"roll_taken": room.supplies.spare_roll_taken,
		"rod_taken": main.fishing.has_rod,
		"gun_taken": main.inventory.has("cork_gun") or apt.kitchen.cork_gun == null,
		"powder_taken": room.bath_powder_taken,
		"examined": main.examined.keys(),
		"discovered": discovered.keys(),
		"hints_shown": hints_shown.keys(),
	}


func save() -> void:
	if not enabled or _loading or main == null or not main.is_node_ready():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(snapshot()))


## 続きから。保存がなければ false。壊れた保存は無視する（はじめから）。
func load_game() -> bool:
	if not has_save():
		return false
	var js := JSON.new()
	if js.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK:
		return false   # 壊れた保存（エラーの出力は出さない）
	var parsed: Variant = js.data
	if typeof(parsed) != TYPE_DICTIONARY or int((parsed as Dictionary).get("version", 0)) != VERSION:
		return false
	apply(parsed)
	return true


func apply(d: Dictionary) -> void:
	_loading = true
	var room = main.room
	var apt = room.apartment
	main.play_time = float(d.get("play_time", 0.0))
	for k in d.get("examined", []):
		main.examined[String(k)] = true
	for k in d.get("discovered", []):
		discovered[String(k)] = true
	for k in d.get("hints_shown", []):
		hints_shown[String(k)] = true
	# 拾った物を、先にそれぞれ棚や床から消す（見た目と照準の判定）
	var inv: Array = d.get("inventory", [])
	if d.get("has_driver", false):
		main.has_driver = true
		if room.driver_node:
			if inv.has("driver"):
				main._item_models["driver"] = room.driver_node.get_node("Visual").duplicate()
			room.remove_driver()
	if d.get("roll_taken", false) and not room.supplies.spare_roll_taken:
		if inv.has("spare_roll"):
			main._item_models["spare_roll"] = main._model_without_areas(room.supplies.get_node("SupplyShelf/SpareRoll"))
		room.supplies.take_spare_roll()
	if d.get("powder_taken", false) and not room.bath_powder_taken:
		if inv.has("bath_powder"):
			main._item_models["bath_powder"] = room.get_node("BathPowder/Visual").duplicate()
		room.take_bath_powder()
	main.powder_used = bool(d.get("powder_used", false))
	if d.get("rod_taken", false):
		main.fishing.has_rod = true
		main.fishing.remove_prop()
		main._item_models["fishing_rod"] = main.FishingScript.zoom_model()
	if d.get("gun_taken", false) and apt.kitchen.cork_gun != null:
		apt.kitchen.remove_gun()
		main._item_models["cork_gun"] = main.CorkGunScript.zoom_model()
	if d.get("mahjong_taken", false) and apt.closet.mahjong_box != null:
		apt.closet.take_mahjong()
		main._item_models["mahjong"] = main.ClosetScriptRef.mahjong_zoom_model()
	if d.get("disc_taken", false) and not apt.record_player.display_taken:
		apt.record_player.take_display()
		main._item_models["record_disc"] = main.RecordPlayerRef.zoom_model()
	if d.get("disc_loaded", false):
		apt.record_player.loaded = true
		apt.record_player._disc_on_platter.visible = true
	if d.get("tank_coin_taken", false):
		room.toilet.coin_taken_already = true
		room.toilet.coin_root.visible = false
	main.coin_count = int(d.get("coin_count", 0))
	if main.coin_count > 0:
		main._item_models["ufo_coin"] = main.FishingScript.coin_model()
	for id in inv:
		if main.ITEMS.has(id) and not main.inventory.has(id):
			main.inventory.append(String(id))
	main.select_item(main.inventory.size() - 1 if not main.inventory.is_empty() else -1)
	if d.get("door_open", false):
		main.door_open = true
		room.open_door()
	# 床下：運んで冷蔵庫に入れた食べ物を、冷蔵庫の棚に並べる。7 つそろっていれば、階段も出す
	var c: Dictionary = d.get("cellar", {})
	var cel = apt.cellar
	cel.set_open(bool(c.get("open", false)), false)
	for id in c.get("removed", []):
		if cel.FOODS.has(id) and not cel.removed.has(id):
			cel.removed.append(String(id))
			for nm in cel.FOODS[id][1]:
				(cel.get_node(nm) as Node3D).visible = false
	for id in c.get("stored", []):
		if cel.FOODS.has(id) and not cel.stored.has(id):
			cel.stored.append(String(id))
			if apt.kitchen.food_nodes.has(id):
				(apt.kitchen.food_nodes[id] as Node3D).visible = true
	cel._refresh_areas()
	if c.get("stairs_open", false) and not cel.stairs_open:
		cel.reveal_stairs()
	_loading = false
