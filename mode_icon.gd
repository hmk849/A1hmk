extends Control
## 模式图标（kind 0-5）与设置页预览（kind -1）

const DU = preload("res://scripts/draw_util.gd")

var kind := 0
var col := Color.WHITE


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0f172a") if kind < 0 else Color(col, 0.14)
	sb.set_corner_radius_all(28 if kind < 0 else 32)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var c := size / 2.0
	var bg := Color("17213a")
	match kind:
		-1:
			var tcol: Color = Store.TARGET_COLORS[Store.gi("target_color")]
			var ccol: Color = Store.CROSS_COLORS[Store.gi("cross_color")]
			var r := 36.0 * Store.gf("size")
			DU.target(self, Vector2(size.x * 0.28, c.y), r, tcol, Color("0f172a"))
			DU.target(self, Vector2(size.x * 0.72, c.y), r, tcol, Color("0f172a"))
			DU.crosshair(self, Vector2(size.x * 0.72, c.y), Store.gi("cross_style"), ccol, 1.1)
		0:
			for i in 3:
				for j in 3:
					var p := c + Vector2(i - 1, j - 1) * 40.0
					var hot := (i == 0 and j == 0) or (i == 2 and j == 1) or (i == 1 and j == 2)
					draw_circle(p, 15.0 if hot else 8.0, col if hot else Color(col, 0.35))
		1:
			var pts := [Vector2(-38, -30), Vector2(10, -44), Vector2(42, -10), Vector2(-14, 2), Vector2(30, 40), Vector2(-40, 38)]
			for p in pts:
				var q: Vector2 = p
				draw_circle(c + q, 13.0, col)
				draw_circle(c + q, 5.0, Color.WHITE)
		2:
			draw_arc(c, 54.0, 0.0, TAU, 48, Color(col, 0.35), 4.0, true)
			for k in 3:
				draw_circle(c + Vector2(-34 + k * 16, 26 - k * 14), 4.0 + k * 1.5, Color(col, 0.3 + 0.2 * k))
			DU.target(self, c + Vector2(26, -22), 20.0, col, bg)
		3:
			draw_circle(c, 54.0, Color(col, 0.18))
			draw_circle(c, 38.0, Color(col, 0.35))
			draw_circle(c, 20.0, col)
			draw_arc(c, 60.0, -PI / 2.0, PI * 0.9, 40, Color.WHITE, 5.0, true)
		4:
			var bolt := PackedVector2Array([Vector2(10, -58), Vector2(-26, 6), Vector2(-3, 6), Vector2(-12, 58), Vector2(28, -10), Vector2(3, -10)])
			for i in bolt.size():
				bolt[i] += c
			draw_colored_polygon(bolt, col)
		5:
			var line := PackedVector2Array()
			for k in 21:
				line.append(c + Vector2(-56.0 + k * 5.6, 30.0 - k * 2.0 + sin(k * 0.5) * 16.0))
			draw_polyline(line, Color(col, 0.5), 4.0, true)
			DU.target(self, line[20], 18.0, col, bg)
