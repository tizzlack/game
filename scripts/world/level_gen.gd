# Erzeugt einen Abschnitt aus zufälligen Bausteinen. Liefert nur Daten; game.gd baut daraus Körper und Grafik.
extends RefCounted

const BASE_Y := 520.0
const MIN_Y := BASE_Y - 560.0
const MAX_Y := BASE_Y + 150.0
const BOTTOM := BASE_Y + 1500.0
const KILL_Y := BASE_Y + 520.0

var rng := RandomNumberGenerator.new()
var d := 0.0
var out: Dictionary
var cur := PackedVector2Array()
var x := 0.0
var y := BASE_Y
var enemy_mult := 1.0
var signs := false  # kleine Lernschilder an Movement-Stellen (nur erste Welt)

func generate(seed_value: int, diff: float, length: float, boss: bool, tutorial: bool, enemy_count: float = 1.0) -> Dictionary:
	rng.seed = seed_value
	d = diff
	signs = diff < 1.0
	enemy_mult = enemy_count
	out = {"ground": [], "blocks": [], "ledges": [], "spawns": [], "coins": [], "checkpoints": [], "hints": [],
		"decor": [], "pads": [], "goal": Vector2.ZERO, "length": 0.0, "boss": boss, "boss_pos": Vector2.ZERO, "start": Vector2(80, BASE_Y - 40),
		"bottom": BOTTOM, "kill_y": KILL_Y, "arena": Rect2()}
	cur = PackedVector2Array()
	x = -420.0
	y = BASE_Y
	_pt(x, y)
	out["blocks"].append({"rect": Rect2(-480, BASE_Y - 1200, 60, 1200 + 1500), "kind": "wall"})
	if boss:
		_boss_arena()
	else:
		_level(length, tutorial)
	return out

# Versus-Arena: kompaktes, abwechslungsreiches Gelände ohne Gegner, mit Spawnpunkten
func generate_versus(seed_value: int) -> Dictionary:
	rng.seed = seed_value
	d = 1.0
	enemy_mult = 0.0
	out = {"ground": [], "blocks": [], "ledges": [], "spawns": [], "coins": [], "checkpoints": [], "hints": [],
		"decor": [], "pads": [], "goal": Vector2.ZERO, "length": 0.0, "boss": false, "boss_pos": Vector2.ZERO, "start": Vector2(80, BASE_Y - 40),
		"bottom": BOTTOM, "kill_y": KILL_Y, "arena": Rect2(), "pvp_spawns": []}
	cur = PackedVector2Array()
	x = -420.0
	y = BASE_Y
	_pt(x, y)
	out["blocks"].append({"rect": Rect2(-480, BASE_Y - 1200, 60, 1200 + 1500), "kind": "wall"})
	_flat(500.0, 4.0)
	var plan := ["mountain", "platforms", "canyon", "shaft", "pad_cliff", "pillars", "tunnel", "downhill", "boxes"]
	for i in 5:
		match plan[rng.randi() % plan.size()]:
			"mountain": _chunk_mountain()
			"platforms": _chunk_platforms()
			"canyon": _chunk_canyon()
			"boxes": _chunk_boxes()
			"shaft": _chunk_shaft()
			"pad_cliff": _chunk_pad_cliff()
			"pillars": _chunk_pillars()
			"tunnel": _chunk_tunnel()
			"downhill": _chunk_downhill()
	_flat(400.0, 4.0)
	_end_piece()
	_block(Rect2(x - 20.0, y - 1200.0, 60.0, 1200.0 + 1500.0), "wall")
	out["length"] = x
	out["spawns"].clear()
	out["coins"].clear()
	var sx := 0.0
	while sx < x - 100.0:
		var gy := ground_y_at(sx)
		if gy != INF:
			out["pvp_spawns"].append(Vector2(sx, gy - 40.0))
		sx += 260.0
	return out

# --- Grundbausteine ---
func _pt(px: float, py: float) -> void:
	x = px
	y = py
	cur.append(Vector2(px, py))

func _end_piece() -> void:
	if cur.size() >= 2:
		out["ground"].append(cur)
	cur = PackedVector2Array()

