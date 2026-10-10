# Zeichnet Boden, Gebäude, Kisten, Plattformen und Deko im Neon-Stil. Wird einmal gezeichnet und dann gecacht.
extends Node2D

const Neon = preload("res://scripts/core/neon.gd")

var kind := "ground"
var pts := PackedVector2Array()
var rect := Rect2()
var pal: Dictionary
var bottom := 2000.0
var seed_value := 0
var windows: Array = []

func setup_ground(p: PackedVector2Array, b: float, palette: Dictionary, s: int) -> void:
	kind = "ground"
	pts = p
	bottom = b
	pal = palette
	seed_value = s

func setup_rect(k: String, r: Rect2, palette: Dictionary, s: int) -> void:
	kind = k
	rect = r
	pal = palette
	seed_value = s
	if k == "building":
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var cols := int((r.size.x - 30.0) / 26.0)
		var rows := int(minf(r.size.y, 520.0) / 30.0)
		for cy in rows:
			for cx in cols:
				if rng.randf() < 0.42:
					windows.append(Vector2(r.position.x + 20.0 + cx * 26.0, r.position.y + 30.0 + cy * 30.0))

func setup_decor(k: String, pos: Vector2, palette: Dictionary, s: int) -> void:
	kind = k
	rect = Rect2(pos, Vector2.ZERO)
	pal = palette
	seed_value = s

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match kind:
		"ground": _draw_ground(rng)
		"building": _draw_building(rng)
		"box": _draw_box(rng)
		"ledge": _draw_ledge(rng)
		"wall": _draw_wall()
		"antenna": _draw_antenna()
		"tower": _draw_tower()

# Weicher Lichtschein unterhalb einer Leuchtkante
func _glow_strip(line_pts: PackedVector2Array, c: Color, depth: float, alpha: float) -> void:
	var top := Neon.fade(c, alpha)
	var bot := Neon.fade(c, 0.0)
	for i in range(1, line_pts.size()):
		var a := line_pts[i - 1]
		var b := line_pts[i]
		draw_polygon(PackedVector2Array([a, b, b + Vector2(0, depth), a + Vector2(0, depth)]), PackedColorArray([top, top, bot, bot]))

func _side(top: Vector2, c: Color, depth: float = 700.0) -> void:
	# Seitenkante, die nach unten ausblendet
	var steps := 6
	for i in steps:
		var a := top + Vector2(0, depth * i / steps)
		var b := top + Vector2(0, depth * (i + 1) / steps)
		Neon.line(self, a, b, Neon.fade(c, 1.0 - float(i) / steps), 2.0)

func _draw_ground(rng: RandomNumberGenerator) -> void:
	var fill := pts.duplicate()
	fill.append(Vector2(pts[pts.size() - 1].x, bottom))
	fill.append(Vector2(pts[0].x, bottom))
	var c: Color = pal["fill"]
	draw_colored_polygon(fill, Color(c.r, c.g, c.b, 1.0))
	var g: Color = pal["ground"]
	_glow_strip(pts, g, 46.0, 0.16)
	Neon.polyline(self, Neon.jagged(pts, rng), g, 2.2)
	# zweite, schwache Linie für Tiefe
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p + Vector2(0, 7))
	draw_polyline(Neon.jagged(inner, rng, 14.0, 1.0), Neon.fade(g, 0.12), 1.0)
	_side(pts[0], g)
	_side(pts[pts.size() - 1], g)

