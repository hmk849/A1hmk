extends Control
## 训练核心：6 种模式、两种输入方式（直接点击 / 准星拖动+开火键）

signal finished(result: Dictionary)
signal exit_requested

const DU = preload("res://scripts/draw_util.gd")

var mode_idx := 0
var mode_id := ""
var mode_data := {}

var vp := Vector2(1080, 1920)
var top := 24.0
var side := 40.0
var field := Rect2()
var fire_pos := Vector2.ZERO
var fire_r := 105.0
var pause_pos := Vector2.ZERO
var resume_rect := Rect2()
var quit_rect := Rect2()

var duration := 30.0
var size_mul := 1.0
var sens := 1.0
var input_mode := 0
var cross_style := 0
var tcol := Color.WHITE
var ccol := Color.WHITE
var accent := Color.WHITE
var bg_dark := Color("0d1428")

var state := "countdown"   # countdown / running / paused / done
var countdown := 3.0
var last_count := 4
var time_left := 0.0
var elapsed := 0.0

var targets: Array = []
var particles: Array = []
var floaters: Array = []

var score := 0
var hits := 0
var shots := 0
var combo := 0
var best_combo := 0
var missed_targets := 0
var reactions: Array = []

var crosshair := Vector2.ZERO
var aim_idx := -1
var fire_idx := -1
var last_aim := Vector2.ZERO
var pressing := false
var aim_pos := Vector2.ZERO

var track_time := 0.0
var track_total := 0.0
var on_target := false

var spawn_timer := 0.0
var reflex_wait := 0.0
var last_target_pos := Vector2.ZERO
var flash := 0.0

var rng := RandomNumberGenerator.new()
var font: Font
var players := {}


func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	mode_data = Store.MODES[mode_idx]
	mode_id = mode_data["id"]
	accent = mode_data["color"]

	var s: Dictionary = Store.settings
	duration = float(Store.gi("duration"))
	size_mul = Store.gf("size")
	sens = Store.gf("sens")
	input_mode = Store.gi("input_mode")
	cross_style = Store.gi("cross_style")
	tcol = Store.TARGET_COLORS[Store.gi("target_color")]
	ccol = Store.CROSS_COLORS[Store.gi("cross_color")]

	vp = get_viewport_rect().size
	top = Store.top_pad()
	side = Store.side_pad()
	var fy := top + 135.0
	var right_reserve := 330.0 if input_mode == 1 else 0.0
	field = Rect2(side, fy, vp.x - side * 2.0 - right_reserve, vp.y - fy - 36.0)
	fire_pos = Vector2(vp.x - side - 165.0, vp.y - 190.0)
	pause_pos = Vector2(vp.x - side - 46.0, top + 50.0)
	resume_rect = Rect2(vp.x / 2.0 - 260.0, vp.y / 2.0 - 40.0, 520.0, 120.0)
	quit_rect = Rect2(vp.x / 2.0 - 260.0, vp.y / 2.0 + 110.0, 520.0, 120.0)
	crosshair = field.get_center()
	aim_pos = crosshair
	last_target_pos = field.get_center()

	for n in ["hit", "miss", "tick", "go"]:
		var p := AudioStreamPlayer.new()
		p.stream = Store.sounds[n]
		add_child(p)
		players[n] = p


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == "running":
			_toggle_pause()


# ───────────────────────── 流程 ─────────────────────────

func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 3.0)
	if state != "paused":
		_update_fx(delta)
	if state == "countdown":
		countdown -= delta
		var c := int(ceil(countdown))
		if c != last_count and c > 0:
			last_count = c
			_play("tick")
		if countdown <= 0.0:
			state = "running"
			time_left = duration
			_init_mode()
			_play("go")
	elif state == "running":
		time_left -= delta
		elapsed += delta
		if input_mode == 1:
			aim_pos = crosshair
		_update_mode(delta)
		if time_left <= 0.0:
			_finish()
	queue_redraw()


func _toggle_pause() -> void:
	if state == "running":
		state = "paused"
		pressing = false
		aim_idx = -1
		fire_idx = -1
	elif state == "paused":
		state = "running"