func _start_piece() -> void:
	cur = PackedVector2Array()
	cur.append(Vector2(x, y))

# Raues Felsgelände: viele kurze Stücke mit Rauschen, aber nie steiler als ~44° (bleibt begehbar)
func _rough(len: float, dy: float, noise: float = 6.0) -> void:
	var sx := x
	var sy := y
	var ty := clampf(y + dy, MIN_Y, MAX_Y)
	var end_x := x + len
	while x < end_x - 1.0:
		var step := minf(rng.randf_range(16.0, 42.0), end_x - x)
		var t := clampf((x + step - sx) / maxf(len, 1.0), 0.0, 1.0)
		var want := lerpf(sy, ty, t) + rng.randf_range(-noise, noise)
		var maxd := step * 0.95
		_pt(x + step, clampf(clampf(want, y - maxd, y + maxd), MIN_Y, MAX_Y))

func _flat(len: float, bump: float = 9.0) -> void:
	_rough(len, 0.0, bump * 0.7)

func _slope(len: float, dy: float) -> void:
	_rough(len, dy, 5.0)

func _step(dy: float) -> void:
	var ny := clampf(y + dy, MIN_Y, MAX_Y)
	_pt(x + 2.0, ny)

func ground_y_at(px: float) -> float:
	for piece in out["ground"] + [cur]:
		var pts: PackedVector2Array = piece
		if pts.size() < 2 or px < pts[0].x or px > pts[pts.size() - 1].x:
			continue
		for i in range(1, pts.size()):
			if px <= pts[i].x:
				var a := pts[i - 1]
				var b := pts[i]
				var t := 0.0 if b.x - a.x < 0.01 else (px - a.x) / (b.x - a.x)
				return lerpf(a.y, b.y, t)
	return INF

func _spawn(kind: String, pos: Vector2) -> void:
	out["spawns"].append({"kind": kind, "pos": pos})

func _spawn_ground(kind: String, px: float) -> void:
	var gy := ground_y_at(px)
	if gy == INF:
		return
	_spawn(kind, Vector2(px, gy - 34.0))

func _coin_line(x0: float, x1: float, py: float, n: int) -> void:
	for i in n:
		out["coins"].append(Vector2(lerpf(x0, x1, float(i) / maxf(1, n - 1)), py))

func _coin_arc(x0: float, x1: float, py: float, h: float, n: int) -> void:
	for i in n:
		var t := float(i) / maxf(1, n - 1)
		out["coins"].append(Vector2(lerpf(x0, x1, t), py - sin(t * PI) * h))

func _ledge(r: Rect2) -> void:
	out["ledges"].append(r)

func _block(r: Rect2, kind: String) -> void:
	out["blocks"].append({"rect": r, "kind": kind})

# Anzahl Gegner pro Baustein
func _count(base: float) -> int:
	return int(round(base * rng.randf_range(0.7, 1.3) * (1.0 + d * 0.32) * enemy_mult))

func _ground_kind() -> String:
	var r := rng.randf()
	if d >= 1.0 and r < 0.16:
		return "brute"
	if r < 0.58:
		return "walker"
	return "gunner"

func _high_kind() -> String:
	var r := rng.randf()
	if d >= 1.8 and r < 0.3:
		return "sniper"
	if r < 0.55:
		return "turret"
	return "gunner"

