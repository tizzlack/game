# Checkpoint-Bake, Ziel-Lichtsäule und Hinweistexte in der Welt.
extends Node2D

const Neon = preload("res://scripts/core/neon.gd")

var kind := "checkpoint"
var pal: Dictionary
var activated := false
var t := 0.0
var text := ""
var font: Font

func _ready() -> void:
	z_index = 5 if kind != "hint" else 4
	if kind == "hint":
		font = load("res://assets/fonts/MonoFont.ttf")

func activate() -> void:
	activated = true
	t = 0.0

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	match kind:
		"checkpoint": _draw_checkpoint()
		"goal": _draw_goal()
		"hint": _draw_hint()

func _draw_checkpoint() -> void:
	var on := activated
	var c: Color = Color(0.45, 0.8, 1.0) if on else Neon.fade(pal["ground"], 0.45)
	var center := Vector2(0, -30)
	var tip := Vector2(0, -52)
	if on:
		# leuchtende Kapsel
		Neon.halo(self, center, 70.0, Neon.fade(c, 0.5))
		draw_line(Vector2(0, -8), Vector2(0, -50), Neon.fade(c, 0.35), 18.0)
		draw_line(Vector2(0, -10), Vector2(0, -48), Neon.hdr(Color(0.85, 0.95, 1.0), 2.0), 8.0)
		Neon.dot(self, Vector2(0, -10), 4.0, Color(0.85, 0.95, 1.0), 1.0)
		Neon.dot(self, Vector2(0, -48), 4.0, Color(0.85, 0.95, 1.0), 1.0)
		# doppelter Ring, pulsierend
		var k := fmod(t, 1.6) / 1.6
		Neon.circle(self, center, 54.0, Neon.fade(c, 0.55), 1.4, 0.6)
		Neon.circle(self, center, 48.0 + k * 30.0, Neon.fade(c, (1.0 - k) * 0.5), 1.2, 0.4)
	else:
		var cap := PackedVector2Array([Vector2(-5, -8), Vector2(-5, -46), Vector2(0, -52), Vector2(5, -46), Vector2(5, -8), Vector2(-5, -8)])
		Neon.polyline(self, cap, c, 1.6, 0.5)
	if on:
		# Lichtstrahl nach oben, der langsam ausblendet
		var pulse := 0.85 + 0.15 * sin(t * 4.0)
		var steps := 10
		for i in steps:
			var y0 := -52.0 - i * 70.0
			var a := (1.0 - float(i) / steps) * pulse
			draw_rect(Rect2(-7, y0 - 70.0, 14, 70), Neon.fade(c, 0.05 * a))
			draw_rect(Rect2(-1.6, y0 - 70.0, 3.2, 70), Neon.hdr(Neon.fade(c, 0.5 * a), 1.0))
		Neon.halo(self, tip, 40.0, Neon.fade(c, 0.35 * pulse))

func _draw_goal() -> void:
	var c: Color = pal["ground"]
	var a: Color = pal["accent"]
	var pulse := 0.85 + 0.15 * sin(t * 4.0)
	# Säule
	draw_rect(Rect2(-34, -1400, 68, 1400), Neon.fade(c, 0.05 * pulse))
	draw_rect(Rect2(-16, -1400, 32, 1400), Neon.fade(c, 0.1 * pulse))
	draw_rect(Rect2(-5, -1400, 10, 1400), Neon.hdr(Neon.fade(c, 0.55 * pulse), 1.2))
	# Rahmen
	var frame := PackedVector2Array([Vector2(-40, 0), Vector2(-40, -150), Vector2(40, -150), Vector2(40, 0)])
	Neon.polyline(self, frame, c, 2.5)
	Neon.line(self, Vector2(-50, -150), Vector2(50, -150), c, 3.0)
	for i in 3:
		var yy := -40.0 - i * 38.0
		Neon.line(self, Vector2(-40, yy), Vector2(40, yy), Neon.fade(a, 0.4), 1.2, 0.4)
	var k := fmod(t * 0.8, 1.0)
	for j in 2:
		var kk := fmod(k + j * 0.5, 1.0)
		Neon.dot(self, Vector2(0, -kk * 400.0), 3.0, Neon.fade(c, 1.0 - kk), 0.8)

func _draw_hint() -> void:
	var a := 0.55 + 0.25 * sin(t * 2.5)
	var lines := text.split("\n")
	var yy := 0.0
	for ln in lines:
		var w := font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(-w * 0.5, yy), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Neon.hdr(Neon.fade(pal["accent"], a), 0.3))
		yy += 24.0