func _finish() -> void:
	state = "done"
	var acc := 0.0
	var avg_ms := 0.0
	var res := {}
	if mode_id == "tracking":
		acc = track_time / maxf(track_total, 0.001) * 100.0
		res["track_time"] = track_time
	else:
		acc = (float(hits) / float(shots) * 100.0) if shots > 0 else 0.0
		if mode_id == "reflex" and reactions.size() > 0:
			var sum := 0.0
			for r in reactions:
				sum += float(r)
			avg_ms = sum / reactions.size() * 1000.0
		elif hits > 0:
			avg_ms = elapsed / hits * 1000.0
	res["mode_idx"] = mode_idx
	res["mode_id"] = mode_id
	res["score"] = score
	res["hits"] = hits
	res["shots"] = shots
	res["acc"] = acc
	res["best_combo"] = best_combo
	res["avg_ms"] = avg_ms
	res["missed"] = missed_targets
	res["duration"] = int(duration)
	finished.emit(res)


func _play(n: String) -> void:
	if not Store.settings["sound"]:
		return
	var p: AudioStreamPlayer = players.get(n)
	if p:
		p.play()


# ───────────────────────── 模式逻辑 ─────────────────────────

func _mk(p: Vector2, r: float, life: float) -> Dictionary:
	return {"pos": p, "r": r, "t": 0.0, "life": life, "cell": -1, "vel": Vector2.ZERO, "turn": 0.0}


func _rand_in_field(r: float) -> Vector2:
	return Vector2(
		rng.randf_range(field.position.x + r, field.end.x - r),
		rng.randf_range(field.position.y + r, field.end.y - r))


func _init_mode() -> void:
	targets.clear()
	match mode_id:
		"gridshot":
			for i in 3:
				_spawn_grid()
		"sixshot":
			for i in 6:
				_spawn_random(60.0 * size_mul, 0.0)
		"microflick":
			_spawn_micro()
		"decay":
			spawn_timer = 0.2
		"reflex":
			reflex_wait = rng.randf_range(0.6, 1.5)
		"tracking":
			var t := _mk(field.get_center(), 100.0 * size_mul, 0.0)
			t["vel"] = Vector2.from_angle(rng.randf() * TAU) * 300.0
			t["turn"] = 1.0
			targets.append(t)


func _grid_center(cell: int) -> Vector2:
	var col := cell % 4
	var row := cell / 4
	var cw := field.size.x / 4.0
	var ch := field.size.y / 3.0
	return field.position + Vector2(cw * (col + 0.5), ch * (row + 0.5))


func _spawn_grid() -> void:
	var used := []
	for t in targets:
		used.append(t["cell"])
	var free := []
	for c in 12:
		if not used.has(c):
			free.append(c)
	if free.is_empty():
		return
	var c: int = free[rng.randi_range(0, free.size() - 1)]
	var t := _mk(_grid_center(c), 85.0 * size_mul, 0.0)
	t["cell"] = c
	targets.append(t)


func _spawn_random(r: float, life: float) -> void:
	var p := _rand_in_field(r)
	for attempt in 30:
		var ok := true
		for t in targets:
			if p.distance_to(t["pos"]) < r + float(t["r"]) + 24.0:
				ok = false
				break
		if ok:
			break
		p = _rand_in_field(r)
	targets.append(_mk(p, r, life))


func _spawn_micro() -> void:
	var r := 38.0 * size_mul
	var inner := field.grow(-r)
	var p := field.get_center()
	for i in 25:
		var cand := last_target_pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(120.0, 300.0)
		if inner.has_point(cand):
			p = cand
			break
	targets.append(_mk(p, r, 0.0))


func _cur_r(t: Dictionary) -> float:
	var r: float = t["r"]
	if mode_id == "decay":
		return r * (1.0 - 0.8 * clampf(t["t"] / t["life"], 0.0, 1.0))
	if mode_id == "reflex":
		return r * minf(1.0, 0.4 + float(t["t"]) * 8.0)
	return r


