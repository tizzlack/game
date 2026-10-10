# Drohne: fliegt, umkreist den Spieler in Abstand und schießt gezielte Einzelschüsse.
extends "res://scripts/enemies/enemy.gd"

var orbit := 0.0
var t := 0.0

func _init_stats() -> void:
	kind = "drone"
	max_hp = 24.0
	contact_dmg = 10.0
	shot_dmg = 9.0
	speed = 230.0
	score_value = 40
	credit_value = 4
	radius = 14.0
	shape_size = Vector2(26, 26)
	uses_gravity = false
	orbit = randf() * TAU

func _ai(delta: float, p) -> void:
	t += delta
	orbit += delta * 0.6
	var target: Vector2 = p.global_position + Vector2(cos(orbit) * 260.0, -170.0 + sin(orbit * 1.3) * 40.0)
	var to := target - global_position
	velocity = velocity.lerp(to.limit_length(speed), clampf(2.5 * delta, 0.0, 1.0))
	aim = (p.global_position - global_position).normalized()
	cd -= delta
	if cd <= 0.0 and global_position.distance_to(p.global_position) < 560.0 and has_los(p.global_position):
		shoot(p.global_position + p.velocity * 0.2, 430.0, 0.0)
		cd = randf_range(1.6, 2.4)

func eye() -> Vector2:
	return global_position

func _draw() -> void:
	var c := draw_color()
	var bob := sin(t * 6.0) * 2.0
	var pts := PackedVector2Array([Vector2(0, -12 + bob), Vector2(13, bob), Vector2(0, 12 + bob), Vector2(-13, bob), Vector2(0, -12 + bob)])
	Neon.polyline(self, pts, c, 2.0)
	Neon.dot(self, Vector2(0, bob) + aim * 4.0, 3.0, c, 1.0)
	var r := sin(t * 40.0) * 10.0
	Neon.line(self, Vector2(-22 - r * 0.3, -6 + bob), Vector2(-8, -6 + bob), Neon.fade(c, 0.7), 1.4, 0.5)
	Neon.line(self, Vector2(8, -6 + bob), Vector2(22 + r * 0.3, -6 + bob), Neon.fade(c, 0.7), 1.4, 0.5)
	if cd < 0.35:
		Neon.circle(self, Vector2(0, bob), 16.0 + cd * 20.0, Neon.fade(c, 0.5), 1.0, 0.4)
