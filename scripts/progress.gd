extends Node
## 進み具合のまわり：①やさしいヒント（神の声の独り言）②見つけた物の記録と、画面の端の小さな知らせ ③簡易セーブ。
## main.gd の子として置く（main が `main` を設定する）。毎フレームの処理は、止まっている時間の加算と、位置の比較だけ。
##
## ヒント：同じ場所で何もしない時間が IDLE_TIME を超えると、状況にあった独り言を 1 つ出す（強制ではない。出したヒントは二度と出さない。
##         つぎのヒントまで HINT_GAP 秒あける。設定で切れる）。
## 発見：DISCOVERIES の物を初めて見つけたとき、画面の右上に「発見　○○　3 / 22」と小さく出す。
## セーブ：user://save.json。持ち物・拾った物・床下の食べ物・階段・レコード・調べた物・発見・出したヒント・プレイ時間だけ。
##         一時停止・終了・発見・食べ物を入れたとき・持ち物が増えたときに書く。起動時に自動で続きから。ヘッドレス（テスト）と撮影では動かさない。

## 保存先。テスト用の環境（TOIRE_SAVE_TEST=1）では別ファイルにして、プレイヤーの本物の保存を上書きしない
var SAVE_PATH := "user://save_test.json" if OS.get_environment("TOIRE_SAVE_TEST") == "1" else "user://save.json"
const VERSION := 1
const HINT_LIMIT := 5                 # 神の声にきける回数（設定から。使うほどクリアのランクが下がる）
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
	"inspect_lever": "点検レバー", "vent_stretch": "背伸びで換気口へ", "ladder": "ボロボロのはしご", "lean_out": "手すりから乗り出す", "ko_line": "KO線", "unit_rise": "ゴゴゴ（浴室が上がった）", "wood_stick": "木の棒",
	"ten_yen": "十円玉", "soap": "固形せっけん", "soap_placed": "せっけんを沈めた", "sink_lid": "洗面台のふた", "soap_dissolved": "せっけんが溶けた", "sinker": "鉛のおもり", "tub_lid": "浴槽のふた", "bath_ball": "入浴剤の玉",
	"ball_dissolved": "玉が溶けた", "match_stick": "マッチ棒", "room_key": "部屋の鍵", "torch": "松明", "torch_thrown": "松明を捨てた", "window_unlocked": "窓の鍵を開けた", "door_knob": "壊れたドアノブ", "hatch_open": "小さな扉が開いた", "fuse": "ヒューズ", "breaker_open": "ブレーカーの蓋", "power_back": "部屋の電気", "chuuren": "九蓮宝燈", "hand_mirror": "手かがみ", "gem": "宝石が割れた", "pickaxe": "大きなツルハシ", "crystal": "結晶", "kotatsu_wall": "こたつの壁を壊した", "washitsu": "隣の和室", "scroll_aligned": "掛け軸の影絵", "bm_dog": "栞（犬）", "bm_monkey": "栞（猿）", "bm_pheasant": "栞（キジ）", "heirloom_open": "家宝が開いた", "photo_tkg": "写真『おふくろのTKG』", "lighter": "ライター", "wood_ladder": "はしご（和室）", "washitsu_coin": "和室のコイン", "rice_pack": "パックご飯", "cold_tkg": "冷めたTKG", "tkg": "TKG", "tkg_eaten": "TKGを食べた", "ladder_placed": "はしごを立てかけた", "star_figure": "射的の当たり", "shot_coin": "射的のコイン", "flashlight": "小さな懐中電灯", "magnifier": "虫眼鏡", "magnet_hook": "磁石付きの釣り針", "earplugs": "耳栓", "home_key": "家の鍵", "blowgun_part": "吹き矢の材料", "mahjong_tiles": "麻雀牌（東・中）", "front_door_unlock": "玄関の鍵を開けた", "bad_book": "悪口本", "bad_book_wet": "濡れた悪口本", "bad_book_flush": "悪口本を流した", "blank_card_0": "白紙のトランプ", "blank_card_1": "白紙のトランプ", "blank_card_2": "白紙のトランプ", "blank_card_3": "白紙のトランプ", "prize_list": "景品一覧表", "safe_open": "押入れの金庫が開いた", "phone_7305": "黒電話に 7305", "small_pickaxe": "小さなツルハシ", "wall_w": "お隣の隔て板を壊した", "wall_e": "おばあちゃんの隔て板を壊した", "granny_chest": "釣りの道具箱", "butsudan": "おばあちゃんの仏壇", "headphones": "ヘッドホン", "placed_item": "置いた物", "height_gauge": "身長計のシール", "painting_button": "絵のボタン", "floor_map": "5階の地図", "sunflower_painting": "ひまわりの絵", "chandelier": "シャンデリアの電球", "blowgun": "吹き矢", "blowgun_hit": "吹き矢が的に当たった", "dart_coin": "ベランダのコイン", "tp_core": "トイレットペーパーの芯", "tp_core2": "使い切った芯", "telescope": "望遠鏡", "telescope_look": "望遠鏡で天井の点をのぞいた", "medal": "メダル", "yen100": "百円玉", "dish_core": "小皿の芯", "feed_box_open": "餌箱の鍵が開いた", "feed_box": "水槽の餌箱", "aq_coin": "水槽のコイン", "closet_safe": "押入れの金庫", "curtain_digits": "カーテンの数字", "lint_washed": "毛だまり", "lint": "毛だまりを拾う", "mirror_paper": "鏡文字のメモ",
}

