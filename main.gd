extends Control
## 界面路由：主菜单 / 选择训练 / 设置 / 统计 / 结果

const GameScript = preload("res://scripts/game.gd")
const IconScript = preload("res://scripts/mode_icon.gd")
const ChartScript = preload("res://scripts/chart.gd")

var screen: Control = null
var game = null
var current := ""
var logo_t := 0.0
var stats_mode := 0


func _ready() -> void:
	show_screen("menu")


func _process(delta: float) -> void:
	logo_t += delta
	if current == "menu":
		queue_redraw()


# ───────────────────────── 背景 ─────────────────────────

func _draw() -> void:
	var s := size
	var c1 := Color("131c3d")
	var c2 := Color("070b16")
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([c1, c1, c2, c2]))
	var x := 0.0
	while x < s.x:
		draw_line(Vector2(x, 0), Vector2(x, s.y), Color(1, 1, 1, 0.025), 2.0)
		x += 90.0
	var y := 0.0
	while y < s.y:
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(1, 1, 1, 0.025), 2.0)
		y += 90.0
	draw_arc(Vector2(s.x, 0), 360.0, 0.0, TAU, 64, Color(0.13, 0.83, 0.93, 0.07), 6.0, true)
	draw_arc(Vector2(0, s.y), 300.0, 0.0, TAU, 64, Color(0.96, 0.45, 0.71, 0.07), 6.0, true)
	if current == "menu":
		var mg := Store.side_pad() + 60.0
		var cw := s.x - mg * 2.0
		_draw_logo(Vector2(mg + (cw - 80.0) / 4.0, 300.0))


func _draw_logo(c: Vector2) -> void:
	var cy := Color("22d3ee")
	var pk := Color("f472b6")
	draw_circle(c, 210.0, Color(cy, 0.06))
	for k in 4:
		var a0 := logo_t * 0.8 + k * PI / 2.0
		draw_arc(c, 190.0, a0, a0 + 0.9, 24, cy, 8.0, true)
	_logo_target(c, 120.0 + sin(logo_t * 2.0) * 4.0, cy)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var dir: Vector2 = d
		draw_line(c + dir * 150.0, c + dir * 250.0, pk, 8.0, true)
	var ang := logo_t * 1.6
	draw_circle(c + Vector2.from_angle(ang) * 190.0, 11.0, pk)


func _logo_target(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col)
	draw_circle(c, r * 0.74, Color("0d1428"))
	draw_circle(c, r * 0.52, col)
	draw_circle(c, r * 0.24, Color.WHITE)


# ───────────────────────── 通用控件 ─────────────────────────

