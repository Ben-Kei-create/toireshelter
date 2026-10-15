extends Node3D
## ベランダの釣り。室外機の後ろに立てかけた釣り竿を拾うと、手すりの前から下の路地へ釣り糸を垂らせる。
## 操作は左クリックだけ：手すりを狙ってクリック＝糸を垂らす → 浮きが跳ねたらクリック＝引き上げる。
## 釣れるのは、ゴミ・お宝・ほかのアイテム（合わせて 28 種類）。釣った物は「釣果」として数える（設定画面で確認できる）。
## UFOキャッチャーのコインを釣ったときだけ持ち物になる（main.gd が受け取る）。ほかの物は、釣った順にベランダの床へランダムに置かれていく。
## 置き物は調べられ、最初の 5 個だけは簡単な当たり判定がある（それ以降は見た目だけ。置けるのは 24 個まで、古い物から消える）。
## 脱出や謎解きとは関係ない遊び。座標は部屋と同じ（ベランダの床は y 0、手すりは z -2.1）。
## 判定：釣り竿（id fishing_rod、拾う）と、手すり沿いの釣り場（id fish_spot。fixture として get_prompt／interact を持つ）。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

signal notice(text: String)
signal coin_caught   # UFOコインが釣れた（持ち物に入る）
signal item_caught(id: String)   # お話の持ち物（マッチ棒・部屋の鍵）が釣れた。main.gd が持ち物に入れる
signal collection_changed(text: String)   # 釣果が変わった（設定画面の行を更新する）

const ROD_POS := Vector3(3.64, 0.0, -1.68)      # 室外機のうしろ、右端の隔て板との隙間に立てかけてある
const ROD_LEN := 1.55
const RAIL_Z := -2.1
const SPOT_X := Vector2(1.5, 3.1)
const GROUND_Y := -13.6                          # 路地の地面（1 階。5 階の 4 階ぶん下）
const WAIT_RANGE := Vector2(2.5, 6.0)
const MAX_SOLID := 5          # 当たり判定のある置き物の数
const MAX_PLACED := 24
const SANDAL := Vector2(2.8, -1.5)
const POT := Vector2(1.45, -1.98)

## 釣れる物 [種類, 名前, 説明, 重み]
const CATCHES := [
	["ゴミ", "空き缶", "ぺしゃんこの空き缶。底に何か書いてあったが、読めない。", 10],
	["ゴミ", "ペットボトル", "ラベルのはがれたペットボトル。中身は雨水だった。", 10],
	["ゴミ", "片方だけの靴下", "かたい。何日ぶんの汚れだろう。", 8],
	["ゴミ", "しわくちゃのレシート", "『おでん　大根　ちくわ』。日付は去年だ。", 8],
	["ゴミ", "割れたビニール傘", "骨が3本折れている。", 6],
	["ゴミ", "折れた割り箸", "割ったとき、うまく割れなかったらしい。", 8],
	["ゴミ", "使い捨てライター", "カチカチするが、火はつかない。", 6],
	["ゴミ", "古いスポーツ新聞", "見出しは『ついに優勝へ』。何年のだろう。", 6],
	["ゴミ", "レジ袋", "『ポイントカードはお持ちですか』と書いてある。", 8],
	["ゴミ", "ボタン電池", "もう空だろう。……たぶん。", 4],
	["ゴミ", "輪ゴムの塊", "ほどけない。ほどくのはあきらめた。", 6],
	["ゴミ", "錆びたスプーン", "これで何をすくっていたのか。", 5],
	["お宝", "古い金貨", "表の絵は、見たことのない王様の横顔。", 3],
	["お宝", "銀の指輪", "内側に小さく『Y to K』と彫ってある。", 3],
	["お宝", "翡翠のかけら", "水に濡れると、ふかい緑がきれいに光る。", 3],
	["お宝", "小さな琥珀", "中に、ちいさな虫が眠っている。", 2],
	["お宝", "昭和の記念硬貨", "ぴかぴかだ。集めている人には高く売れそう。", 4],
	["お宝", "真珠", "一粒だけ。ほんものかどうかは、分からない。", 2],
	["お宝", "金色の鍵", "どこかの鍵に見えるが、この部屋の物ではなさそうだ。", 1],
	["アイテム", "未開封の缶コーヒー", "あたたかい。捨てた人が、すぐ後悔したのかもしれない。", 6],
	["アイテム", "使い捨てカイロ", "まだほんのりあたたかい。", 5],
	["アイテム", "小さな方位磁石", "針が北をささずに、ゆっくり回りつづけている。", 3],
	["アイテム", "懐中電灯", "つけると、いちど光って消えた。", 3],
	["アイテム", "片方の手袋", "毛糸の手袋。ちゃんと洗ってあるように見える。", 5],
	["アイテム", "折りたたんだ地図", "広げると、見たことのない街の地図だった。", 2],
	["アイテム", "ミニ双眼鏡", "のぞくと、ベランダの手すりが大きく見えた。", 2],
	["アイテム", "おもちゃのメダル", "『よくがんばりました』と書いてある。", 4],
	["アイテム", "UFOキャッチャーのコイン", "表にエイリアンの絵。クレーンゲームで使えそうだ。持ち物に入れた。", 3, "coin"],
]
const KIND_WEIGHTS := {"ゴミ": 50, "アイテム": 30, "お宝": 20}
const KIND_COLORS := {"ゴミ": Color(0.45, 0.45, 0.42), "アイテム": Color(0.35, 0.6, 0.85), "お宝": Color(1.0, 0.8, 0.2)}

