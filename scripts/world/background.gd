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

func setup(palette: Dictionary, s: int) -> void:
	pal = palette
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	stars.clear()
	for i in 160:
		stars.append([Vector2(rng.randf() * 2400.0, rng.randf() * 900.0), rng.randf_range(0.6, 1.8), rng.randf() * TAU, rng.randf_range(0.02, 0.12)])
	embers.clear()
	for i in 70:
		embers.append([Vector2(rng.randf() * 1600.0, rng.randf() * 900.0), Vector2(rng.randf_range(-12, 12), rng.randf_range(-30, -8)), rng.randf_range(1.0, 2.6), rng.randf()])
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
		var a := 0.35 + 0.35 * sin(t * 1.7 + s[2])
		draw_circle(Vector2(px, py), s[1], Neon.fade(sc, a))
	for sl in skyline:
		var pts: PackedVector2Array = sl[0]
		var f: float = sl[1]
		var off := Vector2(-fposmod(cam_pos.x * f, 1200.0), -cam_pos.y * f * 0.3 + size.y - 720.0 + 40.0)
		var moved := PackedVector2Array()
		for p in pts:
			moved.append(p + off)
		draw_polyline(moved, Neon.fade(pal["accent"], sl[2]), 1.5)
	var ec: Color = pal["ember"]
	for e in embers:
		var p: Vector2 = e[0]
		var px := fposmod(p.x - cam_pos.x * 0.35, size.x + 40.0) - 20.0
		var py := fposmod(p.y - cam_pos.y * 0.2, size.y + 40.0) - 20.0
		var a := 0.4 + 0.6 * absf(sin(e[3] * 3.0))
		draw_rect(Rect2(px, py, e[2] * 2.2, e[2] * 0.9), Neon.hdr(Neon.fade(ec, a * 0.7), 0.5))