## 幕（章）の名前。いまの幕より先は、行くまで「？？？」と出す。
const CHAPTERS := [
	"第1幕　ユニットバス", "第2幕　部屋が上がる", "第3幕　暗い部屋",
	"第4幕　隣の和室", "第5幕　トイレへ戻る", "第6幕　つかみ取りと、その先",
]

## クリアのランク表：[名前, この時間（分）以内]。これを超えたら F。ヒントを使うと下がる（rank_for）。
## ※ 時間は暫定。全部の幕がそろったあと、実際の通しプレイの時間で調整する。
const RANK_TABLE := [["SSS", 90], ["S", 120], ["A+", 150], ["A", 180], ["B+", 210], ["B", 240], ["B-", 300], ["C", 360]]

var main: Node
var auto_idle := false           # 何もしないまま時間が過ぎると、勝手に独り言を出すか（ヒントは設定からきく方式のため、ふだんはオフ）
var hints_used := 0              # 出したヒントの数（きいた分・自動の分。「焦らなくていい」は数えない）
var enabled := DisplayServer.get_name() != "headless" or OS.get_environment("TOIRE_SAVE_TEST") == "1"   # ヘッドレスのテストでは、保存しない（本物の保存を壊さない）
var hints_on := true
var discovered := {}
var hints_shown := {}
var idle_t := 0.0
var since_hint := 0.0
var _last_pos := Vector3.ZERO
var _loading := false
var notes: Array = []            # 推理ノート：[{id, kind, title, text}]（見つけた順）
var chapter := 0                 # いまの幕（0 始まり。戻らない）


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


# ---------------------------------------------------------------- 推理ノート・幕

func has_note(id: String) -> bool:
	for n in notes:
		if n.id == id:
			return true
	return false


## 手がかり・パスワードを、推理ノートに自動で記録する（kind：「手がかり」「パスワード」「物」）。初めてのときだけ true。
func add_note(id: String, title: String, text: String, kind := "手がかり") -> bool:
	if has_note(id):
		return false
	notes.append({"id": id, "kind": kind, "title": title, "text": text})
	idle_t = 0.0
	if not _loading and main != null and main.hud != null:
		main.hud.show_note_toast(title)
	save()
	return true


## 幕が進む（戻らない）。
func set_chapter(n: int) -> void:
	if n <= chapter or n >= CHAPTERS.size():
		return
	chapter = n
	idle_t = 0.0
	if not _loading and main != null and main.hud != null:
		main.hud.show_note_toast(CHAPTERS[n])
	save()


func chapter_name() -> String:
	return CHAPTERS[clampi(chapter, 0, CHAPTERS.size() - 1)]