func _sb(col: Color, radius := 28, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 24
	s.content_margin_right = 24
	return s


func _btn(text: String, cb: Callable, col := Color("1e293b"), h := 120, fs := 42) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _sb(col))
	b.add_theme_stylebox_override("hover", _sb(col.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", _sb(col.darkened(0.2)))
	b.pressed.connect(cb)
	return b


func _lbl(text: String, fs: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _margin() -> MarginContainer:
	var m := MarginContainer.new()
	screen.add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sd := int(Store.side_pad()) + 60
	m.add_theme_constant_override("margin_left", sd)
	m.add_theme_constant_override("margin_right", sd)
	m.add_theme_constant_override("margin_top", int(Store.top_pad()) + 10)
	m.add_theme_constant_override("margin_bottom", 36)
	return m


func _page(title: String, back := true) -> VBoxContainer:
	var m := _margin()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	m.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	if back:
		var bb := _btn("‹", func(): show_screen("menu"), Color("1e293b"), 84, 54)
		bb.custom_minimum_size = Vector2(84, 84)
		head.add_child(bb)
	else:
		var sp0 := Control.new()
		sp0.custom_minimum_size = Vector2(84, 84)
		head.add_child(sp0)
	var l := _lbl(title, 48)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(84, 84)
	head.add_child(sp)
	return v


func _btn_x(text: String, cb: Callable, col: Color, h: int, fs: int) -> Button:
	var b := _btn(text, cb, col, h, fs)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _panel(col := Color("141c33")) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(col, 28))
	return p


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


# ───────────────────────── 路由 ─────────────────────────

func show_screen(name_: String, arg = null) -> void:
	if screen:
		screen.queue_free()
	screen = Control.new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current = name_
	match name_:
		"menu":
			_build_menu()
		"modes":
			_build_modes()
		"settings":
			_build_settings()
		"stats":
			_build_stats()
		"result":
			_build_result(arg)
	queue_redraw()


func start_game(idx: int) -> void:
	if screen:
		screen.queue_free()
		screen = null
	current = "game"
	game = GameScript.new()
	game.mode_idx = idx
	add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.finished.connect(_on_finished)
	game.exit_requested.connect(_on_exit)


func _on_finished(res: Dictionary) -> void:
	if game:
		game.queue_free()
		game = null
	res["new_record"] = Store.add_result(res)
	stats_mode = int(res["mode_idx"])
	show_screen("result", res)


func _on_exit() -> void:
	if game:
		game.queue_free()
		game = null
	show_screen("modes")


# ───────────────────────── 主菜单 ─────────────────────────

func _build_menu() -> void:
	var m := _margin()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 80)
	m.add_child(h)
	# 左：标题（Logo 由背景绘制）
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	h.add_child(left)
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 520)
	left.add_child(top)
	left.add_child(_lbl("瞄准工坊", 110))
	left.add_child(_lbl("AIMFORGE  ·  瞄准训练", 34, Color("22d3ee")))
	var n := Store.history.size()
	left.add_child(_lbl("已完成 %d 次训练" % n if n > 0 else "准备好开始你的第一次训练了吗？", 26, Color(1, 1, 1, 0.45)))
	# 右：按钮
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 24)
	h.add_child(right)
	right.add_child(_btn("开始训练", func(): show_screen("modes"), Color("0891b2"), 170, 58))
	right.add_child(_btn("训练统计", func(): show_screen("stats"), Color("1e293b"), 130, 44))
	right.add_child(_btn("设置", func(): show_screen("settings"), Color("1e293b"), 130, 44))


# ───────────────────────── 选择训练 ─────────────────────────

func _build_modes() -> void:
	var v := _page("选择训练")
	var inp := "准星拖动" if Store.gi("input_mode") == 1 else "直接点击"
	v.add_child(_lbl("%d 秒  ·  %s  ·  目标大小 %d%%" % [Store.gi("duration"), inp, int(Store.gf("size") * 100.0)], 26, Color(1, 1, 1, 0.5)))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 24)
	v.add_child(g)
	for i in Store.MODES.size():
		g.add_child(_mode_card(i))


func _mode_card(i: int) -> Button:
	var md: Dictionary = Store.MODES[i]
	var col: Color = md["color"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 220)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed"]:
		var base := Color("141c33")
		if st == "hover":
			base = Color("1a2442")
		elif st == "pressed":
			base = Color("0f1730")
		b.add_theme_stylebox_override(st, _sb(base, 32, Color(col, 0.55), 3))
	b.pressed.connect(start_game.bind(i))

	var ic = IconScript.new()
	ic.kind = i
	ic.col = col
	ic.position = Vector2(26, 40)
	ic.size = Vector2(140, 140)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)

	var name_l := _lbl(md["name"], 44, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.position = Vector2(190, 20)
	name_l.size = Vector2(600, 56)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)

	var desc := _lbl(md["desc"], 24, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
	desc.position = Vector2(190, 80)
	desc.size = Vector2(600, 70)
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(desc)

	var bs := Store.get_best(md["id"])
	var best_txt := "尚无记录"
	if not bs.is_empty():
		best_txt = "最高分 %d  ·  准确率 %d%%" % [int(bs["score"]), int(float(bs["acc"]))]
	var bl := _lbl(best_txt, 24, col, HORIZONTAL_ALIGNMENT_LEFT)
	bl.position = Vector2(190, 160)
	bl.size = Vector2(600, 40)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bl)
	return b


# ───────────────────────── 设置 ─────────────────────────

func _set_opt(k: String, val) -> void:
	Store.settings[k] = val
	Store.save_data()
	show_screen("settings")


