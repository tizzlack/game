# Zerstörbares Geländestück: Polygone in Weltkoordinaten, Kollision und Neon-Umriss.
# Treffer stanzen treppenförmige Löcher aus (Geometry2D.clip_polygons), danach werden Kollision und Grafik neu gebaut.
extends StaticBody2D

const Neon = preload("res://scripts/core/neon.gd")

var kind := "ground"  # ground | building | box
var polys: Array = []  # Array[PackedVector2Array]
var pal: Dictionary
var seams: Array = []  # x-Positionen von inneren Schnittkanten (werden nicht gezeichnet)
var top_y := 0.0
var bbox := Rect2()
var seed_value := 0
var destructible := true
var carve_floor := INF  # unterhalb dieser Höhe wird nicht mehr ausgestanzt

func setup(k: String, poly: PackedVector2Array, palette: Dictionary, s: int, seam_xs: Array = []) -> void:
	kind = k
	pal = palette
	seed_value = s
	seams = seam_xs
	polys = [poly]
	collision_layer = 1
	collision_mask = 0
	_update_bounds()
	carve_floor = top_y + 260.0

func _ready() -> void:
	_rebuild_collision()

func _update_bounds() -> void:
	var first := true
	for p in polys:
		for v in p:
			if first:
				bbox = Rect2(v, Vector2.ZERO)
				first = false
			else:
				bbox = bbox.expand(v)
	top_y = bbox.position.y

func _rebuild_collision() -> void:
	for c in get_children():
		if c is CollisionPolygon2D or c is CollisionShape2D:
			remove_child(c)
			c.queue_free()
	for i in polys.size():
		polys[i] = _clean(polys[i])
	for p in polys:
		if p.size() < 3:
			continue
		for part in _convex_parts(p):
			if part.size() < 3:
				continue
			var cs := CollisionShape2D.new()
			var sh := ConvexPolygonShape2D.new()
			sh.set_point_cloud(part)
			cs.shape = sh
			add_child(cs)

# Zerlegt ein Polygon stabil in konvexe Teile: triangulieren, dann benachbarte Dreiecke gierig zusammenfügen
static func _convex_parts(p: PackedVector2Array) -> Array:
	var tri := Geometry2D.triangulate_polygon(p)
	var parts: Array = []
	for k in range(0, tri.size(), 3):
		var t := PackedVector2Array([p[tri[k]], p[tri[k + 1]], p[tri[k + 2]]])
		if absf(_area(t)) < 0.01:
			continue
		var merged := false
		for i in parts.size():
			var m := Geometry2D.merge_polygons(parts[i], t)
			if m.size() == 1 and _is_convex(m[0]):
				parts[i] = m[0]
				merged = true
				break
		if not merged:
			parts.append(t)
	return parts

static func _is_convex(p: PackedVector2Array) -> bool:
	if p.size() < 3 or p.size() > 12:
		return false
	var sign := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		var c := p[(i + 2) % p.size()]
		var cr := (b - a).cross(c - b)
		if absf(cr) < 0.001:
			continue
		if sign == 0.0:
			sign = signf(cr)
		elif signf(cr) != sign:
			return false
	return true

# Entfernt doppelte und fast gerade Zwischenpunkte, damit die Zerlegung stabil bleibt
static func _clean(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p:
		if out.is_empty() or out[out.size() - 1].distance_to(v) > 0.6:
			out.append(v)
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) <= 0.6:
		out.remove_at(out.size() - 1)
	var changed := true
	while changed and out.size() > 3:
		changed = false
		for i in out.size():
			var a := out[(i - 1 + out.size()) % out.size()]
			var b := out[i]
			var c := out[(i + 1) % out.size()]
			if absf((b - a).cross(c - b)) < 0.05:
				out.remove_at(i)
				changed = true
				break
	return out

