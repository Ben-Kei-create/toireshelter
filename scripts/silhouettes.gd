extends RefCounted
## 犬・猿・キジの影絵（墨の黒い絵）。栞・掛け軸・家宝のスロットに使う。画像はコードで描く（楕円・三角・四角の組み合わせ）。
## texture(kind) … kind："dog"／"monkey"／"pheasant"。256×256、透明な背景に、濃い墨色。
## scroll_blotches() … 掛け軸の、バラバラの墨の模様（ぴったりの高さで見ると影絵に揃う、までの「揃っていない」見え方）。

const SIZE := 256

static var _cache := {}


static func texture(kind: String, ink := Color(0.07, 0.06, 0.06, 1.0)) -> ImageTexture:
	var key := "%s_%s" % [kind, ink.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	match kind:
		"dog":
			_dog(img, ink)
		"monkey":
			_monkey(img, ink)
		"pheasant":
			_pheasant(img, ink)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


# ---------------------------------------------------------------- 描画の道具（座標は 0〜1）

static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	var s := float(SIZE)
	var c := cos(rot)
	var sn := sin(rot)
	var x0 := int(maxf(0.0, (cx - maxf(rx, ry) - 0.02) * s))
	var x1 := int(minf(s - 1.0, (cx + maxf(rx, ry) + 0.02) * s))
	var y0 := int(maxf(0.0, (cy - maxf(rx, ry) - 0.02) * s))
	var y1 := int(minf(s - 1.0, (cy + maxf(rx, ry) + 0.02) * s))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) / s - cx
			var dy := float(y) / s - cy
			var u := dx * c + dy * sn
			var v := -dx * sn + dy * c
			if (u * u) / (rx * rx) + (v * v) / (ry * ry) <= 1.0:
				img.set_pixel(x, y, col)


static func _poly(img: Image, pts: Array, col: Color) -> void:
	var s := float(SIZE)
	var ymin := SIZE
	var ymax := 0
	for p in pts:
		ymin = mini(ymin, int(p.y * s))
		ymax = maxi(ymax, int(p.y * s))
	for y in range(maxi(ymin, 0), mini(ymax, SIZE - 1) + 1):
		var xs := []
		var n := pts.size()
		for i in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			var ya := a.y * s
			var yb := b.y * s
			if (ya <= float(y) and yb > float(y)) or (yb <= float(y) and ya > float(y)):
				xs.append(lerpf(a.x, b.x, (float(y) - ya) / (yb - ya)) * s)
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			for x in range(maxi(int(xs[k]), 0), mini(int(xs[k + 1]), SIZE - 1) + 1):
				img.set_pixel(x, y, col)