func _update_mode(dt: float) -> void:
	for t in targets:
		t["t"] += dt
	match mode_id:
		"decay":
			spawn_timer -= dt
			if spawn_timer <= 0.0 and targets.size() < 5:
				_spawn_random(100.0 * size_mul, 1.7)
				spawn_timer = 0.6
			var i := targets.size() - 1
			while i >= 0:
				if targets[i]["t"] >= targets[i]["life"]:
					targets.remove_at(i)
					combo = 0
					missed_targets += 1
				i -= 1
		"reflex":
			if targets.is_empty():
				reflex_wait -= dt
				if reflex_wait <= 0.0:
					var r := 90.0 * size_mul
					targets.append(_mk(_rand_in_field(r), r, 1.2))
			elif targets[0]["t"] >= targets[0]["life"]:
				targets.clear()
				combo = 0
				missed_targets += 1
				flash = 0.6
				reflex_wait = rng.randf_range(0.6, 1.8)
		"tracking":
			_move_tracker(dt)
			track_total += dt
			var on := false
			if pressing and not targets.is_empty():
				var tp: Vector2 = targets[0]["pos"]
				on = aim_pos.distance_to(tp) <= float(targets[0]["r"])
			on_target = on
			if on:
				track_time += dt
				score = int(track_time * 100.0)
				if rng.randf() < dt * 18.0:
					_burst(aim_pos, tcol, 3)


func _move_tracker(dt: float) -> void:
	if targets.is_empty():
		return
	var t: Dictionary = targets[0]
	t["turn"] = float(t["turn"]) - dt
	var v: Vector2 = t["vel"]
	if t["turn"] <= 0.0:
		v = Vector2.from_angle(v.angle() + rng.randf_range(-1.4, 1.4)) * rng.randf_range(240.0, 440.0)
		t["turn"] = rng.randf_range(0.6, 1.4)
	var p: Vector2 = t["pos"]
	p += v * dt
	var f := field.grow(-float(t["r"]))
	if p.x < f.position.x:
		p.x = f.position.x
		v.x = absf(v.x)
	elif p.x > f.end.x:
		p.x = f.end.x
		v.x = -absf(v.x)
	if p.y < f.position.y:
		p.y = f.position.y
		v.y = absf(v.y)
	elif p.y > f.end.y:
		p.y = f.end.y
		v.y = -absf(v.y)
	t["pos"] = p
	t["vel"] = v


# ───────────────────────── 输入 ─────────────────────────

func _input(e) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index)
	elif e is InputEventScreenDrag:
		_drag(e.index, e.position)


func _down(idx: int, p: Vector2) -> void:
	if state == "done" or state == "countdown":
		return
	if p.distance_to(pause_pos) < 70.0 and state == "running":
		_toggle_pause()
		return
	if state == "paused":
		if resume_rect.has_point(p):
			_toggle_pause()
		elif quit_rect.has_point(p):
			state = "done"
			exit_requested.emit()
		return
	if input_mode == 1:
		if p.distance_to(fire_pos) < fire_r * 1.3:
			fire_idx = idx
			pressing = true
			if mode_id != "tracking":
				_shoot(crosshair)
			return
		if aim_idx == -1:
			aim_idx = idx
			last_aim = p
	else:
		aim_idx = idx
		aim_pos = p
		pressing = true
		if mode_id != "tracking":
			_shoot(p)


func _up(idx: int) -> void:
	if idx == fire_idx:
		fire_idx = -1
		pressing = false
	if idx == aim_idx:
		aim_idx = -1
		if input_mode == 0:
			pressing = false


func _drag(idx: int, p: Vector2) -> void:
	if state != "running" or idx != aim_idx:
		return
	if input_mode == 1:
		var d := (p - last_aim) * sens * 1.6
		last_aim = p
		crosshair = (crosshair + d).clamp(field.position, field.end)
	else:
		aim_pos = p


func _shoot(p: Vector2) -> void:
	shots += 1
	var fudge := 14.0 if input_mode == 0 else 4.0
	var hit_i := -1
	var best_d := 1e9
	for i in targets.size():
		var d := p.distance_to(targets[i]["pos"])
		if d <= _cur_r(targets[i]) + fudge and d < best_d:
			best_d = d
			hit_i = i
	if hit_i >= 0:
		_on_hit(hit_i)
	else:
		_on_miss(p)


func _on_hit(i: int) -> void:
	var t: Dictionary = targets[i]
	var pos: Vector2 = t["pos"]
	hits += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	var pts := 100
	match mode_id:
		"decay":
			pts = 60 + int(140.0 * (1.0 - float(t["t"]) / float(t["life"])))
		"reflex":
			reactions.append(float(t["t"]))
			pts = int(clampf(1000.0 - float(t["t"]) * 1000.0, 100.0, 900.0))
		"microflick":
			pts = 120
		"sixshot":
			pts = 110
	pts += mini(combo, 10) * 5
	score += pts
	_burst(pos, tcol, 14)
	floaters.append({"pos": pos, "text": "+%d" % pts, "t": 0.0, "ring": false})
	floaters.append({"pos": pos, "text": "", "t": 0.0, "ring": true})
	targets.remove_at(i)
	_play("hit")
	if Store.settings["vibrate"]:
		Input.vibrate_handheld(15)
	match mode_id:
		"gridshot":
			_spawn_grid()
		"sixshot":
			_spawn_random(60.0 * size_mul, 0.0)
		"microflick":
			last_target_pos = pos
			_spawn_micro()
		"reflex":
			reflex_wait = rng.randf_range(0.6, 1.8)


