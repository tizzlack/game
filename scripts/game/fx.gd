# Leichtgewichtiges Partikelsystem für alle Effekte, additiv gezeichnet.
extends Node2D

const Neon = preload("res://scripts/core/neon.gd")
const Figure = preload("res://scripts/core/figure.gd")

enum K { SPARK, DOT, RING, FLASH, TEXT, BOLT, GHOST, DEBRIS, TRACE, BANNER_RING }

class P:
	var kind := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 1.0
	var max_life := 1.0
	var col := Color.WHITE
	var size := 2.0
	var drag := 3.0
	var grav := 0.0
	var rot := 0.0
	var spin := 0.0
	var text := ""
	var data = null

const MAX := 2200
var list: Array[P] = []
var font: Font
var show_numbers := true

func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	font = load("res://assets/fonts/MonoFont.ttf")
	z_index = 20

func _add(kind: int, pos: Vector2, vel: Vector2, life: float, col: Color, size: float) -> P:
	var p := P.new()
	p.kind = kind
	p.pos = pos
	p.vel = vel
	p.life = life
	p.max_life = life
	p.col = col
	p.size = size
	if list.size() >= MAX:
		list[randi() % list.size()] = p
	else:
		list.append(p)
	return p

func _process(delta: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var p := list[i]
		p.life -= delta
		if p.life <= 0.0:
			list[i] = list[list.size() - 1]
			list.pop_back()
		else:
			p.vel *= exp(-p.drag * delta)
			p.vel.y += p.grav * delta
			p.pos += p.vel * delta
			p.rot += p.spin * delta
		i -= 1
	queue_redraw()

func _draw() -> void:
	for p in list:
		var t := p.life / p.max_life
		match p.kind:
			K.SPARK:
				var tail := p.pos - p.vel * 0.025 * (0.5 + t)
				Neon.line(self, tail, p.pos, Neon.fade(p.col, t), p.size * (0.4 + 0.6 * t), 0.8)
			K.DOT:
				Neon.dot(self, p.pos, p.size * (0.3 + 0.7 * t), Neon.fade(p.col, t), 0.8)
			K.RING:
				var r := p.size * (1.0 - t * t) + 4.0
				Neon.circle(self, p.pos, r, Neon.fade(p.col, t), 2.5 * t + 0.5, 0.8)
			K.FLASH:
				draw_circle(p.pos, p.size * (1.4 - t * 0.4), Neon.hdr(Neon.fade(p.col, t * t * 0.7), 1.5))
				draw_circle(p.pos, p.size * 2.2, Neon.fade(p.col, t * t * 0.12))
			K.TEXT:
				var a := clampf(t * 2.5, 0.0, 1.0)
				var fs := int(p.size)
				var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, p.pos - Vector2(w * 0.5, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Neon.hdr(Neon.fade(p.col, a), 0.6))
			K.BOLT:
				var pts: PackedVector2Array = p.data
				Neon.polyline(self, pts, Neon.fade(p.col, t), 2.0 * t + 0.6, 1.0)
			K.GHOST:
				Figure.draw(self, p.data, Neon.fade(p.col, t * 0.45), 2.0, 0.5)
			K.DEBRIS:
				var d := Vector2.from_angle(p.rot) * p.size
				Neon.line(self, p.pos - d, p.pos + d, Neon.fade(p.col, t), 1.6, 0.7)
			K.TRACE:
				var b: Vector2 = p.data
				Neon.line(self, p.pos, b, Neon.fade(p.col, t * t), p.size * t, 1.0)
			K.BANNER_RING:
				var r2 := p.size * (1.0 - t)
				draw_arc(p.pos, r2, 0.0, TAU, 48, Neon.fade(p.col, t * 0.6), 3.0)

# --- Öffentliche Effekte ---
func sparks(pos: Vector2, col: Color, count: int, speed: float, dir: Vector2 = Vector2.ZERO, spread: float = PI) -> void:
	for i in count:
		var ang := (dir.angle() if dir != Vector2.ZERO else randf() * TAU) + randf_range(-spread, spread)
		var p := _add(K.SPARK, pos, Vector2.from_angle(ang) * speed * randf_range(0.35, 1.0), randf_range(0.18, 0.45), col, randf_range(1.2, 2.2))
		p.drag = 4.0
		p.grav = 300.0

func hit(pos: Vector2, col: Color, dir: Vector2) -> void:
	sparks(pos, col, 5, 380.0, -dir, 0.9)
	_add(K.FLASH, pos, Vector2.ZERO, 0.08, col, 9.0)

func wall_hit(pos: Vector2, col: Color, normal: Vector2) -> void:
	sparks(pos, col, 4, 260.0, normal, 1.0)
	_add(K.FLASH, pos, Vector2.ZERO, 0.06, col, 6.0)

func explosion(pos: Vector2, col: Color, size: float = 1.0) -> void:
	_add(K.FLASH, pos, Vector2.ZERO, 0.22, Color(1, 1, 1), 26.0 * size)
	_add(K.FLASH, pos, Vector2.ZERO, 0.35, col, 40.0 * size)
	_add(K.RING, pos, Vector2.ZERO, 0.45, col, 70.0 * size)
	sparks(pos, col, int(18 * size), 650.0 * sqrt(size))
	sparks(pos, Color(1, 1, 1), int(6 * size), 500.0 * sqrt(size))
	for i in int(8 * size):
		var p := _add(K.DEBRIS, pos, Vector2.from_angle(randf() * TAU) * randf_range(120, 420) * sqrt(size), randf_range(0.5, 1.0), col, randf_range(3, 7))
		p.grav = 900.0
		p.drag = 1.0
		p.spin = randf_range(-14, 14)
		p.rot = randf() * TAU
	for i in int(10 * size):
		var p := _add(K.DOT, pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)) * size, Vector2.from_angle(randf() * TAU) * randf_range(20, 140), randf_range(0.5, 1.2), col, randf_range(1.5, 3.0))
		p.drag = 2.0
		p.grav = -40.0

