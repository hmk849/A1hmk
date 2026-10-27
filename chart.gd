extends Control
## 简易折线图：最近得分趋势

var values: Array = []
var col := Color("22d3ee")


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("111a30")
	sb.set_corner_radius_all(28)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	var n := values.size()
	if n < 2:
		draw_string(font, Vector2(0, size.y / 2.0 + 10.0), "完成 2 次以上训练后显示趋势",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(1, 1, 1, 0.4))
		return
	var lo := 1e18
	var hi := -1e18
	for v in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	if hi - lo < 1.0:
		hi = lo + 1.0
	var pad := 40.0
	var w := size.x - pad * 2.0
	var h := size.y - pad * 2.0
	for g in 4:
		var gy := pad + h * g / 3.0
		draw_line(Vector2(pad, gy), Vector2(size.x - pad, gy), Color(1, 1, 1, 0.06), 2.0)
	var pts := PackedVector2Array()
	for i in n:
		var x := pad + w * float(i) / float(n - 1)
		var y := pad + h * (1.0 - (float(values[i]) - lo) / (hi - lo))
		pts.append(Vector2(x, y))
	draw_polyline(pts, col, 5.0, true)
	for p in pts:
		draw_circle(p, 8.0, col)
		draw_circle(p, 3.5, Color("111a30"))
	draw_string(font, Vector2(pad, 28), "%d" % int(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
	draw_string(font, Vector2(pad, size.y - 8), "%d" % int(lo), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
