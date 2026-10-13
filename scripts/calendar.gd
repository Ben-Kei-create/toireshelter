extends Node3D
## 壁掛けカレンダー。システム日付の月のカレンダー（日付は数字、月は英字の略称。フォントに左右されない）で、今日に赤い丸がつく。
## 原点は壁に掛けた面の中心。文字は +z を向く（置くときに回して、部屋側へ向ける）。apartment.gd が南の壁の、寝床と冷蔵庫のあいだに掛ける。
## 調べると今日の日付と曜日が出る（main.gd。date_text()）。

const MeshKit := preload("res://scripts/mesh_kit.gd")

const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
const WEEKDAYS_JA := ["日", "月", "火", "水", "木", "金", "土"]
const W := 0.27
const H := 0.36

var year := 0
var month := 0
var today := 0
var day_labels: Array = []   # 日付の Label3D（1日から）
var ring: MeshInstance3D


func _ready() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	year = now.year
	month = now.month
	today = now.day
	MeshKit.auto_round = false
	var paper := MeshKit.mat("calendar_paper", Color(0.97, 0.96, 0.92), 0.8)
	var red := MeshKit.mat("calendar_red", Color(0.75, 0.2, 0.2), 0.7)
	MeshKit.box(self, Vector3(W, H, 0.004), Vector3(0, 0, 0.002), paper, "Paper")
	# 月の絵（ユーザー作成・生成 AI 使用。月の文字入り）。紙の上に貼る
	var pic_h := W * 0.4
	MeshKit.image_quad(self, MeshKit.prop_tex("calendar_%02d" % month), Vector2(W, pic_h), Vector3(0, H * 0.5 - pic_h * 0.5, 0.0045), Vector3.BACK, "MonthPicture", false, 0.8)
	MeshKit.cylinder(self, 0.004, 0.012, Vector3(0, H * 0.5 + 0.005, 0.004), MeshKit.mat("calendar_nail", Color(0.6, 0.6, 0.62), 0.3, 0.8), "Nail").rotation.x = PI * 0.5
	_label(str(year), Vector3(0.1, H * 0.5 - pic_h - 0.012, 0.0052), 0.0004, 40, Color(0.35, 0.3, 0.28))
	var cell := 0.0345
	var x0 := -cell * 3.0
	var y0 := H * 0.5 - pic_h - 0.03
	for c in 7:
		_label("SMTWTFS"[c], Vector3(x0 + c * cell, y0, 0.0052), 0.0004, 40, Color(0.7, 0.15, 0.15) if c == 0 else Color(0.15, 0.15, 0.2))
	var first := _weekday_of(year, month, 1)
	var days := _days_in_month(year, month)
	for d in range(1, days + 1):
		var idx := first + d - 1
		var col := idx % 7
		var row := idx / 7
		var pos := Vector3(x0 + col * cell, y0 - 0.032 - row * 0.04, 0.0052)
		var l := _label(str(d), pos, 0.00045, 40, Color(0.7, 0.15, 0.15) if col == 0 else Color(0.12, 0.12, 0.16))
		day_labels.append(l)
		if d == today:
			var disc := MeshKit.cylinder(self, 0.0165, 0.001, Vector3(pos.x, pos.y, 0.0049), red, "TodayRing")
			disc.rotation.x = PI * 0.5
			ring = disc
			l.modulate = Color.WHITE
	var area := MeshKit.interact_area(self, "CalendarArea", "calendar")
	MeshKit.shape_box(area, Vector3(W + 0.02, H + 0.02, 0.06), Vector3(0, 0, 0.02))
	area.set_meta("interact_range", 2.4)
	MeshKit.auto_round = true


func _label(text: String, pos: Vector3, px: float, size: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.font_size = size
	l.modulate = col
	l.outline_size = 0
	l.double_sided = false
	l.position = pos
	l.shaded = false
	add_child(l)
	return l


## 0 が日曜。日付の曜日（Zeller ではなく、エポック秒から求める）。
static func _weekday_of(y: int, m: int, d: int) -> int:
	var t := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12, "minute": 0, "second": 0})
	return int(Time.get_datetime_dict_from_unix_time(int(t)).weekday)


static func _days_in_month(y: int, m: int) -> int:
	var ny := y + (1 if m == 12 else 0)
	var nm := 1 if m == 12 else m + 1
	var a := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": 1, "hour": 12, "minute": 0, "second": 0})
	var b := Time.get_unix_time_from_datetime_dict({"year": ny, "month": nm, "day": 1, "hour": 12, "minute": 0, "second": 0})
	return int(round((b - a) / 86400.0))


func date_text() -> String:
	return "%d年%d月%d日（%s）" % [year, month, today, WEEKDAYS_JA[_weekday_of(year, month, today)]]
