# Deko für das Hauptmenü: scrollender Neon-Boden mit laufender, schießender Figur.
extends Node2D

const Neon = preload("res://scripts/core/neon.gd")
const Figure = preload("res://scripts/core/figure.gd")

var t := 0.0
var ground: Array = []
var shots: Array = []
var shot_cd := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 3
	var x := 0.0
	var y := 0.0
	while x < 4000.0:
		ground.append(Vector2(x, y))
		x += rng.randf_range(60.0, 160.0)
		y = clampf(y + rng.randf_range(-30.0, 30.0), -60.0, 40.0)

func _process(delta: float) -> void:
	t += delta
	shot_cd -= delta
	if shot_cd <= 0.0:
		shot_cd = rng.randf_range(0.12, 0.5)
		shots.append([0.0, rng.randf_range(-0.08, 0.04)])
	for s in shots:
		s[0] += delta
	shots = shots.filter(func(s): return s[0] < 1.2)
	queue_redraw()

func _ground_y(x: float, scroll: float) -> float:
	var gx := fposmod(x + scroll, 3800.0)
	for i in range(1, ground.size()):
		if ground[i].x >= gx:
			var a: Vector2 = ground[i - 1]
			var b: Vector2 = ground[i]
			return lerpf(a.y, b.y, (gx - a.x) / maxf(1.0, b.x - a.x))
	return 0.0

func _draw() -> void:
	var size := get_viewport_rect().size
	var base := size.y * 0.82
	var scroll := t * 260.0
	var pts := PackedVector2Array()
	var x := -20.0
	while x < size.x + 40.0:
		pts.append(Vector2(x, base + _ground_y(x, scroll)))
		x += 24.0
	var fill := pts.duplicate()
	fill.append(Vector2(size.x + 40, size.y))
	fill.append(Vector2(-20, size.y))
	draw_colored_polygon(fill, Color(0.01, 0.015, 0.04))
	Neon.polyline(self, pts, Color(0.85, 0.95, 1.0), 2.2)
	var px := size.x * 0.62
	var py := base + _ground_y(px, scroll) - 27.0
	var aim := Vector2(1, -0.05).normalized()
	var pose := Figure.pose(t * 13.0, 1.0, 1.0, true, aim, 16.0)
	draw_set_transform(Vector2(px, py), 0.0, Vector2(1.6, 1.6))
	Figure.draw(self, pose, Color(0.75, 0.9, 1.0), 2.2, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for s in shots:
		var k: float = s[0]
		var a := Vector2(px + 50.0 + k * 1400.0, py - 22.0 + k * s[1] * 900.0)
		Neon.line(self, a - Vector2(30, 0), a, Color(0.4, 0.85, 1.0), 3.0)
	# ein paar Gegner rechts am Rand
	for i in 3:
		var ex := fposmod(size.x * 1.1 - t * 160.0 - i * 380.0, size.x * 1.3) + size.x * 0.75
		if ex > size.x + 30.0 or ex < px + 140.0:
			continue
		var ey := base + _ground_y(ex, scroll) - 27.0
		var ep := Figure.pose(t * 10.0 + i, 0.8, -1.0, true, Vector2.LEFT, 0.0)
		draw_set_transform(Vector2(ex, ey), 0.0, Vector2(1.6, 1.6))
		Figure.draw(self, ep, Color(1.0, 0.25, 0.38), 2.2, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
