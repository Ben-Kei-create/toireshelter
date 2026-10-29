extends RefCounted
## 置物の絵のシールを、排水口のまわりをはじめ、あちこちにペタペタ貼る（39 枚。figure_art.gd の STICKERS を順に使う）。
## 見た目だけ（当たり判定なし）。貼り先は、浴室の床の排水口・浴槽・洗面台・壁、ホールの床、廊下の排水の溝、1 階の玄関ホール、路地、ベランダ、机の下。
## 浴室まわり（room・浴槽・洗面台）に貼った物は、浴室がせり上がるとき、いっしょに上がる。

const FigureArt := preload("res://scripts/figure_art.gd")
const UP := Vector3.UP

## [貼り先, 位置, 向き, 高さ, 傾き]。貼り先：room／tub／sink／apartment／corridor／entrance／exterior（それぞれの座標）
const SPOTS := [
	# 浴室の床の排水口（-0.15, 0, -0.33）のまわり
	["room", Vector3(-0.32, 0.002, -0.28), UP, 0.12, 12.0],
	["room", Vector3(-0.06, 0.002, -0.22), UP, 0.10, -20.0],
	["room", Vector3(-0.22, 0.002, -0.40), UP, 0.13, 35.0],
	["room", Vector3(0.12, 0.002, -0.36), UP, 0.11, -8.0],
	["room", Vector3(-0.10, 0.002, -0.12), UP, 0.09, 50.0],
	# 浴槽の手前の面
	["tub", Vector3(-0.62, 0.20, 0.376), Vector3.BACK, 0.14, 4.0],
	["tub", Vector3(-0.28, 0.32, 0.376), Vector3.BACK, 0.12, -7.0],
	["tub", Vector3(0.06, 0.18, 0.376), Vector3.BACK, 0.15, 6.0],
	["tub", Vector3(0.42, 0.30, 0.376), Vector3.BACK, 0.13, -3.0],
	# 浴槽の底の排水口のそば
	["tub", Vector3(0.45, 0.102, 0.14), UP, 0.10, 18.0],
	["tub", Vector3(0.66, 0.102, -0.14), UP, 0.09, -25.0],
	# 洗面台のくぼみの底、右の壁の低い所
	["sink", Vector3(0.61, 0.762, 0.22), UP, 0.07, 10.0],
	["sink", Vector3(0.78, 0.762, 0.20), UP, 0.07, -14.0],
	["room", Vector3(0.896, 0.52, 0.05), Vector3.LEFT, 0.10, 5.0],
	["room", Vector3(0.896, 0.38, 0.20), Vector3.LEFT, 0.09, -9.0],
	# 左の壁の低い所（便器のまわり）
	["room", Vector3(-0.896, 0.35, -0.15), Vector3.RIGHT, 0.10, 8.0],
	["room", Vector3(-0.896, 0.60, 0.50), Vector3.RIGHT, 0.11, -6.0],
	["room", Vector3(-0.896, 0.22, 0.90), Vector3.RIGHT, 0.10, 15.0],
	# 玄関ホールの床
	["apartment", Vector3(0.35, 0.001, 1.62), UP, 0.12, 22.0],
	["apartment", Vector3(-0.10, 0.001, 2.00), UP, 0.11, -30.0],
	# 廊下の排水の溝（西の腰壁の足元）
	["corridor", Vector3(-2.4, 0.0125, 0.4), UP, 0.13, 10.0],
	["corridor", Vector3(-2.4, 0.0125, 1.7), UP, 0.12, -15.0],
	["corridor", Vector3(-2.4, 0.0125, 3.0), UP, 0.13, 25.0],
	["corridor", Vector3(-2.4, 0.0125, 4.3), UP, 0.12, -5.0],
	["corridor", Vector3(-2.4, 0.0125, 5.6), UP, 0.13, 40.0],
	# 1 階の玄関ホールの床（入口のローカル座標）
	["entrance", Vector3(0.35, 0.022, -2.4), UP, 0.13, 12.0],
	["entrance", Vector3(-0.35, 0.022, -4.4), UP, 0.12, -22.0],
	["entrance", Vector3(0.4, 0.022, -6.4), UP, 0.13, 30.0],
	["entrance", Vector3(-0.3, 0.022, -8.1), UP, 0.12, -10.0],
	# 路地（1 階の地面。x, z。y は GROUND_Y）
	["alley", Vector3(-3.3, 0.0, -3.2), UP, 0.14, 20.0],
	["alley", Vector3(-0.9, 0.0, -4.0), UP, 0.13, -12.0],
	["alley", Vector3(1.5, 0.0, -3.4), UP, 0.14, 33.0],
	["alley", Vector3(4.0, 0.0, -2.7), UP, 0.13, -28.0],
	["alley", Vector3(6.3, 0.0, -3.6), UP, 0.14, 8.0],
	# ベランダの床
	["exterior", Vector3(1.7, 0.002, -1.95), UP, 0.10, 14.0],
	["exterior", Vector3(2.95, 0.002, -1.95), UP, 0.10, -18.0],
	["exterior", Vector3(3.3, 0.002, -1.45), UP, 0.09, 40.0],
	# 机の下
	["apartment", Vector3(1.3, 0.002, -0.15), UP, 0.12, 5.0],
	["apartment", Vector3(2.1, 0.002, 0.45), UP, 0.12, -35.0],
]


static func paste(room: Node3D) -> void:
	var holders := {
		"room": room, "tub": room.bathtub, "sink": room.sink, "apartment": room.apartment,
		"corridor": room.corridor, "entrance": room.get_node("Entrance"), "exterior": room.exterior,
	}
	var ExteriorScript := preload("res://scripts/exterior.gd")
	var n := mini(SPOTS.size(), FigureArt.STICKERS.size())
	for i in n:
		var sp: Array = SPOTS[i]
		var key: String = sp[0]
		var host: Node3D = room.exterior if key == "alley" else holders[key]
		var pos: Vector3 = sp[1]
		if key == "alley":
			pos.y = ExteriorScript.GROUND_Y
		FigureArt.sticker(host, int(FigureArt.STICKERS[i]), float(sp[3]), pos, sp[2], float(sp[4]))