# --- Level-Aufbau ---
func _level(length: float, tutorial: bool) -> void:
	_flat(420.0 + 420.0, 4.0)  # sicherer Start
	if tutorial:
		_tutorial()
	var cp_done := false
	var last := ""
	while x < length:
		if not cp_done and x > length * 0.5:
			cp_done = true
			_flat(160.0, 3.0)
			out["checkpoints"].append(Vector2(x, ground_y_at(x)))
			_flat(260.0, 3.0)
			continue
		var choice := _pick_chunk(last)
		last = choice
		match choice:
			"flat": _chunk_flat()
			"hill": _chunk_hill()
			"steps": _chunk_steps()
			"gap": _chunk_gap()
			"bridge": _chunk_bridge()
			"rooftops": _chunk_rooftops()
			"platforms": _chunk_platforms()
			"boxes": _chunk_boxes()
			"arena": _chunk_arena()
			"mountain": _chunk_mountain()
			"canyon": _chunk_canyon()
			"shaft": _chunk_shaft()
			"tunnel": _chunk_tunnel()
			"dash_gap": _chunk_dash_gap()
			"pad_cliff": _chunk_pad_cliff()
			"pad_gap": _chunk_pad_gap()
			"downhill": _chunk_downhill()
			"pillars": _chunk_pillars()
			"weak": _chunk_weak()
	_flat(300.0, 3.0)
	var gx := x + 120.0
	_flat(600.0, 0.0)
	out["goal"] = Vector2(gx, ground_y_at(gx))
	_flat(200.0, 0.0)
	_end_piece()
	_block(Rect2(x - 20.0, y - 1200.0, 60.0, 1200.0 + 1500.0), "wall")
	out["length"] = x

static var force_plan: Array = []  # nur für Tests: feste Baustein-Reihenfolge
var _force_i := 0

func _pick_chunk(last: String) -> String:
	if not force_plan.is_empty():
		_force_i += 1
		return force_plan[(_force_i - 1) % force_plan.size()]
	var opts := {"flat": 0.2, "hill": 0.6, "mountain": 1.1, "canyon": 0.7, "steps": 0.5, "gap": 0.4, "bridge": 0.4,
		"rooftops": 0.6, "platforms": 0.6, "boxes": 0.3, "arena": 0.4 + d * 0.15,
		"shaft": 0.9, "tunnel": 0.7, "dash_gap": 0.7, "pad_cliff": 0.8, "pad_gap": 0.6, "downhill": 0.8,
		"pillars": 0.7, "weak": 0.5}
	opts.erase(last)
	var total := 0.0
	for v in opts.values():
		total += v
	var r := rng.randf() * total
	for k in opts.keys():
		r -= opts[k]
		if r <= 0.0:
			return k
	return "flat"

func _tutorial() -> void:
	out["hints"].append({"pos": Vector2(140, BASE_Y - 150), "key": "hint_move"})
	out["hints"].append({"pos": Vector2(520, BASE_Y - 150), "key": "hint_shoot"})
	_spawn_ground("walker", x - 80.0)
	_step(-70.0)
	out["hints"].append({"pos": Vector2(x + 40, y - 150), "key": "hint_jump"})
	_flat(380.0, 4.0)
	_end_piece()
	x += 150.0
	_start_piece()
	_flat(420.0, 4.0)
	out["hints"].append({"pos": Vector2(x - 300, y - 170), "key": "hint_dash"})
	var gy := y
	_flat(700.0, 3.0)
	_ledge(Rect2(x - 560.0, gy - 125.0, 220.0, 14.0))
	_ledge(Rect2(x - 300.0, gy - 235.0, 220.0, 14.0))
	_coin_line(x - 280.0, x - 100.0, gy - 265.0, 5)
	out["hints"].append({"pos": Vector2(x - 200, gy - 330), "key": "hint_drop"})
	_spawn("gunner", Vector2(x - 190.0, gy - 270.0))

