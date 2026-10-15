extends RefCounted
## 自室の床（フローリング）と天井（板張り）の木目の絵を、コードで描く。雑でよい：板の継ぎ目と、細い木目の線を入れるだけ。
## floor_texture() … 1.2m × 0.6m（板 4 枚。1 枚の幅 0.15m）。ceiling_texture() … 1.2m × 0.6m（板の継ぎ目 0.3m おき）。

static var _floor: ImageTexture
static var _ceil: ImageTexture


static func floor_texture() -> ImageTexture:
	if _floor == null:
		var w := 512
		var h := 256
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		var base := Color(0.56, 0.43, 0.31)
		var plank_h := h / 4
		for p in 4:
			var tone := rng.randf_range(-0.035, 0.035)
			var col := Color(base.r + tone, base.g + tone, base.b + tone * 0.8)
			for y in range(p * plank_h, (p + 1) * plank_h):
				for x in w:
					img.set_pixel(x, y, col)
			# 木目：横に流れる細い線（ゆるくうねる）
			for k in 7:
				var yy := float(p * plank_h) + rng.randf_range(4.0, plank_h - 4.0)
				var amp := rng.randf_range(0.6, 2.2)
				var fr := rng.randf_range(0.01, 0.03)
				var ph := rng.randf_range(0.0, TAU)
				var dark := rng.randf_range(0.05, 0.12)
				var x0 := rng.randi_range(0, w / 3)
				var x1 := rng.randi_range(w * 2 / 3, w - 1)
				for x in range(x0, x1):
					var y := int(yy + sin(float(x) * fr + ph) * amp)
					if y >= p * plank_h + 1 and y < (p + 1) * plank_h - 1:
						var c: Color = img.get_pixel(x, y)
						img.set_pixel(x, y, Color(c.r - dark, c.g - dark, c.b - dark * 0.9))
			# 継ぎ目：板どうし（横線）と、板の端（縦線。板ごとにずらす）
			for x in w:
				img.set_pixel(x, p * plank_h, Color(0.3, 0.22, 0.15))
			var jx := rng.randi_range(80, w - 80)
			for y in range(p * plank_h, (p + 1) * plank_h):
				img.set_pixel(jx, y, Color(0.3, 0.22, 0.15))
		_floor = ImageTexture.create_from_image(img)
	return _floor


static func ceiling_texture() -> ImageTexture:
	if _ceil == null:
		var w := 512
		var h := 256
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 43
		var base := Color(0.93, 0.92, 0.89)
		img.fill(base)
		var board_h := h / 2   # 0.3m の板
		for b in 2:
			for k in 5:
				var yy := float(b * board_h) + rng.randf_range(5.0, board_h - 5.0)
				var amp := rng.randf_range(0.5, 1.8)
				var fr := rng.randf_range(0.01, 0.03)
				var ph := rng.randf_range(0.0, TAU)
				for x in range(rng.randi_range(0, w / 4), rng.randi_range(w * 3 / 4, w - 1)):
					var y := int(yy + sin(float(x) * fr + ph) * amp)
					if y > b * board_h and y < (b + 1) * board_h - 1:
						var c: Color = img.get_pixel(x, y)
						img.set_pixel(x, y, Color(c.r - 0.07, c.g - 0.07, c.b - 0.06))
			for x in w:
				img.set_pixel(x, b * board_h, Color(0.6, 0.58, 0.53))
		_ceil = ImageTexture.create_from_image(img)
	return _ceil