static func _line(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := b - a
	var len := d.length()
	var nrm := Vector2(-d.y, d.x).normalized() * w * 0.5
	_poly(img, [a + nrm, b + nrm, b - nrm, a - nrm], col)


# ---------------------------------------------------------------- 3 匹

static func _dog(img: Image, c: Color) -> void:
	_ellipse(img, 0.45, 0.62, 0.26, 0.17, c)                 # 胴
	_ellipse(img, 0.70, 0.40, 0.13, 0.12, c)                 # 頭
	_ellipse(img, 0.82, 0.45, 0.10, 0.06, c)                 # 鼻づら
	_poly(img, [Vector2(0.62, 0.34), Vector2(0.66, 0.14), Vector2(0.74, 0.30)], c)   # 耳
	_line(img, Vector2(0.22, 0.58), Vector2(0.10, 0.32), 0.06, c)   # しっぽ
	for x in [0.30, 0.38, 0.55, 0.62]:
		_line(img, Vector2(x, 0.70), Vector2(x, 0.92), 0.07, c)   # 脚
	_ellipse(img, 0.74, 0.37, 0.018, 0.018, Color(0, 0, 0, 0))


static func _monkey(img: Image, c: Color) -> void:
	_ellipse(img, 0.45, 0.62, 0.18, 0.22, c)                 # 胴
	_ellipse(img, 0.45, 0.30, 0.14, 0.14, c)                 # 頭
	_ellipse(img, 0.30, 0.28, 0.06, 0.06, c)                 # 耳
	_ellipse(img, 0.60, 0.28, 0.06, 0.06, c)
	_line(img, Vector2(0.30, 0.52), Vector2(0.14, 0.72), 0.07, c)   # 腕
	_line(img, Vector2(0.60, 0.52), Vector2(0.76, 0.66), 0.07, c)
	_line(img, Vector2(0.38, 0.80), Vector2(0.34, 0.95), 0.08, c)   # 脚
	_line(img, Vector2(0.52, 0.80), Vector2(0.58, 0.95), 0.08, c)
	# 長いしっぽ（くるんと巻く）
	var pts := []
	for i in 14:
		var t := float(i) / 13.0
		pts.append(Vector2(0.62 + 0.20 * sin(t * 3.4), 0.82 - 0.50 * t))
	for i in pts.size() - 1:
		_line(img, pts[i], pts[i + 1], 0.045, c)


static func _pheasant(img: Image, c: Color) -> void:
	_ellipse(img, 0.40, 0.55, 0.22, 0.14, c, -0.3)           # 胴
	_ellipse(img, 0.62, 0.34, 0.08, 0.08, c)                 # 頭
	_poly(img, [Vector2(0.69, 0.32), Vector2(0.80, 0.36), Vector2(0.69, 0.40)], c)   # くちばし
	_poly(img, [Vector2(0.58, 0.27), Vector2(0.54, 0.14), Vector2(0.64, 0.26)], c)   # とさか
	_line(img, Vector2(0.55, 0.42), Vector2(0.50, 0.52), 0.07, c)   # 首
	# 長い尾羽
	_poly(img, [Vector2(0.24, 0.52), Vector2(0.02, 0.80), Vector2(0.06, 0.86), Vector2(0.32, 0.64)], c)
	_line(img, Vector2(0.42, 0.66), Vector2(0.40, 0.88), 0.03, c)   # 脚
	_line(img, Vector2(0.50, 0.64), Vector2(0.52, 0.88), 0.03, c)
	_line(img, Vector2(0.36, 0.90), Vector2(0.46, 0.90), 0.025, c)
	_line(img, Vector2(0.48, 0.90), Vector2(0.58, 0.90), 0.025, c)


## 掛け軸の、バラバラの墨の模様（揃っていないときの見え方）。256×512 の縦長。
static func scroll_blotches() -> ImageTexture:
	if _cache.has("scroll"):
		return _cache["scroll"]
	var img := Image.create(SIZE, SIZE * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 142
	for i in 26:
		var cx := rng.randf_range(0.12, 0.88)
		var cy := rng.randf_range(0.05, 0.95)
		var rx := rng.randf_range(0.02, 0.09)
		var ry := rng.randf_range(0.01, 0.05)
		var shade := rng.randf_range(0.05, 0.25)
		var layer := Image.create(SIZE, SIZE * 2, false, Image.FORMAT_RGBA8)
		_blot(img, cx, cy, rx, ry, rng.randf_range(0, PI), Color(shade, shade * 0.95, shade * 0.9, rng.randf_range(0.5, 0.9)))
	var t := ImageTexture.create_from_image(img)
	_cache["scroll"] = t
	return t


static func _blot(img: Image, cx: float, cy: float, rx: float, ry: float, rot: float, col: Color) -> void:
	var w := float(img.get_width())
	var h := float(img.get_height())
	var c := cos(rot)
	var s := sin(rot)
	for y in range(maxi(0, int((cy - 0.12) * h)), mini(img.get_height(), int((cy + 0.12) * h))):
		for x in range(maxi(0, int((cx - 0.12) * w)), mini(img.get_width(), int((cx + 0.12) * w))):
			var dx := float(x) / w - cx
			var dy := float(y) / h - cy
			var u := dx * c + dy * s
			var v := -dx * s + dy * c
			if (u * u) / (rx * rx) + (v * v) / (ry * ry) <= 1.0:
				img.set_pixel(x, y, col)
