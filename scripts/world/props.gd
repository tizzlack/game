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
	var c: Color = pal["accent"] if activated else Neon.fade(pal["ground"], 0.45)
	Neon.line(self, Vector2(0, 0), Vector2(0, -120), c, 2.0, 0.8 if activated else 0.4)
	Neon.line(self, Vector2(-10, 0), Vector2(10, 0), c, 2.0, 0.6)
	var head := Vector2(0, -126)
	Neon.dot(self, head, 4.0 + (sin(t * 5.0) * 1.0 if activated else 0.0), c, 1.0 if activated else 0.4)
	if activated:
		var k := fmod(t, 1.4) / 1.4
		draw_arc(head, 8.0 + k * 40.0, 0.0, TAU, 32, Neon.fade(c, (1.0 - k) * 0.6), 2.0)
		# Lichtstrahl nach oben
		draw_rect(Rect2(-1.5, -900, 3, 780), Neon.fade(c, 0.12))

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