func _draw_building(rng: RandomNumberGenerator) -> void:
	var c: Color = pal["building"]
	var top_l := rect.position
	var top_r := Vector2(rect.end.x, rect.position.y)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 900.0)), Color(pal["fill"].r, pal["fill"].g, pal["fill"].b, 0.92))
	var top := PackedVector2Array([top_l, top_r])
	_glow_strip(top, c, 40.0, 0.14)
	Neon.polyline(self, Neon.jagged(top, rng), c, 2.2)
	_side(top_l, c, 800.0)
	_side(top_r, c, 800.0)
	var wc: Color = pal["window"]
	for w in windows:
		var a := 0.55 + rng.randf() * 0.45
		draw_rect(Rect2(w, Vector2(6, 3)), Neon.hdr(Neon.fade(wc, a), 0.4))
		draw_rect(Rect2(w - Vector2(2, 2), Vector2(10, 7)), Neon.fade(wc, 0.08))
	# Dachkante mit kleinem Aufbau
	if rect.size.x > 260.0 and rng.randf() < 0.6:
		var bx := rect.position.x + rect.size.x * rng.randf_range(0.55, 0.8)
		var box := Rect2(bx, rect.position.y - 18.0, 40.0, 18.0)
		Neon.rect(self, box, Neon.fade(c, 0.6), 1.5, 0.6)

func _draw_box(rng: RandomNumberGenerator) -> void:
	var c: Color = pal["ledge"]
	draw_rect(rect, Color(c.r, c.g, c.b, 0.05))
	var r := rect
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	Neon.polyline(self, Neon.jagged(p, rng, 10.0, 1.2), c, 2.2)

func _draw_ledge(rng: RandomNumberGenerator) -> void:
	var c: Color = pal["ledge"]
	var p := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)])
	_glow_strip(p, c, 26.0, 0.12)
	Neon.polyline(self, Neon.jagged(p, rng, 10.0, 1.0), c, 3.0)
	draw_line(rect.position + Vector2(6, 8), Vector2(rect.end.x - 6, rect.position.y + 8), Neon.fade(c, 0.18), 1.0)

func _draw_wall() -> void:
	var c: Color = pal["accent"]
	var xs := [rect.position.x, rect.end.x]
	for wx in xs:
		Neon.line(self, Vector2(wx, rect.position.y + 300.0), Vector2(wx, rect.end.y - 1000.0), Neon.fade(c, 0.5), 2.0, 0.6)
	draw_rect(rect, Color(0, 0, 0, 1))
	var yy := rect.position.y + 320.0
	while yy < rect.end.y - 1000.0:
		Neon.line(self, Vector2(rect.position.x, yy), Vector2(rect.end.x, yy + 30.0), Neon.fade(c, 0.35), 1.5, 0.4)
		yy += 60.0

func _draw_antenna() -> void:
	var p := rect.position
	var c: Color = Neon.fade(pal["ground"], 0.7)
	Neon.line(self, p, p + Vector2(0, -60), c, 1.6, 0.6)
	Neon.line(self, p + Vector2(-8, 0), p + Vector2(0, -40), c, 1.2, 0.4)
	Neon.line(self, p + Vector2(8, 0), p + Vector2(0, -40), c, 1.2, 0.4)
	Neon.dot(self, p + Vector2(0, -62), 2.2, pal["enemy"], 1.0)

func _draw_tower() -> void:
	# kleiner Funkmast wie in der Vorlage: schmales A-Gerüst mit Raute oben
	var p := rect.position
	var c: Color = Neon.fade(pal["ground"].lerp(pal["accent"], 0.3), 0.8)
	Neon.line(self, p + Vector2(-7, 0), p + Vector2(-1.5, -30), c, 1.3, 0.6)
	Neon.line(self, p + Vector2(7, 0), p + Vector2(1.5, -30), c, 1.3, 0.6)
	Neon.line(self, p + Vector2(-5, -10), p + Vector2(5, -10), Neon.fade(c, 0.7), 1.0, 0.3)
	Neon.line(self, p + Vector2(-3.5, -20), p + Vector2(3.5, -20), Neon.fade(c, 0.7), 1.0, 0.3)
	var top := p + Vector2(0, -38)
	var dia := PackedVector2Array([top + Vector2(0, -7), top + Vector2(5, 0), top + Vector2(0, 7), top + Vector2(-5, 0), top + Vector2(0, -7)])
	Neon.polyline(self, dia, c, 1.3, 0.7)
