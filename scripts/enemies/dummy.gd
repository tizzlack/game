# Übungspuppe für das Tutorial: steht still, wehrt sich nicht.
extends "res://scripts/enemies/enemy.gd"

var t := 0.0

func _init_stats() -> void:
	kind = "dummy"
	max_hp = 25.0
	contact_dmg = 0.0
	speed = 0.0
	score_value = 10
	credit_value = 2
	activate_dist = 700.0

func _ai(delta: float, _p) -> void:
	t += delta
	velocity.x = 0.0

func _draw() -> void:
	var p := Figure.pose(0.0, 0.0, facing, grounded(), Vector2(facing, -0.4).normalized(), 0.0, 0.0, 0.0, 1.0, {"idle_t": t})
	Figure.draw(self, p, draw_color(), 2.0, 0.8)
	last_pose = p
	# Zielscheibe
	Neon.circle(self, Vector2(0, -2), 16.0 + sin(t * 3.0) * 1.5, Neon.fade(col, 0.5), 1.2, 0.5)