var has_rod := false
var magnet := false              # 磁石付きの釣り針（景品 3）：金属の物（お宝・アイテム）が出やすい
var story_next: Callable                 # 次に釣れるお話の持ち物の id を返す（main.gd）。なければ ""
var _story_misses := 0                   # お話の物が出ないまま釣った回数（数回で必ず出る）
const STORY_CHANCE := 0.45
const STORY_MAX_MISSES := 3
const STORY_CATCHES := {
	"match_stick": ["アイテム", "マッチ棒", "たった 1 本のマッチ。箱は、どこかで湿ってしまったらしい。", 0, "story", "match_stick"],
	"wood_stick": ["アイテム", "木の棒", "ドアの枠の破片のような、まっすぐな木の棒。", 0, "story", "wood_stick"],
	"room_key": ["アイテム", "部屋の鍵", "この部屋の窓の鍵。見覚えのあるキーホルダーが付いている。", 0, "story", "room_key"],
}
## まれに釣れる、小さなツルハシ（種類の数には入れない。一度釣れたら、もう出ない）
const SMALL_PICKAXE := ["アイテム", "小さなツルハシ", "ちいさな、ちいさなツルハシ。壁を壊すには、気が遠くなりそうだ。", 0, "story", "small_pickaxe"]
const SMALL_PICKAXE_CHANCE := 0.03
var small_pickaxe_caught := false
var state := "idle"            # idle / waiting / bite / reeling
var caught := {}               # 名前 → 回数
var last_text := ""
var last_kind := ""
var player: Node3D
var _wait := 0.0
var _cast_x := 2.5
var _rng := RandomNumberGenerator.new()
var _rod_prop: Node3D
var _cast_rod: Node3D
var _line: MeshInstance3D
var _bobber: MeshInstance3D
var _hook_item: MeshInstance3D
var _line_len := 0.0
var _top := Vector3.ZERO      # 竿の先（糸の出る所）
var _tween: Tween
var _t := 0.0
var placed: Array = []       # 置いた物 {node, id, name, kind, desc, solid}
var _placed_serial := 0
var _pending: Array = []


func _ready() -> void:
	_rng.randomize()
	MeshKit.auto_round = false
	_rod_prop = Node3D.new()
	_rod_prop.name = "RodProp"
	_rod_prop.position = ROD_POS + Vector3(0, ROD_LEN * 0.5, 0)
	_rod_prop.rotation.z = -0.03   # 隔て板に寄りかかる（上が +x へ少し）
	add_child(_rod_prop)
	var rod := build_rod(ROD_LEN)
	rod.position.y = -ROD_LEN * 0.5
	_rod_prop.add_child(rod)
	var a := MeshKit.interact_area(_rod_prop, "RodArea", "fishing_rod")
	MeshKit.shape_box(a, Vector3(0.14, ROD_LEN, 0.14), Vector3.ZERO)
	a.set_meta("interact_range", 2.6)
	# 釣り場：手すり（z -2.1）の手前に、見えない判定
	var spot := MeshKit.interact_area(self, "SpotArea", "fish_spot", self)
	MeshKit.shape_box(spot, Vector3(SPOT_X.y - SPOT_X.x + 0.2, 1.0, 0.1), Vector3((SPOT_X.x + SPOT_X.y) * 0.5, 0.9, RAIL_Z + 0.12))
	spot.set_meta("interact_range", 2.2)
	# 釣り糸・浮き（使うときだけ見える）
	var line_m := MeshKit.mat("fishing_line", Color(0.9, 0.9, 0.85), 0.6)
	_line = MeshInstance3D.new()
	_line.name = "Line"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.003
	cm.bottom_radius = 0.003
	cm.height = 1.0
	cm.radial_segments = 4
	cm.rings = 1
	_line.mesh = cm
	_line.material_override = line_m
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.visible = false
	add_child(_line)
	_bobber = MeshKit.sphere(self, 0.05, Vector3.ZERO, MeshKit.mat("fishing_bobber", Color(0.95, 0.2, 0.15), 0.4))
	_bobber.name = "Bobber"
	_bobber.visible = false
	_hook_item = MeshKit.sphere(self, 0.07, Vector3.ZERO, MeshKit.mat("fishing_catch", Color(0.7, 0.7, 0.7), 0.5))
	_hook_item.name = "CatchModel"
	_hook_item.visible = false
	_cast_rod = build_rod(ROD_LEN)
	_cast_rod.name = "CastRod"
	_cast_rod.visible = false
	add_child(_cast_rod)
	MeshKit.auto_round = true