## 目次（推理ノートの上に出す）。いまの幕に印、終えた幕にチェック、先の幕は「？？？」。
func chapter_lines() -> String:
	var lines := PackedStringArray()
	for i in CHAPTERS.size():
		if i < chapter:
			lines.append("✓　" + CHAPTERS[i])
		elif i == chapter:
			lines.append("▶　" + CHAPTERS[i])
		else:
			lines.append("　　？？？")
	return "\n".join(lines)


## ノートの本文（新しい順）。
func notes_text() -> String:
	if notes.is_empty():
		return "（まだ何も書かれていない。気になる紙や文字を見つけると、ここに残る）"
	var out := PackedStringArray()
	for i in range(notes.size() - 1, -1, -1):
		var n: Dictionary = notes[i]
		out.append("【%s】%s\n　　%s" % [n.kind, n.title, n.text])
	return "\n".join(out)


## 保存ファイルから、続きの幕の名前を読む（タイトル画面の「つづきから」に添える）。なければ空。
func saved_chapter_name() -> String:
	if not has_save():
		return ""
	var js := JSON.new()
	if js.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK or typeof(js.data) != TYPE_DICTIONARY:
		return ""
	return CHAPTERS[clampi(int((js.data as Dictionary).get("chapter", 0)), 0, CHAPTERS.size() - 1)]


# ---------------------------------------------------------------- ヒント