# Steiler, zerklüfteter Berg: Hänge und kleine Klippen hinauf, Plateau, steiler Abstieg
func _chunk_mountain() -> void:
	var start := x
	var start_y := y
	var up := minf(rng.randf_range(220.0, 440.0), y - MIN_Y)
	if up < 140.0:
		_chunk_canyon()
		return
	var guard := 0
	while start_y - y < up - 25.0 and guard < 20:
		guard += 1
		var left := up - (start_y - y)
		if rng.randf() < 0.3:
			_step(-minf(rng.randf_range(50.0, 95.0), left))
			_rough(rng.randf_range(40.0, 110.0), -rng.randf_range(0.0, 12.0), 4.0)
		else:
			var dyc := minf(rng.randf_range(60.0, 150.0), left)
			_rough(dyc / rng.randf_range(0.6, 0.92), -dyc, 6.0)
	var peak_a := x
	_rough(rng.randf_range(160.0, 320.0), rng.randf_range(-20.0, 20.0), 7.0)
	var peak_b := x
	var peak_mid := (peak_a + peak_b) * 0.5
	out["decor"].append({"kind": "tower", "pos": Vector2(peak_mid, ground_y_at(peak_mid))})
	_coin_arc(peak_a + 20.0, peak_b - 20.0, ground_y_at(peak_mid) - 50.0, 40.0, 6)
	if rng.randf() < 0.6 + d * 0.1:
		_spawn(_high_kind(), Vector2(peak_mid + rng.randf_range(-40.0, 40.0), ground_y_at(peak_mid) - 34.0))
	var down := clampf(up * rng.randf_range(0.6, 1.15), 0.0, MAX_Y - y)
	var target := y + down
	guard = 0
	while y < target - 25.0 and guard < 20:
		guard += 1
		var left := target - y
		if rng.randf() < 0.35:
			_step(minf(rng.randf_range(60.0, 180.0), left))
			_rough(rng.randf_range(40.0, 100.0), rng.randf_range(0.0, 12.0), 4.0)
		else:
			var dyc := minf(rng.randf_range(60.0, 150.0), left)
			_rough(dyc / rng.randf_range(0.6, 0.92), dyc, 6.0)
	_rough(rng.randf_range(120.0, 220.0), 0.0, 5.0)
	for i in _count(1.0):
		_spawn_ground(_ground_kind(), rng.randf_range(start + 80.0, x - 40.0))

# Schlucht: hinab ins Tal, Kampf am Boden, über Stufen wieder hinauf
func _chunk_canyon() -> void:
	var start := x
	var down := minf(rng.randf_range(140.0, 280.0), MAX_Y - y)
	if down < 80.0:
		_rough(rng.randf_range(300.0, 500.0), -rng.randf_range(80.0, 160.0), 6.0)
		return
	if rng.randf() < 0.5:
		_step(down * 0.6)
		_rough(down * 0.4 / 0.8, down * 0.4, 5.0)
	else:
		_rough(down / 0.85, down, 6.0)
	var floor_a := x
	_rough(rng.randf_range(300.0, 520.0), rng.randf_range(-20.0, 20.0), 6.0)
	var floor_b := x
	for i in _count(1.3):
		_spawn_ground(_ground_kind(), rng.randf_range(floor_a + 60.0, floor_b - 40.0))
	_coin_line(floor_a + 60.0, floor_a + 220.0, ground_y_at(floor_a + 140.0) - 40.0, 5)
	var climb := minf(down * rng.randf_range(0.7, 1.2), y - MIN_Y)
	var climbed := 0.0
	var guard := 0
	while climbed < climb - 20.0 and guard < 12:
		guard += 1
		var h := minf(rng.randf_range(55.0, 95.0), climb - climbed)
		_step(-h)
		climbed += h
		_rough(rng.randf_range(60.0, 140.0), -rng.randf_range(0.0, 10.0), 4.0)
	if rng.randf() < 0.5:
		_spawn("drone", Vector2((floor_a + floor_b) * 0.5, ground_y_at(floor_a) - 220.0))
	_rough(rng.randf_range(100.0, 200.0), 0.0, 5.0)

func _chunk_flat() -> void:
	var start := x
	_flat(rng.randf_range(450.0, 800.0))
	for i in _count(1.0):
		_spawn_ground(_ground_kind(), rng.randf_range(start + 100.0, x - 40.0))
	if rng.randf() < 0.5:
		_coin_line(start + 80.0, start + 260.0, ground_y_at(start + 170.0) - 40.0, 5)
	if rng.randf() < 0.55:
		var dx := rng.randf_range(start + 60.0, x - 60.0)
		out["decor"].append({"kind": "tower", "pos": Vector2(dx, ground_y_at(dx))})