func _row(label: String, ctrl: Control) -> PanelContainer:
	var p := _panel()
	p.custom_minimum_size = Vector2(0, 96)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var l := _lbl(label, 32, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(ctrl)
	return p


func _cycle(text: String, cb: Callable) -> Button:
	var b := _btn(text, cb, Color("0e7490"), 72, 32)
	b.custom_minimum_size = Vector2(300, 72)
	return b


func _stepper(text: String, dec: Callable, inc: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var a := _btn("−", dec, Color("334155"), 72, 40)
	a.custom_minimum_size = Vector2(84, 72)
	var l := _lbl(text, 32)
	l.custom_minimum_size = Vector2(120, 72)
	var b := _btn("+", inc, Color("334155"), 72, 40)
	b.custom_minimum_size = Vector2(84, 72)
	h.add_child(a)
	h.add_child(l)
	h.add_child(b)
	return h


func _swatch(col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 72)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, _sb(col, 36, Color(1, 1, 1, 0.6), 3))
	b.pressed.connect(cb)
	return b


func _build_settings() -> void:
	var v := _page("设置")
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 14)
	v.add_child(g)
	var im := Store.gi("input_mode")
	g.add_child(_row("输入方式", _cycle("准星拖动" if im == 1 else "直接点击",
		func(): _set_opt("input_mode", 1 - im))))
	g.add_child(_row("准星灵敏度", _stepper("%.1f" % Store.gf("sens"),
		func(): _set_opt("sens", snappedf(clampf(Store.gf("sens") - 0.1, 0.3, 3.0), 0.1)),
		func(): _set_opt("sens", snappedf(clampf(Store.gf("sens") + 0.1, 0.3, 3.0), 0.1)))))
	g.add_child(_row("目标大小", _stepper("%d%%" % int(Store.gf("size") * 100.0),
		func(): _set_opt("size", snappedf(clampf(Store.gf("size") - 0.1, 0.6, 1.6), 0.1)),
		func(): _set_opt("size", snappedf(clampf(Store.gf("size") + 0.1, 0.6, 1.6), 0.1)))))
	var durs := [30, 60, 90]
	var di := durs.find(Store.gi("duration"))
	g.add_child(_row("训练时长", _cycle("%d 秒" % Store.gi("duration"),
		func(): _set_opt("duration", durs[(di + 1) % 3]))))
	var cs := Store.gi("cross_style")
	g.add_child(_row("准星样式", _cycle(Store.CROSS_NAMES[cs],
		func(): _set_opt("cross_style", (cs + 1) % Store.CROSS_NAMES.size()))))
	var cc := Store.gi("cross_color")
	g.add_child(_row("准星颜色", _swatch(Store.CROSS_COLORS[cc],
		func(): _set_opt("cross_color", (cc + 1) % Store.CROSS_COLORS.size()))))
	var tc := Store.gi("target_color")
	g.add_child(_row("目标颜色", _swatch(Store.TARGET_COLORS[tc],
		func(): _set_opt("target_color", (tc + 1) % Store.TARGET_COLORS.size()))))
	var snd: bool = Store.settings["sound"]
	g.add_child(_row("音效", _cycle("开" if snd else "关", func(): _set_opt("sound", not snd))))
	var vib: bool = Store.settings["vibrate"]
	g.add_child(_row("击中震动", _cycle("开" if vib else "关", func(): _set_opt("vibrate", not vib))))
	v.add_child(_spacer())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 24)
	v.add_child(bottom)
	var pv = IconScript.new()
	pv.kind = -1
	pv.custom_minimum_size = Vector2(0, 150)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(pv)
	var rb := _btn("清除所有成绩数据", _reset_all, Color("7f1d1d"), 150, 32)
	rb.custom_minimum_size = Vector2(480, 150)
	bottom.add_child(rb)


# ───────────────────────── 统计 ─────────────────────────

func _reset_all() -> void:
	Store.reset_data()
	show_screen("settings")


func _next_stats_mode() -> void:
	stats_mode = (stats_mode + 1) % Store.MODES.size()
	show_screen("stats")


func _fmt_ts(ts: float) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(int(ts) + bias * 60)
	return "%02d-%02d %02d:%02d" % [d["month"], d["day"], d["hour"], d["minute"]]


func _stat_box(title: String, value: String, col := Color.WHITE) -> PanelContainer:
	var p := _panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	p.add_child(vb)
	vb.add_child(_lbl(title, 26, Color(1, 1, 1, 0.5)))
	vb.add_child(_lbl(value, 52, col))
	return p