## 状況にあった独り言の候補（先に並べた物ほど優先）。{id, ok: 今出してよいか, text}
func _hints() -> Array:
	var apt = main.room.apartment
	var cel = apt.cellar
	var risen: bool = main.room.risen
	var dark: bool = risen and not main.room.power_on
	return [
		{"id": "s6_medal", "ok": main.inventory.has("medal"), "text": "メダルは、つかみ取りに入れてみよう。電気がついているときに。"},
		{"id": "s6_dart", "ok": main.inventory.has("blowgun") and not main.room.exterior.sign_hit, "text": "ベランダから、向かいの壁を狙おう。背伸びをすると、的が見える。"},
		{"id": "s6_blowgun", "ok": main.inventory.has("blowgun_part") and not main.inventory.has("blowgun") and not main.room.exterior.sign_hit, "text": "吹き矢の材料。筒になる物と、矢羽根になる物があれば。"},
		{"id": "s6_mj", "ok": main.inventory.has("mahjong_tiles") and not main.medal_given, "text": "東と中を持って、こたつの中で麻雀を。捨てるのは、いらない牌だ。"},
		{"id": "s6_scope", "ok": main.inventory.has("crystal") and main.inventory.has("tp_core") and not main.inventory.has("telescope"), "text": "結晶と、紙の芯。……合わせたら、何か見えそうだ。"},
		{"id": "s5_feed", "ok": main.inventory.has("paper") and not main.room.apartment.aquarium.feed_unlocked, "text": "鏡文字のメモは、鏡で読もう。水槽の餌箱の鍵かもしれない。"},
		{"id": "s5_phone", "ok": discovered.has("curtain_digits") and not main.phone_coin_taken, "text": "カーテンに浮かんだ数字を、黒電話に。"},
		{"id": "s5_safe", "ok": main.cards_taken.size() >= 4 and not main.room.apartment.closet.safe_open, "text": "カードは、点の多い順に。押入れの金庫へ。"},
		{"id": "s5_cards", "ok": main.cards_taken.size() < 4 and main.power_restored, "text": "白いカード。トイレの青い光で、何か見えるかもしれない。部屋は暗いほうがいい。"},
		{"id": "s5_book2", "ok": main.inventory.has("bad_book") and not main.room.toilet.clogged, "text": "黒い本は、水に流そう。トイレの蓋を開けて。"},
		{"id": "s5_book", "ok": main.power_restored and not main.room.apartment.bad_book_taken, "text": "椅子の上に、黒い本がある。……水に流せないだろうか。"},
		{"id": "s5_door", "ok": main.inventory.has("home_key") and main.room.front_door.locked, "text": "家の鍵は、玄関のドアのためのものだ。"},
		{"id": "s5_prize", "ok": main.coin_count > 0 and main.room.apartment.ufo_catcher.taken < 8 and main.room.power_on, "text": "コインは、つかみ取りに入れよう。景品は、順番に出てくるらしい。"},
		{"id": "s5_star", "ok": not main.shot_coin_taken and main.power_restored, "text": "棚のフィギュアの中に、星の印がついた子がいる。"},
		{"id": "s4_mirror", "ok": dark and risen and main.inventory.has("hand_mirror") and not main.room.apartment.gem_broken, "text": "トイレの青い光を、手かがみで、宝石へ。部屋は暗いほうがいい。"},
		{"id": "s4_wall", "ok": main.inventory.has("pickaxe") and not main.room.apartment.kotatsu.wall_broken, "text": "こたつの中を、ずっと奥まで進んでみよう。壁があった気がする。"},
		{"id": "s4_scroll", "ok": main.region == "washitsu" and not discovered.has("scroll_aligned"), "text": "掛け軸は、ある高さで見ると、ちがうものになる気がする。"},
		{"id": "s3_key", "ok": dark and main.room.exterior.ladder_down and not main.items_found.has("room_key") and main.room.apartment.window_locked, "text": "鍵はどこかに落ちていないか。下を見てみよう。"},
		{"id": "s3_torch", "ok": dark and main.inventory.has("wood_stick") and main.inventory.has("match_stick"), "text": "棒の先に、火をつけられそうだ。"},
		{"id": "s3_dark", "ok": dark and main.region == "room", "text": "電気は、どこから来ているのだろう。"},
		{"id": "s3_knob", "ok": dark and main.inventory.has("door_knob") and not main.room.hatch_open, "text": "ドアノブのない扉が、あった。"},
		{"id": "floor", "ok": not discovered.has("cellar") and main.region in ["room", "hall"], "text": "そういえば、床の一部が……少しだけ、色が違う気がする。"},
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


func hints_left() -> int:
	return maxi(0, HINT_LIMIT - hints_used)


## 設定の「神の声にきく」。回数に限りがある。返り値：ok（ヒントを出した）／off（神の声モードがオフ）／none（もう回数がない）。
func ask_hint() -> String:
	if main.god_silent:
		main.hud.show_message(main.STAGE4["hint_silent"])
		return "none"
	if not hints_on:
		return "off"
	if hints_left() <= 0:
		main.hud.show_message("……もう、教えられることは、ない。", -1.0, "voice")
		return "none"
	force_hint()
	return "ok"


## クリアのランク：時間で決めて、ヒントを 2 回使うごとに 1 段下がる。SSS はヒントなしのときだけ。
static func rank_for(seconds: float, hints: int) -> String:
	var names: Array = []
	var idx := RANK_TABLE.size()   # F
	for i in RANK_TABLE.size():
		names.append(RANK_TABLE[i][0])
		if seconds <= float(RANK_TABLE[i][1]) * 60.0 and idx == RANK_TABLE.size():
			idx = i
	names.append("F")
	idx += hints / 2
	if hints > 0 and idx == 0:
		idx = 1
	return names[mini(idx, names.size() - 1)]


func force_hint() -> bool:
	var h := _next_hint()
	if h.is_empty():
		return false
	hints_shown[h.id] = true
	if h.id != "calm":
		hints_used += 1
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
	if auto_idle and hints_on and not busy and idle_t >= IDLE_TIME and since_hint >= HINT_GAP:
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
		"risen": room.risen,
		"ladder_down": room.exterior.ladder_down,
		"bucket_taken": room.bucket_taken,
		"bucket_in_tub": room.bucket_in_tub,
		"stick_taken": main.inventory.has("wood_stick") or main.items_found.has("wood_stick"),
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
		"hints_used": hints_used,
		"notes": notes.duplicate(true),
		"items_found": main.items_found.keys(),
		"coins_total": main.coins_total,
		"chapter": chapter,
		"stage2": _stage2_snapshot(),
		"stage3": _stage3_snapshot(),
		"stage4": _stage4_snapshot(),
	}