func _on_miss(p: Vector2) -> void:
	combo = 0
	flash = 1.0
	floaters.append({"pos": p, "text": "", "t": 0.0, "ring": true})
	_play("miss")


func _burst(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		particles.append({
			"pos": p,
			"vel": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(160.0, 520.0),
			"t": 0.0, "life": rng.randf_range(0.3, 0.6),
			"col": col, "r": rng.randf_range(4.0, 9.0)})


func _update_fx(dt: float) -> void:
	var i := particles.size() - 1
	while i >= 0:
		var p: Dictionary = particles[i]
		p["t"] += dt
		p["pos"] += p["vel"] * dt
		p["vel"] *= 0.94
		if p["t"] >= p["life"]:
			particles.remove_at(i)
		i -= 1
	i = floaters.size() - 1
	while i >= 0:
		var f: Dictionary = floaters[i]
		f["t"] += dt
		if not f["ring"]:
			f["pos"] += Vector2(0, -90.0 * dt)
		if f["t"] >= 0.7:
			floaters.remove_at(i)
		i -= 1


# ───────────────────────── 绘制 ─────────────────────────

func _txt(text: String, center: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := 900.0
	var x := center.x - w / 2.0
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		x = center.x
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = center.x - w
	draw_string(font, Vector2(x, center.y + fs * 0.35), text, align, w, fs, col)


func _btn_draw(rect: Rect2, text: String, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(36)
	draw_style_box(sb, rect)
	_txt(text, rect.get_center(), 44, Color.WHITE)


func _draw() -> void:
	var s := vp
	# 背景渐变
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color("111a38"), Color("111a38"), Color("070b16"), Color("070b16")]))

	_draw_field()

	# 靶子
	for t in targets:
		var r := _cur_r(t)
		var pos: Vector2 = t["pos"]
		DU.target(self, pos, r, tcol, bg_dark)
		if mode_id == "tracking" and on_target:
			draw_arc(pos, r + 16.0, 0.0, TAU, 48, Color.WHITE, 6.0, true)
		elif mode_id == "decay":
			var frac := 1.0 - clampf(t["t"] / t["life"], 0.0, 1.0)
			draw_arc(pos, r * 1.2 + 6.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color(1, 1, 1, 0.7), 5.0, true)

	# 粒子与特效
	for p in particles:
		var a := 1.0 - float(p["t"]) / float(p["life"])
		var pc: Color = p["col"]
		draw_circle(p["pos"], float(p["r"]) * a, Color(pc, a))
	for f in floaters:
		var a2 := 1.0 - float(f["t"]) / 0.7
		var fp: Vector2 = f["pos"]
		if f["ring"]:
			draw_arc(fp, 24.0 + float(f["t"]) * 160.0, 0.0, TAU, 32, Color(1, 1, 1, a2 * 0.6), 4.0, true)
		else:
			_txt(f["text"], fp, 46, Color(1, 1, 1, a2))

	# 准星 / 触点
	if state == "running" or state == "paused":
		if input_mode == 1:
			DU.crosshair(self, crosshair, cross_style, ccol)
		elif pressing:
			DU.crosshair(self, aim_pos, cross_style, ccol, 0.8)

	if input_mode == 1:
		_draw_fire()

	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.2, 0.2, flash * 0.10))

	_draw_hud()

	if state == "countdown":
		_draw_countdown()
	elif state == "paused":
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.7))
		_txt("已暂停", Vector2(s.x / 2.0, s.y / 2.0 - 180.0), 80, Color.WHITE)
		_btn_draw(resume_rect, "继续", accent.darkened(0.25))
		_btn_draw(quit_rect, "退出训练", Color("334155"))