## 釣り竿の見た目。原点は手元の端、+y へ length。竹色の竿、握りのコルク、リール、ガイド、糸の先の針。
static func build_rod(length: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Rod"
	var bamboo := MeshKit.mat("rod_bamboo", Color(0.62, 0.5, 0.25), 0.55)
	var cork := MeshKit.mat("rod_cork", Color(0.72, 0.58, 0.4), 0.9)
	var metal := MeshKit.mat("rod_metal", Color(0.75, 0.75, 0.78), 0.3, 0.8)
	var red := MeshKit.mat("rod_wrap", Color(0.6, 0.1, 0.1), 0.6)
	var segs := 4
	for i in segs:
		var r0 := lerpf(0.016, 0.004, float(i) / segs)
		var r1 := lerpf(0.016, 0.004, float(i + 1) / segs)
		var h := length * 0.82 / segs
		MeshKit.cylinder(n, r0, h, Vector3(0, length * 0.18 + h * (i + 0.5), 0), bamboo, "Seg%d" % i, r1)
		if i > 0:
			MeshKit.cylinder(n, r0 + 0.002, 0.014, Vector3(0, length * 0.18 + h * i, 0), red, "Wrap%d" % i)
	MeshKit.cylinder(n, 0.02, length * 0.18, Vector3(0, length * 0.09, 0), cork, "Grip", 0.017)
	# リール：握りの上、横に張り出す
	var reel := MeshKit.cylinder(n, 0.022, 0.02, Vector3(0.025, length * 0.2, 0), metal, "Reel")
	reel.rotation.x = PI * 0.5
	MeshKit.box(n, Vector3(0.03, 0.006, 0.006), Vector3(0.012, length * 0.2, 0), metal, "ReelArm")
	# ガイド（3か所）
	for k in 3:
		var gy := length * (0.45 + 0.17 * k)
		var g := MeshKit.cylinder(n, 0.008, 0.002, Vector3(0.014, gy, 0), metal, "Guide%d" % k)
		g.rotation.z = PI * 0.5
	return n


## UFOコインの拡大表示用モデル。
static func coin_model() -> Node3D:
	var holder := Node3D.new()
	holder.name = "CoinModel"
	var c := MeshKit.cylinder(holder, 0.05, 0.008, Vector3.ZERO, MeshKit.mat("ufo_coin", Color(0.95, 0.78, 0.25), 0.25, 0.8), "Coin")
	c.rotation.x = PI * 0.5
	var tex := MeshKit.prop_tex("ufo_coin_face")   # エイリアンの絵（ユーザー作成・生成 AI 使用）
	MeshKit.image_quad(holder, tex, Vector2(0.1, 0.1), Vector3(0, 0, 0.0042), Vector3.BACK, "FaceFront", false, 0.35)
	MeshKit.image_quad(holder, tex, Vector2(0.1, 0.1), Vector3(0, 0, -0.0042), Vector3.FORWARD, "FaceBack", false, 0.35)
	return holder


## 持ち物の拡大表示用：短くして横に寝かせた釣り竿。
static func zoom_model() -> Node3D:
	var holder := Node3D.new()
	holder.name = "RodModel"
	var rod := build_rod(1.55)
	rod.scale = Vector3.ONE * 0.16
	rod.position = Vector3(-0.124, 0.0, 0.0)
	rod.rotation.z = -PI * 0.5
	holder.add_child(rod)
	return holder


func remove_prop() -> void:
	_rod_prop.visible = false
	for a in _rod_prop.get_children():
		if a is Area3D:
			(a as Area3D).collision_layer = 0


func collection_text() -> String:
	var total := CATCHES.size()
	var by := {"ゴミ": 0, "お宝": 0, "アイテム": 0}
	for c in CATCHES:
		if caught.has(c[1]):
			by[c[0]] += 1
	var n: int = caught.size()
	if n == 0:
		return "釣果：まだ何も釣っていない（全 %d 種類）" % total
	return "釣果：%d / %d 種類（ゴミ %d・お宝 %d・アイテム %d）" % [n, total, by["ゴミ"], by["お宝"], by["アイテム"]]


# ---------------------------------------------------------------- 釣り（fixture）

func get_prompt(id: String) -> String:
	if id.begins_with("catch_"):
		return "catch_look"
	if not has_rod:
		return "fish_need_rod_prompt"
	match state:
		"idle":
			return "fish_cast"
		"waiting":
			return "fish_wait"
		"bite":
			return "fish_reel"
	return ""


func interact(id: String) -> String:
	if id.begins_with("catch_"):
		for p in placed:
			if "catch_%d" % p.id == id:
				last_text = "【%s】%s\n%s" % [p.kind, p.name, p.desc]
				return "fishing_text"
		return ""
	if not has_rod:
		return "fish_need_rod"
	match state:
		"idle":
			_cast()
			return "fish_cast_msg"
		"waiting":
			_cancel(true)
			return "fish_early"
		"bite":
			_reel()
			return "fishing_text"
	return ""


func format_message(_key: String, text: String) -> String:
	return text.replace("{text}", last_text)


func _cast() -> void:
	var px := 2.5
	if player:
		px = clampf(player.global_position.x, SPOT_X.x, SPOT_X.y)
	_cast_x = px
	state = "waiting"
	_wait = _rng.randf_range(WAIT_RANGE.x, WAIT_RANGE.y)
	Sfx.play("slide", 1.6, -8.0)
	# 竿を手すりの外へ突き出し、先から糸が真下へ伸びていく
	_cast_rod.visible = true
	_cast_rod.position = Vector3(px + 0.3, 0.85, RAIL_Z + 0.25)   # 視界のじゃまにならないよう、右手のほう
	_cast_rod.rotation = Vector3(deg_to_rad(-65.0), 0, 0)   # 手元が手すりの内側、先が手すりの外・斜め上へ
	_top = _cast_rod.transform * Vector3(0, ROD_LEN, 0)
	_hook_item.visible = false
	_bobber.visible = true
	_line.visible = true
	_line_len = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_line_len, 0.3, _top.y - GROUND_Y - 0.1, 1.2).set_trans(Tween.TRANS_SINE)