func _chunk_hill() -> void:
	var start := x
	var h := rng.randf_range(80.0, 190.0)
	_slope(rng.randf_range(220.0, 380.0), -h)
	var top_start := x
	_flat(rng.randf_range(160.0, 360.0), 6.0)
	var top_end := x
	_slope(rng.randf_range(220.0, 380.0), h * rng.randf_range(0.6, 1.2))
	_coin_arc(top_start, top_end, ground_y_at((top_start + top_end) * 0.5) - 40.0, 30.0, 5)
	for i in _count(1.1):
		_spawn_ground(_ground_kind(), rng.randf_range(start + 80.0, x - 40.0))
	if rng.randf() < 0.35:
		out["decor"].append({"kind": "tower", "pos": Vector2((top_start + top_end) * 0.5, ground_y_at((top_start + top_end) * 0.5))})

func _chunk_steps() -> void:
	var start := x
	var dir := -1.0 if y > MIN_Y + 150.0 and rng.randf() < 0.6 else 1.0
	for i in rng.randi_range(2, 3):
		_flat(rng.randf_range(150.0, 260.0), 4.0)
		_step(dir * rng.randf_range(50.0, 95.0))
	_flat(rng.randf_range(160.0, 260.0), 4.0)
	for i in _count(0.9):
		_spawn_ground(_ground_kind(), rng.randf_range(start + 120.0, x - 40.0))

func _chunk_gap() -> void:
	_flat(rng.randf_range(120.0, 220.0), 4.0)
	var gap_start := x
	var gap_y := y
	_end_piece()
	var w := rng.randf_range(130.0, 210.0)
	x += w
	y = clampf(y + rng.randf_range(-60.0, 40.0), MIN_Y, MAX_Y)
	_start_piece()
	_coin_arc(gap_start + 10.0, x - 10.0, minf(gap_y, y) - 50.0, 70.0, 5)
	var land := x
	_flat(rng.randf_range(260.0, 420.0))
	for i in _count(0.7):
		_spawn_ground(_ground_kind(), rng.randf_range(land + 120.0, x - 30.0))

func _chunk_bridge() -> void:
	_flat(rng.randf_range(100.0, 180.0), 4.0)
	var gy := y
	_end_piece()
	var w := rng.randf_range(420.0, 620.0)
	var n := 2 if w < 520.0 else 3
	for i in n:
		var cx := x + w * (i + 1) / (n + 1)
		var ly := gy - rng.randf_range(20.0, 90.0)
		_ledge(Rect2(cx - 60.0, ly, 120.0, 14.0))
		out["coins"].append(Vector2(cx, ly - 30.0))
		if i == n - 1 and rng.randf() < 0.5 + d * 0.1:
			_spawn("drone", Vector2(cx, ly - 160.0))
	x += w
	y = clampf(gy + rng.randf_range(-40.0, 40.0), MIN_Y, MAX_Y)
	_start_piece()
	_flat(rng.randf_range(260.0, 400.0))
	for i in _count(0.6):
		_spawn_ground(_ground_kind(), rng.randf_range(x - 200.0, x - 30.0))

func _chunk_rooftops() -> void:
	_flat(rng.randf_range(100.0, 160.0), 4.0)
	var top := y
	_end_piece()
	for i in rng.randi_range(2, 4):
		x += rng.randf_range(80.0, 160.0) if i > 0 else rng.randf_range(80.0, 130.0)
		var w := rng.randf_range(220.0, 420.0)
		top = clampf(top + rng.randf_range(-90.0, 70.0), MIN_Y, MAX_Y)
		_block(Rect2(x, top, w, BOTTOM - top), "building")
		if rng.randf() < 0.55 + d * 0.08:
			_spawn(_high_kind(), Vector2(x + w * rng.randf_range(0.4, 0.8), top - 34.0))
		if rng.randf() < 0.5:
			_coin_line(x + 40.0, x + w - 40.0, top - 40.0, 4)
		if rng.randf() < 0.3:
			out["decor"].append({"kind": "antenna", "pos": Vector2(x + w * 0.2, top)})
		x += w
	x += rng.randf_range(90.0, 150.0)
	y = clampf(top + rng.randf_range(0.0, 60.0), MIN_Y, MAX_Y)
	_start_piece()
	_flat(rng.randf_range(260.0, 400.0))

