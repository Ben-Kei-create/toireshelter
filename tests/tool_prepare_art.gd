extends SceneTree
## 置物の絵（4 枚のシート 4×3 = 48 点）を 1 点ずつ切り出し、お酒の絵（6 点）を余白なしに切り詰めて、assets に保存する道具。
## 実行: Godot --headless --path . --script res://tests/tool_prepare_art.gd -- <シート4枚のフォルダ> <お酒6枚のフォルダ>
## シートは 1448×1086、4 列×3 行。透明な背景の連結成分を数え、重心のいる枡に割り振ってから切り出す（隣の置物のはみ出しが混ざらない）。
## 保存先：assets/textures/figures/fig_01〜48.png、assets/textures/liquor/liquor_01〜06.png

const OUT_FIG := "res://assets/textures/figures/"
const OUT_LIQ := "res://assets/textures/liquor/"
const ALPHA_MIN := 24


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("使い方: -- <シートのフォルダ> <お酒のフォルダ>")
		quit(1)
		return
	var sheets := _list_pngs(args[0])
	var liq := _list_pngs(args[1])
	print("sheets=", sheets.size(), " liquor=", liq.size())
	var n := 0
	for sp in sheets:
		n += _split_sheet(sp, n)
	for i in liq.size():
		_trim_save(liq[i], OUT_LIQ + "liquor_%02d.png" % (i + 1), 640)
	print("DONE figures=", n)
	quit()


func _list_pngs(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			out.append(dir.path_join(f))
	out.sort()
	return out


func _trim_save(path: String, out: String, max_h: int) -> void:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	var r := img.get_used_rect()
	var c := img.get_region(r)
	if c.get_height() > max_h:
		c.resize(int(float(c.get_width()) * max_h / c.get_height()), max_h, Image.INTERPOLATE_LANCZOS)
	c.save_png(ProjectSettings.globalize_path(out))


func _split_sheet(path: String, start: int) -> int:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var cw := w / 4
	var ch := h / 3
	# 半分の解像度で連結成分を数える
	var hw := w / 2
	var hh := h / 2
	var mask := PackedByteArray()
	mask.resize(hw * hh)
	for y in hh:
		for x in hw:
			var a := img.get_pixel(x * 2, y * 2).a8
			mask[y * hw + x] = 1 if a >= ALPHA_MIN else 0
	var label := PackedInt32Array()
	label.resize(hw * hh)
	var comps := []   # {area, sx, sy}
	var next := 1
	for y0 in hh:
		for x0 in hw:
			var i0 := y0 * hw + x0
			if mask[i0] == 0 or label[i0] != 0:
				continue
			var stack := [i0]
			label[i0] = next
			var area := 0
			var sx := 0
			var sy := 0
			while not stack.is_empty():
				var i: int = stack.pop_back()
				var x := i % hw
				var y := i / hw
				area += 1
				sx += x
				sy += y
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= hw or ny >= hh:
						continue
					var ni := ny * hw + nx
					if mask[ni] != 0 and label[ni] == 0:
						label[ni] = next
						stack.append(ni)
			comps.append({"id": next, "area": area, "cx": float(sx) / area * 2.0, "cy": float(sy) / area * 2.0})
			next += 1
	# 小さな成分は捨てる（かすれ・粒）。残りを枡に割り振る
	var cell_of := {}
	for c in comps:
		if int(c.area) < 60:
			continue
		var cell := clampi(int(c.cx) / cw, 0, 3) + 4 * clampi(int(c.cy) / ch, 0, 2)
		cell_of[int(c.id)] = cell
	var saved := 0
	for cell in 12:
		var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var any := false
		for y in h:
			for x in w:
				var l := label[(y / 2) * hw + (x / 2)]
				if l != 0 and cell_of.get(l, -1) == cell:
					out.set_pixel(x, y, img.get_pixel(x, y))
					any = true
		if not any:
			print("  空の枡 ", path.get_file(), " ", cell)
			continue
		var r := out.get_used_rect()
		var c := out.get_region(r)
		c.save_png(ProjectSettings.globalize_path(OUT_FIG + "fig_%02d.png" % (start + cell + 1)))
		saved += 1
	print(path.get_file(), " → ", saved, " 点（成分 ", comps.size(), "）")
	return 12