func _set_line_len(l: float) -> void:
	_line_len = l
	_update_line()


func _update_line() -> void:
	var top := _top
	var bottom := top + Vector3(0, -_line_len, 0)
	_line.position = (top + bottom) * 0.5
	(_line.mesh as CylinderMesh).height = maxf(_line_len, 0.01)
	_bobber.position = bottom + Vector3(0, 0.0, 0)
	_hook_item.position = bottom + Vector3(0, -0.05, 0)


func _process(delta: float) -> void:
	_t += delta
	if state == "waiting":
		_wait -= delta
		if player and absf(player.global_position.x - _cast_x) > 2.5:
			_cancel(false)
			return
		if _wait <= 0.0:
			state = "bite"
			_wait = 4.0
			Sfx.play("plop", 0.9, -4.0)
			notice.emit("浮きが跳ねた！ いまだ、左クリック！")
	elif state == "bite":
		# 浮きが小刻みに震える。4 秒たつと逃げられる
		_bobber.position.x = _top.x + sin(_t * 40.0) * 0.03
		_wait -= delta
		if _wait <= 0.0:
			_cancel(false)
			notice.emit("……逃げられた。糸が軽くなった。")
	elif state == "waiting" or state == "idle":
		pass


func _cancel(_early: bool) -> void:
	state = "idle"
	if _tween:
		_tween.kill()
	_line.visible = false
	_bobber.visible = false
	_cast_rod.visible = false
	_hook_item.visible = false


func _reel() -> void:
	state = "reeling"
	var pick := _pick()
	last_kind = pick[0]
	var first: bool = not caught.has(pick[1])
	caught[pick[1]] = int(caught.get(pick[1], 0)) + 1
	last_text = "【%s】%s を釣り上げた%s\n%s\n%s" % [pick[0], pick[1], "！（はじめて）" if first else "。（%d 回目）" % caught[pick[1]], pick[2], collection_text()]
	collection_changed.emit(collection_text())
	(_hook_item.material_override as StandardMaterial3D).albedo_color = KIND_COLORS[pick[0]]
	_hook_item.visible = true
	_bobber.visible = false
	Sfx.play("pop", 0.8)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_line_len, _line_len, 0.2, 1.4).set_trans(Tween.TRANS_SINE)
	_pending = pick
	_tween.tween_callback(func() -> void:
		state = "idle"
		_line.visible = false
		_hook_item.visible = false
		_cast_rod.visible = false
		Sfx.play("chime" if last_kind == "お宝" else "click", 1.2, -6.0)
		_land(_pending))