func _chunk_platforms() -> void:
	var start := x
	_flat(rng.randf_range(700.0, 1000.0), 5.0)
	var gy := ground_y_at(start + 200.0)
	var lx := start + rng.randf_range(120.0, 220.0)
	var ly := gy - rng.randf_range(110.0, 130.0)
	for i in rng.randi_range(2, 3):
		var w := rng.randf_range(150.0, 260.0)
		_ledge(Rect2(lx, ly, w, 14.0))
		if i > 0 and rng.randf() < 0.75:
			_spawn(_high_kind() if rng.randf() < 0.5 else "gunner", Vector2(lx + w * 0.5, ly - 34.0))
		else:
			_coin_line(lx + 20.0, lx + w - 20.0, ly - 30.0, 4)
		lx += w + rng.randf_range(40.0, 120.0)
		ly -= rng.randf_range(80.0, 110.0)
		ly = maxf(ly, gy - 360.0)
	for i in _count(0.6):
		_spawn_ground(_ground_kind(), rng.randf_range(start + 100.0, x - 40.0))
	if rng.randf() < 0.4 + d * 0.15:
		_spawn("drone", Vector2(x - 200.0, gy - 260.0))

func _chunk_boxes() -> void:
	var start := x
	_flat(rng.randf_range(650.0, 900.0), 5.0)
	var bx := start + rng.randf_range(100.0, 180.0)
	for i in rng.randi_range(2, 3):
		var w := rng.randf_range(110.0, 190.0)
		var gy := ground_y_at(bx + w * 0.5)
		var by := gy - rng.randf_range(130.0, 175.0)
		_block(Rect2(bx, by, w, rng.randf_range(44.0, 64.0)), "box")
		if rng.randf() < 0.6:
			_spawn(_high_kind(), Vector2(bx + w * 0.5, by - 34.0))
		else:
			_coin_line(bx + 20.0, bx + w - 20.0, by - 30.0, 3)
		bx += w + rng.randf_range(90.0, 200.0)
		if bx > x - 150.0:
			break
	for i in _count(0.7):
		_spawn_ground(_ground_kind(), rng.randf_range(start + 80.0, x - 40.0))

func _chunk_arena() -> void:
	var start := x
	_flat(rng.randf_range(900.0, 1200.0), 6.0)
	for i in _count(2.0):
		_spawn_ground(_ground_kind(), rng.randf_range(start + 200.0, x - 60.0))
	for i in int(1 + d * 0.6):
		_spawn("drone", Vector2(rng.randf_range(start + 300.0, x - 100.0), ground_y_at(start + 500.0) - rng.randf_range(200.0, 300.0)))
	var gy := ground_y_at(start + 450.0)
	_ledge(Rect2(start + 350.0, gy - 130.0, 240.0, 14.0))
	_coin_line(start + 370.0, start + 570.0, gy - 160.0, 6)

func _boss_arena() -> void:
	_flat(420.0, 0.0)
	var arena_x := x
	_flat(1900.0, 4.0)
	var gy := ground_y_at(arena_x + 900.0)
	_ledge(Rect2(arena_x + 120.0, gy - 140.0, 260.0, 14.0))
	_ledge(Rect2(arena_x + 1520.0, gy - 140.0, 260.0, 14.0))
	_ledge(Rect2(arena_x + 820.0, gy - 250.0, 260.0, 14.0))
	_pad(arena_x + 60.0, 1150.0)
	_pad(arena_x + 1840.0, 1150.0)
	_flat(200.0, 0.0)
	_end_piece()
	_block(Rect2(x - 20.0, y - 1200.0, 60.0, 1200.0 + 1500.0), "wall")
	out["arena"] = Rect2(arena_x, gy - 700.0, 1900.0, 700.0)
	out["boss_pos"] = Vector2(arena_x + 950.0, gy - 360.0)
	out["goal"] = Vector2(arena_x + 950.0, gy)
	out["length"] = x

# =====================================================================
# Movement-Bausteine: Wall-Jump-Schacht, Rutsch-Tunnel, Dash-Lücke, Sprungfelder,
# Abfahrt mit Schanze, Säulen-Parcours, brüchiger Boden mit Geheimfach
# =====================================================================
func _pad(px: float, power: float) -> void:
	out["pads"].append({"pos": Vector2(px, ground_y_at(px)), "power": power})

