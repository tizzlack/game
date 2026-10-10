# Geschütz: steht fest, dreht den Lauf zum Spieler und feuert 3er-Salven.
extends "res://scripts/enemies/enemy.gd"

var state := "idle"
var state_t := 0.0
var shots_left := 0

func _init_stats() -> void:
	kind = "turret"
	max_hp = 70.0
	contact_dmg = 10.0
	shot_dmg = 9.0
	speed = 0.0
	score_value = 45
	credit_value = 6
	radius = 18.0
	shape_size = Vector2(36, 36)
	knock_resist = 1.0

func eye() -> Vector2:
	return global_position + Vector2(0, -6)

func _ai(delta: float, p) -> void:
	velocity.x = 0.0
	var to_p: Vector2 = p.global_position - eye()
	aim = aim.lerp(to_p.normalized(), 3.0 * delta).normalized()
	state_t -= delta
	match state:
		"idle":
			cd -= delta
			if cd <= 0.0 and to_p.length() < 650.0 and has_los(p.global_position):
				state = "fire"
				shots_left = 3 + int(minf(diff, 4.0) * 0.5)
				state_t = 0.35
		"fire":
			if state_t <= 0.0:
				shoot(eye() + aim * 100.0, 500.0, 3.0)
				shots_left -= 1
				state_t = 0.13
				if shots_left <= 0:
					state = "idle"
					cd = randf_range(1.8, 2.6)

func _draw() -> void:
	var c := draw_color()
	var base := PackedVector2Array([Vector2(-18, 18), Vector2(-14, -2), Vector2(14, -2), Vector2(18, 18), Vector2(-18, 18)])
	Neon.polyline(self, base, c, 2.2)
	Neon.circle(self, Vector2(0, -6), 9.0, c, 2.0)
	Neon.line(self, Vector2(0, -6) + aim * 8.0, Vector2(0, -6) + aim * 28.0, c, 3.5)
	if state == "fire" or (state == "idle" and cd < 0.3):
		Neon.dot(self, Vector2(0, -6), 3.0, c, 1.0)