func _stage2_snapshot() -> Dictionary:
	var room = main.room
	return {
		"coin_in_wall": room.towel.has_coin,
		"sink_lid": room.sink.plug_in, "soap_soak": room.sink.soap_soak, "soap_gone": room.sink.soap_gone, "sinker_taken": room.sink.sinker_taken, "soap_taken": room.sink.soap_taken, "soap_in_bowl": room.sink.soap_in_bowl,
		"tub_lid": room.bathtub.lid, "tub_plug_in": room.bathtub.plug_in,
		"ball": room.bathtub.ball, "ball_melt": room.bathtub.ball_melt, "driver_taken": room.bathtub.driver_taken,
		"has_lint": main.has_lint, "lint_present": room.bathtub.lint_present, "lint_taken": room.bathtub.lint_taken,
		"curtain_digits_seen": room.shower_curtain.digits_seen, "paper_taken": room.paper_taken,
	}


func _stage3_snapshot() -> Dictionary:
	var room = main.room
	return {
		"window_locked": room.apartment.window_locked,
		"fusuma_open": room.apartment.hall_fusuma.open,
		"curtain_closed": room.apartment.curtain_closed,
		"knob_taken": room.knob_taken, "hatch_open": room.hatch_open, "fuse_taken": room.fuse_taken,
		"breaker_cover": room.exterior.breaker.cover_open, "breaker_fuse": room.exterior.breaker.fuse_in,
		"power_restored": main.power_restored, "cellar_broken": room.cellar_broken, "cellar_cracks": room.cellar_cracks, "torch_thrown": main.thrown_torch != null and is_instance_valid(main.thrown_torch),
	}


func _stage3_apply(d: Dictionary) -> void:
	var room = main.room
	var apt = room.apartment
	if d.has("window_locked"):
		apt.window_locked = bool(d.window_locked)
	apt.hall_fusuma.set_open(bool(d.get("fusuma_open", false)), true)
	if not bool(d.get("curtain_closed", true)) and apt.curtain_closed:
		apt.curtain_closed = false
		apt.curtain.scale.x = 0.18
	if bool(d.get("knob_taken", false)) and not room.knob_taken:
		room.take_door_knob()
	if bool(d.get("hatch_open", false)) and room.risen:
		room.open_hatch(true)
	if bool(d.get("fuse_taken", false)) and room.hatch_open:
		room.take_fuse()
	room.exterior.breaker.restore(bool(d.get("breaker_cover", false)), bool(d.get("breaker_fuse", false)))
	room.cellar_broken = bool(d.get("cellar_broken", false))
	room.cellar_cracks = int(d.get("cellar_cracks", 0))
	if room.wine_cellar:
		room.wine_cellar.restore(room.cellar_broken, room.cellar_cracks)
	main.power_restored = bool(d.get("power_restored", false))
	if main.power_restored:
		room.set_power(true, true)
	elif bool(d.get("torch_thrown", false)):
		main.restore_thrown_torch()
	elif room.risen and not apt.curtain_closed:
		room.set_moonlight(true)


func _restore_stage3_models(inv: Array) -> void:
	for id in ["match_stick", "room_key", "torch", "door_knob", "fuse"]:
		if inv.has(id):
			main._give_stage3_model(id)


