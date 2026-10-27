extends RefCounted
## 共用绘制：靶子与准星（全部用代码绘制，无需外部美术资源）


static func target(ci: CanvasItem, pos: Vector2, r: float, col: Color, bg: Color, glow := true) -> void:
	if glow:
		ci.draw_circle(pos, r * 1.35, Color(col, 0.10))
		ci.draw_circle(pos, r * 1.15, Color(col, 0.16))
	ci.draw_circle(pos, r, col)
	ci.draw_circle(pos, r * 0.74, bg)
	ci.draw_circle(pos, r * 0.52, col)
	ci.draw_circle(pos, r * 0.24, Color.WHITE)


static func crosshair(ci: CanvasItem, pos: Vector2, style: int, col: Color, s := 1.0) -> void:
	var dirs := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	for p in 2:
		var c: Color = Color(0, 0, 0, 0.7) if p == 0 else col
		var w: float = (8.0 if p == 0 else 4.0) * s
		match style:
			0:
				for d in dirs:
					var dir: Vector2 = d
					ci.draw_line(pos + dir * 12.0 * s, pos + dir * 40.0 * s, c, w)
			1:
				ci.draw_circle(pos, (13.0 if p == 0 else 8.0) * s, c)
			2:
				ci.draw_arc(pos, 30.0 * s, 0.0, TAU, 48, c, w, true)
				if p == 1:
					ci.draw_circle(pos, 4.0 * s, c)
			3:
				ci.draw_arc(pos, 26.0 * s, 0.0, TAU, 48, c, w, true)
				for d in dirs:
					var dir2: Vector2 = d
					ci.draw_line(pos + dir2 * 26.0 * s, pos + dir2 * 46.0 * s, c, w)