func _build_stats() -> void:
	var v := _page("训练统计")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 40)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 16)
	h.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	h.add_child(right)

	var n := Store.history.size()
	var hits := 0
	var shots := 0
	for hh in Store.history:
		hits += int(hh.get("hits", 0))
		shots += int(hh.get("shots", 0))
	var acc := int(float(hits) / float(shots) * 100.0) if shots > 0 else 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(_stat_box("训练次数", "%d" % n))
	row.add_child(_stat_box("总命中", "%d" % hits))
	row.add_child(_stat_box("总体准确率", "%d%%" % acc, Color("22d3ee")))
	left.add_child(row)

	var md: Dictionary = Store.MODES[stats_mode]
	var mcol: Color = md["color"]
	left.add_child(_btn("趋势 · %s  ⟳" % md["name"], _next_stats_mode, mcol.darkened(0.45), 84, 32))
	var vals := []
	for hh in Store.history:
		if hh["mode_id"] == md["id"]:
			vals.append(hh["score"])
	if vals.size() > 20:
		vals = vals.slice(vals.size() - 20)
	var ch = ChartScript.new()
	ch.values = vals
	ch.col = md["color"]
	ch.custom_minimum_size = Vector2(0, 360)
	ch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(ch)

	right.add_child(_lbl("最近记录", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	right.add_child(grid)
	if n == 0:
		right.add_child(_lbl("还没有训练记录", 28, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_LEFT))
	for i in range(n - 1, maxi(n - 9, -1), -1):
		var rec: Dictionary = Store.history[i]
		var mdi := Store.mode_by_id(rec["mode_id"])
		var nm := _lbl(mdi.get("name", "?"), 28, mdi.get("color", Color.WHITE), HORIZONTAL_ALIGNMENT_LEFT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(nm)
		grid.add_child(_lbl("%d" % int(rec["score"]), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(_lbl("%d%%" % int(float(rec["acc"])), 28, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(_lbl(_fmt_ts(float(rec["ts"])), 24, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_RIGHT))


# ───────────────────────── 结果 ─────────────────────────

func _build_result(res: Dictionary) -> void:
	var md: Dictionary = Store.MODES[int(res["mode_idx"])]
	var col: Color = md["color"]
	var v := _page("训练完成", false)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 60)
	v.add_child(h)

	# 左：得分
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(left)
	left.add_child(_lbl(md["name"] + "  " + md["en"], 38, col))
	left.add_child(_lbl("%d" % int(res["score"]), 160))
	if res.get("new_record", false):
		left.add_child(_lbl("★ 新纪录 ★", 48, Color("fbbf24")))
	else:
		left.add_child(_lbl("得分", 30, Color(1, 1, 1, 0.45)))

	# 右：数据
	var items := []
	if res["mode_id"] == "tracking":
		items = [
			["咬合率", "%d%%" % int(float(res["acc"]))],
			["咬合时间", "%.1f 秒" % float(res["track_time"])],
			["训练时长", "%d 秒" % int(res["duration"])],
			["得分/秒", "%.1f" % (float(res["score"]) / maxf(1.0, float(res["duration"])))],
		]
	else:
		var avg_label := "平均反应" if res["mode_id"] == "reflex" else "平均击杀用时"
		var avg_txt := "%d ms" % int(float(res["avg_ms"])) if float(res["avg_ms"]) > 0.0 else "-"
		items = [
			["准确率", "%d%%" % int(float(res["acc"]))],
			["命中 / 射击", "%d / %d" % [int(res["hits"]), int(res["shots"])]],
			["最高连击", "%d" % int(res["best_combo"])],
			[avg_label, avg_txt],
		]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	h.add_child(grid)
	for it in items:
		grid.add_child(_stat_box(it[0], it[1], col))

	v.add_child(_spacer())
	var idx := int(res["mode_idx"])
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 20)
	v.add_child(bh)
	bh.add_child(_btn_x("再来一次", func(): start_game(idx), Color("0891b2"), 120, 44))
	bh.add_child(_btn_x("选择其它模式", func(): show_screen("modes"), Color("1e293b"), 120, 40))
	bh.add_child(_btn_x("主菜单", func(): show_screen("menu"), Color("1e293b"), 120, 40))