func ring(pos: Vector2, col: Color, radius: float, life: float = 0.4) -> void:
	_add(K.RING, pos, Vector2.ZERO, life, col, radius)

func flash(pos: Vector2, col: Color, size: float, life: float = 0.12) -> void:
	_add(K.FLASH, pos, Vector2.ZERO, life, col, size)

func text(pos: Vector2, s: String, col: Color, size: float = 18.0, life: float = 0.8, rise: float = 70.0) -> void:
	var p := _add(K.TEXT, pos, Vector2(randf_range(-15, 15), -rise), life, col, size)
	p.text = s
	p.drag = 2.5

func number(pos: Vector2, v: float, crit: bool) -> void:
	if not show_numbers:
		return
	var s := str(int(round(v)))
	if crit:
		text(pos + Vector2(0, -10), s + "!", Color(1.0, 0.85, 0.3), 20.0, 0.7, 110.0)
	else:
		text(pos + Vector2(0, -10), s, Color(1, 1, 1, 0.85), 14.0, 0.5, 90.0)

func bolt(a: Vector2, b: Vector2, col: Color, life: float = 0.25) -> void:
	var pts := PackedVector2Array()
	var n := maxi(3, int(a.distance_to(b) / 18.0))
	var nrm := (b - a).orthogonal().normalized()
	for i in n + 1:
		var t := float(i) / n
		var off := 0.0 if i == 0 or i == n else randf_range(-12, 12)
		pts.append(a.lerp(b, t) + nrm * off)
	var p := _add(K.BOLT, a, Vector2.ZERO, life, col, 2.0)
	p.data = pts
	p.drag = 0.0

func ghost(pose_global: Dictionary, col: Color) -> void:
	var p := _add(K.GHOST, Vector2.ZERO, Vector2.ZERO, 0.28, col, 1.0)
	p.data = pose_global
	p.drag = 0.0

func trace(a: Vector2, b: Vector2, col: Color, width: float, life: float = 0.25) -> void:
	var p := _add(K.TRACE, a, Vector2.ZERO, life, col, width)
	p.data = b
	p.drag = 0.0

func dust(pos: Vector2, col: Color, count: int = 6) -> void:
	for i in count:
		var dir := Vector2(randf_range(-1, 1), randf_range(-0.5, -0.1)).normalized()
		var p := _add(K.DOT, pos + Vector2(randf_range(-8, 8), 0), dir * randf_range(40, 160), randf_range(0.25, 0.5), col, randf_range(1.0, 2.0))
		p.drag = 5.0

func muzzle(pos: Vector2, dir: Vector2, col: Color) -> void:
	_add(K.FLASH, pos, Vector2.ZERO, 0.05, col, 10.0)
	for i in 3:
		var p := _add(K.SPARK, pos, dir.rotated(randf_range(-0.5, 0.5)) * randf_range(200, 450), 0.08, col, 1.5)
		p.drag = 8.0

func shockwave(pos: Vector2, col: Color, radius: float) -> void:
	_add(K.BANNER_RING, pos, Vector2.ZERO, 0.6, col, radius)