# Treppenförmige "Pixel"-Form für ein Loch
static func stair_shape(center: Vector2, r: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var grid := clampf(r * 0.35, 3.0, 10.0)
	var n := clampi(int(r * 0.9), 10, 28)
	var pts: Array = []
	for i in n:
		var a := TAU * i / n
		var rr := r * rng.randf_range(0.7, 1.15)
		var p := center + Vector2(cos(a), sin(a)) * rr
		p = Vector2(round(p.x / grid) * grid, round(p.y / grid) * grid)
		pts.append(p)
	# Treppen-Ecken nur einfügen, wenn die Form dabei sternförmig (und damit überschneidungsfrei) bleibt
	var out := PackedVector2Array()
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		if out.size() > 0 and out[out.size() - 1].distance_to(a) < 0.5:
			continue
		out.append(a)
		if absf(a.x - b.x) > 0.1 and absf(a.y - b.y) > 0.1:
			var c := Vector2(b.x, a.y) if i % 2 == 0 else Vector2(a.x, b.y)
			var aa := (a - center).angle()
			var ab := wrapf((b - center).angle() - aa, 0.0, TAU)
			var ac := wrapf((c - center).angle() - aa, 0.0, TAU)
			if ac > 0.0 and ac < ab and c.distance_to(center) > 1.0:
				out.append(c)
	return out

# Stanzt eine Form aus. Gibt true zurück, wenn sich etwas verändert hat.
func carve(shape: PackedVector2Array, shape_rect: Rect2) -> bool:
	if not destructible or not bbox.intersects(shape_rect):
		return false
	if shape_rect.position.y > carve_floor:
		return false
	var changed := false
	var out: Array = []
	var orient_cw := false
	for p in polys:
		var res := Geometry2D.clip_polygons(p, shape)
		if res.size() == 1 and res[0].size() == p.size():
			out.append(p)
			continue
		# Ein Loch komplett im Inneren (anders orientiertes Ergebnis) kann die Kollision nicht abbilden -> überspringen
		orient_cw = Geometry2D.is_polygon_clockwise(p)
		var has_hole := false
		for r in res:
			if Geometry2D.is_polygon_clockwise(r) != orient_cw:
				has_hole = true
		if has_hole:
			out.append(p)
			continue
		changed = true
		for r in res:
			if absf(_area(r)) > 30.0:
				out.append(r)
	if not changed:
		return false
	polys = out
	_update_bounds()
	_rebuild_collision()
	queue_redraw()
	return true

static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var j := (i + 1) % p.size()
		a += p[i].x * p[j].y - p[j].x * p[i].y
	return a * 0.5

func contains(pt: Vector2) -> bool:
	for p in polys:
		if Geometry2D.is_point_in_polygon(pt, p):
			return true
	return false

func _is_seam(a: Vector2, b: Vector2) -> bool:
	if absf(a.x - b.x) > 0.5:
		return false
	for sx in seams:
		if absf(a.x - sx) < 0.5:
			return true
	return false

func edge_color(a: Vector2, b: Vector2) -> Color:
	var top: Color = pal["ground"] if kind == "ground" else pal["building"].lerp(Color.WHITE, 0.55)
	var side: Color = pal["building"] if kind != "box" else pal["ledge"]
	if kind == "box":
		top = pal["ledge"].lerp(Color.WHITE, 0.3)
	var d := (b - a).normalized()
	var h := absf(d.x)
	return side.lerp(top, h * h)

func _draw() -> void:
	var fill: Color = pal["fill"]
	for p in polys:
		if Geometry2D.triangulate_polygon(p).size() > 0:
			draw_colored_polygon(p, Color(fill.r, fill.g, fill.b, 1.0))
	var fade_from := top_y + 220.0
	for p in polys:
		var n: int = p.size()
		for i in n:
			var a: Vector2 = p[i]
			var b: Vector2 = p[(i + 1) % n]
			if _is_seam(a, b):
				continue
			var depth := maxf(a.y, b.y) - fade_from
			if depth > 500.0:
				continue
			var alpha := clampf(1.0 - depth / 500.0, 0.0, 1.0)
			var c := Neon.fade(edge_color(a, b), alpha)
			var len := a.distance_to(b)
			if len > 14.0:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(Vector4(a.x, a.y, b.x, b.y)) + seed_value
				Neon.polyline(self, Neon.jagged(PackedVector2Array([a, b]), rng, 6.0, 2.0), c, 2.4, 1.0)
			else:
				Neon.line(self, a, b, c, 2.4, 1.0)
