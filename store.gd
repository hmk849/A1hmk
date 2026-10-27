extends Node
## 全局数据：设置、成绩存档、程序生成的音效

const SAVE_PATH := "user://aimforge_save.json"

var MODES := [
	{"id": "gridshot", "name": "网格射击", "en": "GRIDSHOT", "color": Color("22d3ee"),
	 "desc": "4×3 网格同时出现 3 个目标，考验连续点射的速度与精度"},
	{"id": "sixshot", "name": "六连射", "en": "SIXSHOT", "color": Color("f472b6"),
	 "desc": "6 个小目标同时刷新，训练视野切换与精准度"},
	{"id": "microflick", "name": "微闪", "en": "MICROFLICK", "color": Color("fbbf24"),
	 "desc": "极小目标在附近闪现，练习短距离精细微调"},
	{"id": "decay", "name": "泡泡消除", "en": "DECAY", "color": Color("34d399"),
	 "desc": "目标会逐渐缩小直至消失，越早命中得分越高"},
	{"id": "reflex", "name": "反应力", "en": "REFLEX", "color": Color("f87171"),
	 "desc": "目标随机突然出现，测试你的最快反应速度"},
	{"id": "tracking", "name": "追踪", "en": "TRACKING", "color": Color("a78bfa"),
	 "desc": "按住并咬住移动中的目标，训练持续追踪能力"},
]

var TARGET_COLORS := [Color("22d3ee"), Color("f472b6"), Color("fbbf24"), Color("34d399"), Color("f87171"), Color("a78bfa")]
var CROSS_COLORS := [Color("34d399"), Color("ffffff"), Color("f87171"), Color("fbbf24"), Color("22d3ee"), Color("f472b6")]
var CROSS_NAMES := ["十字", "圆点", "圆环", "圆环十字"]

var settings := {
	"input_mode": 0,   # 0 直接点击  1 准星拖动
	"sens": 1.0,
	"size": 1.0,
	"duration": 30,
	"cross_style": 0,
	"cross_color": 0,
	"target_color": 0,
	"sound": true,
	"vibrate": true,
}
var best := {}
var history: Array = []
var sounds := {}


func _ready() -> void:
	load_data()
	sounds = {
		"hit": make_tone(880.0, 0.09, 0.45, 600.0),
		"miss": make_tone(150.0, 0.14, 0.5, -60.0),
		"tick": make_tone(660.0, 0.07, 0.35),
		"go": make_tone(990.0, 0.25, 0.4, 300.0),
	}


func gi(k: String) -> int:
	return int(settings[k])


func gf(k: String) -> float:
	return float(settings[k])


func mode_by_id(id: String) -> Dictionary:
	for m in MODES:
		if m["id"] == id:
			return m
	return {}


func best_key(id: String) -> String:
	return "%s_%d_%d" % [id, gi("input_mode"), gi("duration")]


func get_best(id: String) -> Dictionary:
	return best.get(best_key(id), {})


func _ratio() -> float:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 1.0
	return 1080.0 / float(win.y)


## 状态栏安全区（以 1080 高设计坐标计）
func top_pad() -> float:
	var safe := DisplayServer.get_display_safe_area()
	return maxf(24.0, float(safe.position.y) * _ratio())


## 横屏时左右刘海/圆角安全区
func side_pad() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var left := float(safe.position.x)
	var right := float(win.x - (safe.position.x + safe.size.x))
	return maxf(40.0, maxf(left, maxf(right, 0.0)) * _ratio())


func add_result(r: Dictionary) -> bool:
	var id: String = r["mode_id"]
	var key := best_key(id)
	var rec := false
	var prev = best.get(key, null)
	var sc := int(r["score"])
	if sc > 0 and (prev == null or sc > int(prev["score"])):
		rec = true
		best[key] = {"score": sc, "acc": float(r["acc"])}
	history.append({
		"mode_id": id, "score": sc, "acc": float(r["acc"]),
		"hits": int(r.get("hits", 0)), "shots": int(r.get("shots", 0)),
		"ts": Time.get_unix_time_from_system(),
	})
	if history.size() > 300:
		history = history.slice(history.size() - 300)
	save_data()
	return rec


func reset_data() -> void:
	best = {}
	history = []
	save_data()


func save_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"settings": settings, "best": best, "history": history}))


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	var s = d.get("settings", {})
	for k in s:
		if settings.has(k):
			settings[k] = s[k]
	best = d.get("best", {})
	history = d.get("history", [])


func make_tone(freq: float, dur: float, vol := 0.5, slide := 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		var env := pow(1.0 - float(i) / n, 2.0)
		phase += TAU * (freq + slide * t) / rate
		var s := int(clampf(sin(phase) * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
