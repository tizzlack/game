# Hintergrund: Farbverlauf, funkelnde Sterne, entfernte Skyline und treibende Glut. Folgt der Kamera mit Parallaxe.
extends Node2D

const Neon = preload("res://scripts/core/neon.gd")

var pal: Dictionary
var stars: Array = []
var embers: Array = []
var skyline: Array = []  # [PackedVector2Array, Parallax-Faktor, Alpha]
var cam_pos := Vector2.ZERO
var t := 0.0
var auto_scroll := 0.0  # für das Hauptmenü
var haze: Array = []  # große, weiche Lichtflecken
var show_skyline := false
var hills: Array = []  # [PackedVector2Array (Periode 2400), Parallax, Höhe]
var lights: Array = []
var haze_tex: GradientTexture2D

func setup(palette: Dictionary, s: int) -> void:
	pal = palette
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	stars.clear()
	for i in 70:
		stars.append([Vector2(rng.randf() * 2400.0, rng.randf() * 900.0), rng.randf_range(0.5, 1.2), rng.randf() * TAU, rng.randf_range(0.02, 0.12)])
	if haze_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.4, Color(1, 1, 1, 0.45))
		haze_tex = GradientTexture2D.new()
		haze_tex.gradient = g
		haze_tex.fill = GradientTexture2D.FILL_RADIAL
		haze_tex.fill_from = Vector2(0.5, 0.5)
		haze_tex.fill_to = Vector2(1.0, 0.5)
		haze_tex.width = 128
		haze_tex.height = 128
	haze.clear()
	for i in 6:
		haze.append([Vector2(rng.randf() * 2400.0, rng.randf_range(150.0, 650.0)), rng.randf_range(220.0, 420.0), rng.randf()])
	embers.clear()
	for i in 55:
		embers.append([Vector2(rng.randf() * 1600.0, rng.randf() * 900.0), Vector2(rng.randf_range(-10, 10), rng.randf_range(-14, -3)), rng.randf_range(1.2, 2.4), rng.randf()])
	hills.clear()
	for layer in 2:
		var unit := PackedVector2Array()
		var hx := 0.0
		var hy := 0.0
		while hx < 2400.0:
			unit.append(Vector2(hx, hy))
			hx += rng.randf_range(14.0, 40.0)
			hy = clampf(hy + rng.randf_range(-16.0, 16.0) + (randf() - 0.5) * 2.0, -110.0, 50.0)
		unit.append(Vector2(2400.0, 0.0))
		var pts := PackedVector2Array()
		for rep in 3:
			for p in unit:
				pts.append(p + Vector2(rep * 2400.0, 0))
		hills.append([pts, 0.18 + layer * 0.1, 660.0 + layer * 45.0])
	lights.clear()
	for i in 4:
		lights.append([Vector2(rng.randf() * 2400.0, rng.randf_range(250.0, 520.0)), rng.randf_range(20.0, 46.0)])
	skyline.clear()
	for layer in 2:
		# Muster mit Periode 1200 px, dreimal aneinandergehängt -> nahtloses Scrollen
		var unit := PackedVector2Array()
		var xx := 0.0
		var base := 560.0 + layer * 60.0
		while xx < 1200.0:
			var w := minf(rng.randf_range(40.0, 140.0), 1200.0 - xx)
			var h := rng.randf_range(40.0, 220.0) * (0.6 if layer == 1 else 1.0)
			unit.append(Vector2(xx, base - h))
			unit.append(Vector2(xx + w, base - h))
			if rng.randf() < 0.3:
				unit.append(Vector2(xx + w, base - h * rng.randf_range(0.3, 0.7)))
			xx += w
		var pts := PackedVector2Array()
		for rep in 4:
			for p in unit:
				pts.append(p + Vector2(rep * 1200.0, 0))
		skyline.append([pts, 0.08 + layer * 0.07, 0.16 - layer * 0.05])

func _process(delta: float) -> void:
	t += delta
	cam_pos.x += auto_scroll * delta
	var vp := get_viewport()
	var cam := vp.get_camera_2d()
	if cam and auto_scroll == 0.0:
		cam_pos = cam.get_screen_center_position()
	for e in embers:
		e[0] += e[1] * delta
		e[3] += delta * 0.3
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var top: Color = pal["sky_top"]
	var bot: Color = pal["sky_bottom"]
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([top, top, bot, bot]))
	var sc: Color = pal["star"]
	for s in stars:
		var p: Vector2 = s[0]
		var px := fposmod(p.x - cam_pos.x * s[3], size.x + 40.0) - 20.0
		var py := fposmod(p.y - cam_pos.y * s[3] * 0.5, size.y)
		var a := 0.2 + 0.25 * sin(t * 1.7 + s[2])
		draw_circle(Vector2(px, py), s[1], Neon.fade(sc, a))
	if show_skyline:
		for sl in skyline:
			var pts: PackedVector2Array = sl[0]
			var f: float = sl[1]
			var off := Vector2(-fposmod(cam_pos.x * f, 1200.0), -cam_pos.y * f * 0.3 + size.y - 720.0 + 40.0)
			var moved := PackedVector2Array()
			for p in pts:
				moved.append(p + off)
			draw_polyline(moved, Neon.fade(pal["accent"], sl[2]), 1.5)
	# Hügellinien hinten (wie die grüne Linie in der Vorlage)
	var hc: Color = pal["building"]
	for hl in hills:
		var pts: PackedVector2Array = hl[0]
		var f: float = hl[1]
		var off := Vector2(-fposmod(cam_pos.x * f, 2400.0), hl[2] - (cam_pos.y - 400.0) * f * 0.4 + (size.y - 720.0))
		var moved := PackedVector2Array()
		for p in pts:
			var q := p + off
			if q.x > -60.0 and q.x < size.x + 60.0:
				moved.append(q)
		if moved.size() > 1:
			var fill := moved.duplicate()
			fill.append(Vector2(moved[moved.size() - 1].x, size.y + 10))
			fill.append(Vector2(moved[0].x, size.y + 10))
			if Geometry2D.triangulate_polygon(fill).size() > 0:
				draw_colored_polygon(fill, Color(0, 0, 0, 1))
			Neon.polyline(self, moved, Neon.fade(hc, 0.32 if f < 0.25 else 0.2), 1.3, 0.6)
	# entfernte Lichtpunkte
	for lt in lights:
		var lp: Vector2 = lt[0]
		var lx := fposmod(lp.x - cam_pos.x * 0.15, size.x + 200.0) - 100.0
		Neon.halo(self, Vector2(lx, lp.y - cam_pos.y * 0.05), lt[1], Neon.fade(pal["star"], 0.12 + 0.04 * sin(t + lp.x)))
	var ec: Color = pal["ember"]
	for e in embers:
		var p: Vector2 = e[0]
		var px := fposmod(p.x - cam_pos.x * 0.35, size.x + 40.0) - 20.0
		var py := fposmod(p.y - cam_pos.y * 0.2, size.y + 40.0) - 20.0
		var a := 0.45 + 0.55 * absf(sin(e[3] * 2.0))
		draw_rect(Rect2(px, py, e[2] * 2.6, e[2] * 0.8), Neon.hdr(Neon.fade(ec, a * 0.75), 0.6))