func _draw_field() -> void:
	draw_rect(field, Color(1, 1, 1, 0.025))
	var x := field.position.x + 120.0
	while x < field.end.x:
		draw_line(Vector2(x, field.position.y), Vector2(x, field.end.y), Color(1, 1, 1, 0.035), 2.0)
		x += 120.0
	var y := field.position.y + 120.0
	while y < field.end.y:
		draw_line(Vector2(field.position.x, y), Vector2(field.end.x, y), Color(1, 1, 1, 0.035), 2.0)
		y += 120.0
	draw_rect(field, Color(1, 1, 1, 0.10), false, 2.0)
	var L := 46.0
	var c := Color(accent, 0.9)
	var a := field.position
	var b := field.end
	for corner in [[a, 1.0, 1.0], [Vector2(b.x, a.y), -1.0, 1.0], [Vector2(a.x, b.y), 1.0, -1.0], [b, -1.0, -1.0]]:
		var o: Vector2 = corner[0]
		var sx: float = corner[1]
		var sy: float = corner[2]
		draw_line(o, o + Vector2(L * sx, 0), c, 6.0)
		draw_line(o, o + Vector2(0, L * sy), c, 6.0)
	if mode_id == "gridshot" and state == "running":
		for cell in 12:
			draw_circle(_grid_center(cell), 5.0, Color(1, 1, 1, 0.12))


func _draw_fire() -> void:
	var pressed := fire_idx != -1
	draw_circle(fire_pos, fire_r * 1.3, Color(accent, 0.10))
	draw_circle(fire_pos, fire_r, Color(accent, 0.55 if pressed else 0.25))
	draw_arc(fire_pos, fire_r, 0.0, TAU, 48, accent, 6.0, true)
	_txt("按住" if mode_id == "tracking" else "开火", fire_pos, 42, Color.WHITE)
	_txt("拖动屏幕移动准星", Vector2(fire_pos.x, fire_pos.y - 190.0), 28, Color(1, 1, 1, 0.4))


func _draw_hud() -> void:
	var s := vp
	var dim := Color(1, 1, 1, 0.5)
	# 左：得分
	_txt("SCORE", Vector2(side, top + 14.0), 22, dim, HORIZONTAL_ALIGNMENT_LEFT)
	_txt("%d" % score, Vector2(side, top + 62.0), 56, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	# 中：倒计时 + 连击
	var tl := duration if state == "countdown" else maxf(time_left, 0.0)
	_txt("%.1f" % tl, Vector2(s.x / 2.0, top + 46.0), 72, Color.WHITE)
	if combo >= 3:
		_txt("x%d 连击" % combo, Vector2(s.x / 2.0 + 170.0, top + 50.0), 30, accent, HORIZONTAL_ALIGNMENT_LEFT)
	# 右：准确率 + 暂停键
	var acc := 0.0
	if mode_id == "tracking":
		acc = track_time / maxf(track_total, 0.001) * 100.0
	elif shots > 0:
		acc = float(hits) / float(shots) * 100.0
	_txt("ACC", Vector2(s.x - side - 130.0, top + 14.0), 22, dim, HORIZONTAL_ALIGNMENT_RIGHT)
	_txt("%d%%" % int(acc), Vector2(s.x - side - 130.0, top + 62.0), 50, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_circle(pause_pos, 40.0, Color(1, 1, 1, 0.10))
	draw_rect(Rect2(pause_pos + Vector2(-13, -16), Vector2(8, 32)), Color.WHITE)
	draw_rect(Rect2(pause_pos + Vector2(5, -16), Vector2(8, 32)), Color.WHITE)
	# 进度条
	var bar := Rect2(side, top + 108.0, s.x - side * 2.0, 8.0)
	draw_rect(bar, Color(1, 1, 1, 0.10))
	var frac := 1.0 if state == "countdown" else clampf(time_left / duration, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), accent)


func _draw_countdown() -> void:
	var s := vp
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.45))
	_txt(mode_data["name"], Vector2(s.x / 2.0, s.y / 2.0 - 330.0), 84, Color.WHITE)
	_txt(mode_data["en"], Vector2(s.x / 2.0, s.y / 2.0 - 250.0), 36, accent)
	draw_multiline_string(font, Vector2(90.0, s.y / 2.0 - 160.0), mode_data["desc"],
		HORIZONTAL_ALIGNMENT_CENTER, s.x - 180.0, 34, -1, Color(1, 1, 1, 0.65))
	_txt("%d" % maxi(1, int(ceil(countdown))), Vector2(s.x / 2.0, s.y / 2.0 + 120.0), 240, accent)
