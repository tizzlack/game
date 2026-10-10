# Zeichenhilfen für den Neon-Look: jede Form wird mit weichen Glow-Schichten und einem hellen HDR-Kern gezeichnet.
# Der HDR-Kern (Werte > 1) wird zusätzlich vom WorldEnvironment-Glow aufgehellt.
extends RefCounted

static func hdr(c: Color, boost: float = 0.8) -> Color:
	return Color(c.r * (1.0 + boost), c.g * (1.0 + boost), c.b * (1.0 + boost), c.a)

static func fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float = 2.0, glow: float = 1.0) -> void:
	if glow > 0.0:
		ci.draw_line(a, b, fade(c, 0.07 * glow), w * 6.0)
		ci.draw_line(a, b, fade(c, 0.22 * glow), w * 2.6)
	ci.draw_line(a, b, hdr(c, 0.8 * glow), w, true)

static func polyline(ci: CanvasItem, pts: PackedVector2Array, c: Color, w: float = 2.0, glow: float = 1.0) -> void:
	if pts.size() < 2:
		return
	if glow > 0.0:
		ci.draw_polyline(pts, fade(c, 0.07 * glow), w * 6.0)
		ci.draw_polyline(pts, fade(c, 0.22 * glow), w * 2.6)
	ci.draw_polyline(pts, hdr(c, 0.8 * glow), w, true)

static func circle(ci: CanvasItem, center: Vector2, r: float, c: Color, w: float = 2.0, glow: float = 1.0) -> void:
	var seg := clampi(int(r * 0.8), 12, 48)
	if glow > 0.0:
		ci.draw_arc(center, r, 0.0, TAU, seg, fade(c, 0.07 * glow), w * 6.0)
		ci.draw_arc(center, r, 0.0, TAU, seg, fade(c, 0.22 * glow), w * 2.6)
	ci.draw_arc(center, r, 0.0, TAU, seg, hdr(c, 0.8 * glow), w, true)

static func dot(ci: CanvasItem, center: Vector2, r: float, c: Color, glow: float = 1.0) -> void:
	if glow > 0.0:
		ci.draw_circle(center, r * 3.2, fade(c, 0.06 * glow))
		ci.draw_circle(center, r * 1.8, fade(c, 0.2 * glow))
	ci.draw_circle(center, r, hdr(c, 0.9 * glow))

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