## 釣れた物を手に入れる：コインは持ち物へ、それ以外はベランダの床へ置く。
func _land(pick: Array) -> void:
	if pick.size() > 4 and pick[4] == "coin":
		coin_caught.emit()
		return
	if pick.size() > 5 and pick[4] == "story":
		item_caught.emit(String(pick[5]))
		return
	_place(pick)


## ベランダの床へランダムに置く。最初の MAX_SOLID 個は手すりぎわ（体の通り道の外）に置いて当たり判定をつける。
func _place(pick: Array) -> void:
	var solid := placed.filter(func(p): return p.solid).size() < MAX_SOLID
	var size := Vector3(_rng.randf_range(0.07, 0.12), _rng.randf_range(0.04, 0.09), _rng.randf_range(0.07, 0.12))
	var pos := Vector3.ZERO
	for _try in 30:
		var x := _rng.randf_range(1.6, 3.1)
		var z := _rng.randf_range(-2.0, -1.9) if solid else _rng.randf_range(-2.0, -1.45)
		pos = Vector3(x, size.y * 0.5, z)
		var ok := Vector2(x, z).distance_to(SANDAL) > 0.2 and Vector2(x, z).distance_to(POT) > 0.2
		for p in placed:
			if Vector2(x, z).distance_to(Vector2(p.node.position.x, p.node.position.z)) < 0.16:
				ok = false
		if ok:
			break
	var col: Color = KIND_COLORS[pick[0]]
	var n := Node3D.new()
	n.name = "Catch%02d" % _placed_serial
	n.position = pos
	n.rotation.y = _rng.randf_range(0.0, TAU)
	add_child(n)
	var mat := MeshKit.mat("catch_%s" % pick[0], col.darkened(0.2) if pick[0] == "ゴミ" else col, 0.6, 0.3 if pick[0] == "お宝" else 0.0)
	if pick[0] == "お宝":
		MeshKit.sphere(n, size.y * 0.55, Vector3.ZERO, mat)
	else:
		MeshKit.box(n, size, Vector3.ZERO, mat, "Body")
	var area := MeshKit.interact_area(n, "CatchArea", "catch_%d" % _placed_serial, self)
	MeshKit.shape_box(area, size + Vector3(0.04, 0.04, 0.04), Vector3.ZERO)
	if solid:
		var body := StaticBody3D.new()
		body.name = "Solid"
		body.collision_layer = MeshKit.LAYER_WORLD
		body.collision_mask = 0
		n.add_child(body)
		MeshKit.shape_box(body, size, Vector3.ZERO)
	placed.append({"node": n, "id": _placed_serial, "name": pick[1], "kind": pick[0], "desc": pick[2], "solid": solid})
	_placed_serial += 1
	if placed.size() > MAX_PLACED:
		var old: Dictionary = placed.pop_front()
		(old.node as Node3D).queue_free()


func _pick() -> Array:
	var weights: Dictionary = KIND_WEIGHTS
	if magnet:
		weights = {"ゴミ": 25, "アイテム": 42, "お宝": 33}
	# お話の持ち物（マッチ棒・部屋の鍵）：ふつうの当たりのひとつとして、高い確率で出る。数回釣れば、必ず出る
	if story_next.is_valid():
		var sid := String(story_next.call())
		if sid != "" and STORY_CATCHES.has(sid):
			_story_misses += 1
			if _story_misses > STORY_MAX_MISSES or _rng.randf() < STORY_CHANCE:
				_story_misses = 0
				return STORY_CATCHES[sid]
	if not small_pickaxe_caught and _rng.randf() < SMALL_PICKAXE_CHANCE:
		small_pickaxe_caught = true
		return SMALL_PICKAXE
	var kinds: Array = weights.keys()
	var kt := 0
	for k in kinds:
		kt += int(weights[k])
	var r := _rng.randi_range(0, kt - 1)
	var kind: String = kinds[0]
	for k in kinds:
		r -= int(weights[k])
		if r < 0:
			kind = k
			break
	var pool := CATCHES.filter(func(c): return c[0] == kind)
	var wt := 0
	for c in pool:
		wt += int(c[3])
	var rr := _rng.randi_range(0, wt - 1)
	for c in pool:
		rr -= int(c[3])
		if rr < 0:
			return c
	return pool[0]