func _stage4_snapshot() -> Dictionary:
	var room = main.room
	var apt = room.apartment
	var w = room.washitsu
	return {
		"mirror_taken": not room.mirror_cabinet.hand_mirror.visible,
		"gem_broken": apt.gem_broken, "pickaxe_taken": apt.pickaxe_taken, "crystal_taken": apt.crystal_taken,
		"wall_broken": apt.kotatsu.wall_broken,
		"slots": w.slots_filled, "heirloom_open": w.heirloom_open, "photo_taken": w.photo_taken,
		"ladder_taken": w.ladder_taken, "coin_taken": w.coin_taken,
		"ladder_placed": room.ladder_placed, "bad_book_taken": apt.bad_book_taken, "cards_taken": main.cards_taken.duplicate(), "cards_in_safe": main.cards_in_safe.duplicate(), "safe_slots": apt.closet.safe_slots.duplicate(), "safe_open": apt.closet.safe_open, "safe_list_taken": main.safe_list_taken, "phone_coin_taken": main.phone_coin_taken, "cards_seen": main.cards_seen.keys(), "painting_slid": room.painting_map.slid, "bulb_present": room.bulb_present, "wall_hits": main.wall_hits.duplicate(), "part_open": room.exterior.part_open.duplicate(), "chest_small": main.chest_small_taken, "placed": main.placed_items.map(func(e): return [e.id, e.node.global_position.x, e.node.global_position.y, e.node.global_position.z, e.node.rotation.y]), "hp_taken": not apt.kotatsu.headphones_node.visible, "medal_given": main.medal_given, "darts_used": main.darts_used, "sign_hit": room.exterior.sign_hit, "dart_coin_taken": room.exterior.dart_coin_taken, "tp_installed": room.supplies.has_paper or room.supplies.used_up, "tp_pulls": room.supplies.pulls, "tp_used_up": room.supplies.used_up, "tp_dish_taken": room.supplies.dish_core_taken, "tp_core2_taken": room.supplies.core2_taken, "memos_found": main.memos_found.duplicate(), "muttered": main.muttered.duplicate(), "mutter_i": main._mutter_idle_i, "feed_unlocked": apt.aquarium.feed_unlocked, "tank_coin_taken": apt.aquarium.coin_taken, "toilet_clogged": room.toilet.clogged, "ufo_taken": apt.ufo_catcher.taken, "front_unlocked": not room.front_door.locked, "shot_coin_taken": main.shot_coin_taken, "shot_coin_pos": [main.shot_coin_node.position.x, main.shot_coin_node.position.y, main.shot_coin_node.position.z] if main.shot_coin_node else [], "god_silent": main.god_silent, "lighter_taken": room.exterior.breaker.lighter_taken, "rice_taken": room.apartment.kitchen.rice_taken,
	}