func _sign(px: float, py: float, key: String) -> void:
	if signs:
		out["hints"].append({"pos": Vector2(px, py), "key": key})

func _chunk_shaft() -> void:
	_flat(rng.randf_range(140.0, 220.0), 3.0)
	var h := minf(rng.randf_range(260.0, 420.0), y - MIN_Y)
	if h < 200.0:
		_chunk_canyon()
		return
	var w := rng.randf_range(115.0, 150.0)
	var floor_y := y
	var wall_x := x
	_rough(w + 36.0, 0.0, 1.0)
	# Hängewand: reicht von oben bis 95 px über den Boden -> man läuft darunter in den Schacht
	_block(Rect2(wall_x, floor_y - h - 20.0, 36.0, h + 20.0 - 95.0), "building")
	for i in 4:
		var cx := wall_x + 36.0 + (w * 0.3 if i % 2 == 0 else w * 0.7)
		out["coins"].append(Vector2(cx, floor_y - 130.0 - i * (h - 120.0) / 4.0))
	_sign(wall_x + 36.0 + w * 0.5, floor_y - 160.0, "sign_walljump")
	_step(-h)
	var top_a := x
	_rough(rng.randf_range(220.0, 340.0), rng.randf_range(-10.0, 10.0), 5.0)
	out["decor"].append({"kind": "tower", "pos": Vector2(top_a + 60.0, ground_y_at(top_a + 60.0))})
	if rng.randf() < 0.7:
		_spawn(_high_kind(), Vector2(x - 80.0, ground_y_at(x - 80.0) - 34.0))

func _chunk_tunnel() -> void:
	_flat(rng.randf_range(200.0, 280.0), 3.0)
	var gy := y
	var len := rng.randf_range(170.0, 280.0)
	var tx := x
	_rough(len + 70.0, 0.0, 0.3)
	# hohe Wand mit Schlitz unten: nur rutschend passierbar
	_block(Rect2(tx + 35.0, gy - 44.0 - 440.0, len, 440.0), "building")
	_coin_line(tx + 50.0, tx + len + 20.0, gy - 18.0, 6)
	_sign(tx - 40.0, gy - 120.0, "sign_slide")
	_flat(rng.randf_range(180.0, 260.0), 4.0)
	for i in _count(0.8):
		_spawn_ground(_ground_kind(), x - rng.randf_range(30.0, 150.0))

func _chunk_dash_gap() -> void:
	_flat(rng.randf_range(180.0, 260.0), 3.0)
	var gy := y
	_end_piece()
	var w := rng.randf_range(320.0, 420.0)
	_coin_arc(x + 20.0, x + w - 20.0, gy - 60.0, 50.0, 7)
	_sign(x - 60.0, gy - 120.0, "sign_dash")
	if rng.randf() < 0.4 + d * 0.1:
		_spawn("drone", Vector2(x + w * 0.5, gy - 220.0))
	x += w
	y = clampf(gy + rng.randf_range(-30.0, 20.0), MIN_Y, MAX_Y)
	_start_piece()
	_flat(rng.randf_range(260.0, 380.0))
	for i in _count(0.6):
		_spawn_ground(_ground_kind(), x - rng.randf_range(40.0, 200.0))

func _chunk_pad_cliff() -> void:
	var h := minf(rng.randf_range(260.0, 380.0), y - MIN_Y)
	if h < 180.0:
		_chunk_downhill()
		return
	_flat(rng.randf_range(160.0, 220.0), 3.0)
	var pad_x := x + 40.0
	_rough(160.0, 0.0, 0.5)
	_pad(pad_x, sqrt(2.0 * 1950.0 * (h + 90.0)))
	for i in 4:
		out["coins"].append(Vector2(pad_x + 20.0, ground_y_at(pad_x) - 120.0 - i * 60.0))
	_step(-h)
	var top := x
	_rough(rng.randf_range(260.0, 420.0), rng.randf_range(-20.0, 20.0), 6.0)
	for i in _count(0.9):
		_spawn_ground(_ground_kind(), rng.randf_range(top + 80.0, x - 40.0))

