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
var windows: Array = []
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
	if kind == "building":
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var r := bbox
		var cols := int((r.size.x - 24.0) / 22.0)
		var rows := int(minf(r.size.y, 480.0) / 26.0)
		for cy in rows:
			for cx in cols:
				if rng.randf() < 0.38:
					var c: Color = pal["window"] if rng.randf() < 0.65 else pal["building"]
					windows.append([Vector2(r.position.x + 16.0 + cx * 22.0, r.position.y + 26.0 + cy * 26.0), c, rng.randf_range(0.5, 1.0)])

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
		if c is CollisionPolygon2D:
			remove_child(c)
			c.queue_free()
	for p in polys:
		if p.size() < 3:
			continue
		var cp := CollisionPolygon2D.new()
		cp.polygon = p
		add_child(cp)

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
	var out := PackedVector2Array()
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		out.append(a)
		if absf(a.x - b.x) > 0.1 and absf(a.y - b.y) > 0.1:
			out.append(Vector2(b.x, a.y) if i % 2 == 0 else Vector2(a.x, b.y))
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
	if kind == "building":
		for w in windows:
			var wp: Vector2 = w[0]
			if not contains(wp + Vector2(3, 1)):
				continue
			var wc: Color = w[1]
			draw_rect(Rect2(wp, Vector2(7, 2.5)), Neon.hdr(Neon.fade(wc, w[2]), 0.6))