func _stage4_apply(d: Dictionary) -> void:
	var room = main.room
	var apt = room.apartment
	var w = room.washitsu
	if bool(d.get("mirror_taken", false)):
		room.mirror_cabinet.take_hand_mirror()
	apt.pickaxe_taken = bool(d.get("pickaxe_taken", false))
	apt.crystal_taken = bool(d.get("crystal_taken", false))
	if bool(d.get("gem_broken", false)):
		apt.break_gem(true)
	if bool(d.get("wall_broken", false)):
		apt.kotatsu.break_wall(true)
	w.slots_filled = int(d.get("slots", 0))
	for i in w.slots_filled:
		w.light_slot(i)
	w.photo_taken = bool(d.get("photo_taken", false))
	if bool(d.get("heirloom_open", false)):
		w.open_heirloom(true)
	if bool(d.get("ladder_taken", false)):
		w.take_ladder()
	if bool(d.get("coin_taken", false)):
		w.take_coin()
	if bool(d.get("ladder_placed", false)):
		room.place_ladder()
	main.cards_taken = Array(d.get("cards_taken", [])).map(func(v): return int(v))
	main.cards_in_safe = Array(d.get("cards_in_safe", [])).map(func(v): return int(v))
	main.safe_list_taken = bool(d.get("safe_list_taken", false))
	main.phone_coin_taken = bool(d.get("phone_coin_taken", false))
	main.medal_given = bool(d.get("medal_given", false))
	for cid in Array(d.get("cards_seen", [])):
		main.cards_seen[String(cid)] = true
	room.painting_map.set_slid(bool(d.get("painting_slid", false)))
	room.set_bulb(bool(d.get("bulb_present", true)))
	var wh: Dictionary = d.get("wall_hits", {})
	main.chest_small_taken = bool(d.get("chest_small", false))
	var po: Dictionary = d.get("part_open", {})
	for sd in ["w", "e"]:
		main.wall_hits[sd] = int(wh.get(sd, 0))
		if main.wall_hits[sd] > 0:
			room.exterior.set_partition_damage(sd, minf(1.0, float(main.wall_hits[sd]) / float(room.exterior.PART_HITS["pickaxe"])))
		if bool(po.get(sd, false)):
			room.exterior.break_partition(sd, true)
	if bool(d.get("hp_taken", false)):
		apt.kotatsu.take_headphones()
	var placed_ids: Array = []
	for e in Array(d.get("placed", [])):
		placed_ids.append(String(e[0]))
	if not placed_ids.is_empty():
		_restore_stage2_models(placed_ids)
		_restore_stage3_models(placed_ids)
		_restore_stage4_models(placed_ids)
		for e in Array(d.get("placed", [])):
			main._place_item(String(e[0]), Vector3(float(e[1]), float(e[2]), float(e[3])), float(e[4]))
			main.items_found[String(e[0])] = true
		for k in main._item_models.keys():
			if not main.inventory.has(k):
				(main._item_models[k] as Node).free()
				main._item_models.erase(k)
	main.darts_used = int(d.get("darts_used", 0))
	room.exterior.sign_hit = bool(d.get("sign_hit", false))
	room.exterior.dart_coin_taken = bool(d.get("dart_coin_taken", false))
	if room.exterior.sign_hit:
		room.exterior.drop_dart_coin()
	room.supplies.restore_paper(bool(d.get("tp_installed", false)), int(d.get("tp_pulls", 0)), bool(d.get("tp_used_up", false)), bool(d.get("tp_dish_taken", false)), bool(d.get("tp_core2_taken", false)))
	main.memos_found = Array(d.get("memos_found", [])).map(func(v): return String(v))
	main.muttered = Dictionary(d.get("muttered", {}))
	main._mutter_idle_i = int(d.get("mutter_i", 0))
	apt.aquarium.coin_taken = bool(d.get("tank_coin_taken", false))
	if bool(d.get("feed_unlocked", false)):
		apt.aquarium.unlock_feed_box(true)
	for ck in main.cards_taken:
		apt.closet.hide_card(ck)
		apt.hide_card(ck)
	for dv in Array(d.get("safe_slots", [])):
		apt.closet.safe_slots.append(int(dv))
		apt.closet._add_marker(apt.closet.safe_slots.size() - 1)
	if bool(d.get("safe_open", false)):
		apt.closet.open_safe(true)
	if bool(d.get("bad_book_taken", false)):
		apt.take_bad_book()
	if bool(d.get("toilet_clogged", false)):
		room.toilet.restore_clogged()
	var ufo_n := int(d.get("ufo_taken", 0))
	for i in mini(ufo_n, apt.ufo_catcher.prizes.size()):
		apt.ufo_catcher.prizes[i].taken = true
		(apt.ufo_catcher.prizes[i].node as Node3D).visible = false
	apt.ufo_catcher.taken = ufo_n
	if bool(d.get("front_unlocked", false)):
		room.front_door.locked = false
	main.shot_coin_taken = bool(d.get("shot_coin_taken", false))
	var sc: Array = d.get("shot_coin_pos", [])
	if sc.size() == 3 and not main.shot_coin_taken:
		main.spawn_shot_coin(Vector3(sc[0], sc[1] - 0.012, sc[2]))
	if bool(d.get("rice_taken", false)):
		apt.kitchen.take_rice()
	main.fishing.magnet = main.inventory.has("magnet_hook") or main.items_found.has("magnet_hook")
	main.god_silent = bool(d.get("god_silent", false))
	main.hud.voice_silenced = main.god_silent
	room.exterior.breaker.restore(room.exterior.breaker.cover_open, room.exterior.breaker.fuse_in, bool(d.get("lighter_taken", false)))


func _restore_stage4_models(inv: Array) -> void:
	for id in ["hand_mirror", "pickaxe", "crystal", "bm_dog", "bm_monkey", "bm_pheasant", "lighter", "wood_ladder", "photo_tkg", "rice_pack", "cold_tkg", "tkg", "flashlight", "magnifier", "magnet_hook", "earplugs", "home_key", "blowgun_part", "mahjong_tiles", "bad_book", "bad_book_wet", "blowgun", "headphones", "small_pickaxe", "chandelier_bulb", "tp_core", "tp_core2", "telescope", "medal", "blank_card_0", "blank_card_1", "blank_card_2", "blank_card_3", "prize_list"]:
		if inv.has(id):
			main._give_stage4_model(id)