func _chunk_pad_gap() -> void:
	_flat(rng.randf_range(180.0, 260.0), 3.0)
	var pad_x := x - 70.0
	_pad(pad_x, 1250.0)
	var gy := y
	_end_piece()
	var w := rng.randf_range(420.0, 540.0)
	_coin_arc(x + 30.0, x + w - 30.0, gy - 120.0, 160.0, 9)
	if rng.randf() < 0.4:
		_ledge(Rect2(x + w * 0.5 - 60.0, gy - 80.0, 120.0, 14.0))
	x += w
	y = clampf(gy + rng.randf_range(-60.0, 30.0), MIN_Y, MAX_Y)
	_start_piece()
	_flat(rng.randf_range(260.0, 360.0))
	for i in _count(0.7):
		_spawn_ground(_ground_kind(), x - rng.randf_range(40.0, 200.0))

func _chunk_downhill() -> void:
	if y > MAX_Y - 180.0:
		_rough(rng.randf_range(300.0, 420.0), -rng.randf_range(180.0, 240.0), 5.0)
	_flat(rng.randf_range(80.0, 140.0), 2.0)
	var drop := minf(rng.randf_range(220.0, 360.0), MAX_Y - y - 10.0)
	_sign(x, y - 110.0, "sign_slide_hill")
	_rough(drop / rng.randf_range(0.62, 0.8), drop, 2.5)
	# Schanze
	_rough(80.0, -46.0, 0.0)
	var gy := y
	_end_piece()
	var w := rng.randf_range(260.0, 360.0)
	_coin_arc(x + 20.0, x + w - 20.0, gy - 40.0, 120.0, 8)
	x += w
	y = clampf(gy + rng.randf_range(0.0, 60.0), MIN_Y, MAX_Y)
	_start_piece()
	_flat(rng.randf_range(280.0, 380.0))
	for i in _count(0.8):
		_spawn_ground(_ground_kind(), x - rng.randf_range(40.0, 220.0))

func _chunk_pillars() -> void:
	_flat(rng.randf_range(120.0, 180.0), 3.0)
	var top := y
	_end_piece()
	var n := rng.randi_range(3, 5)
	for i in n:
		x += rng.randf_range(110.0, 175.0)
		var w := rng.randf_range(44.0, 72.0)
		top = clampf(top + rng.randf_range(-90.0, 60.0), MIN_Y, MAX_Y)
		_block(Rect2(x, top, w, BOTTOM - top), "building")
		out["coins"].append(Vector2(x + w * 0.5, top - 34.0))
		if i == n / 2 and rng.randf() < 0.5 + d * 0.1:
			_spawn("turret", Vector2(x + w * 0.5, top - 34.0))
		x += w
	x += rng.randf_range(110.0, 170.0)
	y = clampf(top + rng.randf_range(0.0, 50.0), MIN_Y, MAX_Y)
	_start_piece()
	_flat(rng.randf_range(260.0, 360.0))

func _chunk_weak() -> void:
	_flat(rng.randf_range(160.0, 240.0), 3.0)
	var gy := y
	var px0 := x
	var pw := rng.randf_range(170.0, 230.0)
	var depth := rng.randf_range(100.0, 128.0)
	_step(depth)
	_rough(pw - 4.0, 0.0, 0.5)
	_step(-depth)
	# Deckel aus brüchigem Material, bündig mit dem Boden: mit dem Ground-Slam aufbrechen
	_block(Rect2(px0 - 2.0, gy - 2.0, pw + 4.0, 26.0), "weak")
	_coin_line(px0 + 25.0, px0 + pw - 25.0, gy + depth - 30.0, 6)
	_sign(px0 + pw * 0.5, gy - 110.0, "sign_slam")
	_flat(rng.randf_range(220.0, 320.0), 4.0)
	for i in _count(0.7):
		_spawn_ground(_ground_kind(), x - rng.randf_range(30.0, 180.0))
