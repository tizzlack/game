# Zeichenhilfen für den Neon-Look: jede Form wird mit weichen Glow-Schichten und einem hellen HDR-Kern gezeichnet.
# Der HDR-Kern (Werte > 1) wird zusätzlich vom WorldEnvironment-Glow aufgehellt.
extends RefCounted

static func hdr(c: Color, boost: float = 0.8) -> Color:
	return Color(c.r * (1.0 + boost), c.g * (1.0 + boost), c.b * (1.0 + boost), c.a)

static func fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)

# Kernfarbe einer Neonröhre: fast weiß glühend, mit einem Hauch der Grundfarbe
static func core(c: Color, glow: float) -> Color:
	return hdr(c.lerp(Color(1, 1, 1, c.a), 0.4), 1.2 * glow)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float = 2.0, glow: float = 1.0) -> void:
	if glow > 0.0:
		# Breite Schichten nur so breit wie die Linie lang ist, sonst entstehen eckige Leuchtkästen
		var len := a.distance_to(b)
		var w1 := minf(w * 11.0, len * 0.35)
		var w2 := minf(w * 5.5, len * 0.55)
		if w1 > w * 3.0:
			ci.draw_line(a, b, fade(c, 0.04 * glow), w1)
		if w2 > w * 2.4:
			ci.draw_line(a, b, fade(c, 0.1 * glow), w2)
		ci.draw_line(a, b, fade(c, 0.32 * glow), w * 2.4)
	ci.draw_line(a, b, core(c, glow), w, true)

static func polyline(ci: CanvasItem, pts: PackedVector2Array, c: Color, w: float = 2.0, glow: float = 1.0) -> void:
	if pts.size() < 2:
		return
	if glow > 0.0:
		ci.draw_polyline(pts, fade(c, 0.035 * glow), w * 13.0)
		ci.draw_polyline(pts, fade(c, 0.1 * glow), w * 5.5)
		ci.draw_polyline(pts, fade(c, 0.32 * glow), w * 2.4)
	ci.draw_polyline(pts, core(c, glow), w, true)

static func circle(ci: CanvasItem, center: Vector2, r: float, c: Color, w: float = 2.0, glow: float = 1.0) -> void:
	var seg := clampi(int(r * 0.8), 12, 48)
	if glow > 0.0:
		ci.draw_arc(center, r, 0.0, TAU, seg, fade(c, 0.04 * glow), w * 11.0)
		ci.draw_arc(center, r, 0.0, TAU, seg, fade(c, 0.1 * glow), w * 5.5)
		ci.draw_arc(center, r, 0.0, TAU, seg, fade(c, 0.32 * glow), w * 2.4)
	ci.draw_arc(center, r, 0.0, TAU, seg, core(c, glow), w, true)

static func dot(ci: CanvasItem, center: Vector2, r: float, c: Color, glow: float = 1.0) -> void:
	if glow > 0.0:
		ci.draw_circle(center, r * 5.0, fade(c, 0.035 * glow))
		ci.draw_circle(center, r * 2.6, fade(c, 0.1 * glow))
		ci.draw_circle(center, r * 1.6, fade(c, 0.28 * glow))
	ci.draw_circle(center, r, hdr(c, 1.2 * glow))

static var _halo: GradientTexture2D

static func halo_tex() -> GradientTexture2D:
	if _halo == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.25, Color(1, 1, 1, 0.5))
		g.add_point(0.6, Color(1, 1, 1, 0.12))
		_halo = GradientTexture2D.new()
		_halo.gradient = g
		_halo.fill = GradientTexture2D.FILL_RADIAL
		_halo.fill_from = Vector2(0.5, 0.5)
		_halo.fill_to = Vector2(1.0, 0.5)
		_halo.width = 128
		_halo.height = 128
	return _halo

# Weicher, runder Lichtschein (für helle Objekte wie Spieler, Kugeln, Explosionen)
static func halo(ci: CanvasItem, center: Vector2, r: float, c: Color) -> void:
	ci.draw_texture_rect(halo_tex(), Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false, c)

static func rect(ci: CanvasItem, r: Rect2, c: Color, w: float = 2.0, glow: float = 1.0) -> void:
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	polyline(ci, p, c, w, glow)

# Unterteilt eine Linie und verwackelt sie leicht – das gibt den "elektrischen", handgezeichneten Rand.
static func jagged(pts: PackedVector2Array, rng: RandomNumberGenerator, step: float = 9.0, amp: float = 1.4) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return pts
	out.append(pts[0])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var n := maxi(1, int(a.distance_to(b) / step))
		var nrm := (b - a).orthogonal().normalized()
		for k in range(1, n):
			var p := a.lerp(b, float(k) / n)
			out.append(p + nrm * rng.randf_range(-amp, amp))
		out.append(b)
	return out