func _restore_stage2_models(inv: Array) -> void:
	if inv.has("ten_yen"):
		main._item_models["ten_yen"] = main.TowelRef.coin_model()
	if inv.has("soap"):
		main._item_models["soap"] = main.SinkRef.soap_model()
	if inv.has("sinker"):
		main._item_models["sinker"] = main.SinkRef.sinker_model()
	if inv.has("paper"):
		main._item_models["paper"] = main.RoomScript.paper_model(true)
	if inv.has("lint"):
		var lm := Node3D.new()
		for off in [Vector3.ZERO, Vector3(0.012, -0.004, 0.008), Vector3(-0.01, -0.005, 0.01)]:
			main.MeshKit.sphere(lm, 0.02, off, main.MeshKit.mat("lint_zoom", Color(0.55, 0.52, 0.5), 0.95))
		main._item_models["lint"] = lm


func _stage2_apply(d: Dictionary) -> void:
	var room = main.room
	if not bool(d.get("coin_in_wall", true)):
		room.towel.take_coin()
	room.sink.restore(bool(d.get("sink_lid", false)), float(d.get("soap_soak", 0.0)), bool(d.get("soap_gone", false)), bool(d.get("sinker_taken", false)), bool(d.get("soap_taken", false)), bool(d.get("soap_in_bowl", false)))
	room.bathtub.restore(String(d.get("tub_lid", "none")), bool(d.get("tub_plug_in", false)), String(d.get("ball", "")), float(d.get("ball_melt", 0.0)),
			bool(d.get("driver_taken", false)), bool(d.get("lint_present", false)), bool(d.get("lint_taken", false)))
	main.has_lint = bool(d.get("has_lint", true))
	room.shower_curtain.digits_seen = bool(d.get("curtain_digits_seen", false))
	if bool(d.get("paper_taken", false)) and not room.paper_taken:
		room.take_paper()


var save_deferred := false   # 取引（購入・交換・景品）の最中に保存を頼まれた：終わってから保存する


func save() -> void:
	if _loading or main == null or not main.is_node_ready():
		return
	if main.txn > 0:
		save_deferred = true   # 途中の状態（物が減って、まだ報酬がない）を保存しない
		return
	if not enabled:
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
	notes.clear()
	for n in d.get("notes", []):
		if typeof(n) == TYPE_DICTIONARY and n.has("id"):
			notes.append({"id": String(n.id), "kind": String(n.get("kind", "手がかり")), "title": String(n.get("title", "")), "text": String(n.get("text", ""))})
	hints_used = int(d.get("hints_used", 0))
	_stage2_apply(d.get("stage2", {}))
	chapter = clampi(int(d.get("chapter", 0)), 0, CHAPTERS.size() - 1)
	for k in d.get("items_found", []):
		main.items_found[String(k)] = true
	main.coins_total = int(d.get("coins_total", 0))
	if d.get("bucket_taken", false) and not room.bucket_taken:
		room.take_bucket()
	if d.get("bucket_in_tub", false):
		room.place_bucket_in_tub()
	if d.get("ladder_down", false):
		pass   # はしごは、上がった高さが決まってから（下の risen の処理のあと）下ろす
	if d.get("risen", false) and not room.risen:
		room.mirror_cabinet.pull_lever_visual(true)
		room.rise_unit(main.player, true)
		if d.get("stick_taken", false):
			room.take_wood_stick()
	if d.get("ladder_down", false) and not room.exterior.ladder_down:
		room.exterior.lower_ladder(room.exterior.DUCT_FLOOR + room.rise_offset, true)
	# 拾った物を、先にそれぞれ棚や床から消す（見た目と照準の判定）
	var inv: Array = d.get("inventory", [])
	if d.get("has_driver", false):
		main.has_driver = true
		if inv.has("driver"):
			main._item_models["driver"] = room.bathtub.get_node("TubDriver/Visual").duplicate()
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
		main.items_found[String(id)] = true
	_restore_stage2_models(inv)
	_restore_stage3_models(inv)
	_restore_stage4_models(inv)
	main.select_item(-1)
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
	_stage3_apply(d.get("stage3", {}))
	_stage4_apply(d.get("stage4", {}))
	_loading = false
