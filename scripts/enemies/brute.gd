# Koloss: groß, viel Leben, kündigt einen Sturmangriff an und rennt dann los.
extends "res://scripts/enemies/enemy.gd"

var state := "walk"
var state_t := 0.0
var charge_dir := 1.0

func _init_stats() -> void:
	kind = "brute"
	max_hp = 130.0
	contact_dmg = 24.0
	speed = 105.0
	score_value = 70
	credit_value = 9
	radius = 20.0
	shape_size = Vector2(32, 76)
	knock_resist = 0.8

func _ai(delta: float, p) -> void:
	state_t -= delta
	var d: Vector2 = p.global_position - global_position
	match state:
		"walk":
			if absf(d.x) > 6.0:
				facing = signf(d.x)
			var target := facing * speed
			if is_on_floor() and not ground_ahead(facing):
				target = 0.0
			velocity.x = move_toward(velocity.x, target, 900.0 * delta)
			if is_on_wall() and is_on_floor():
				velocity.y = -600.0
			cd -= delta
			if cd <= 0.0 and absf(d.x) < 420.0 and absf(d.y) < 80.0 and is_on_floor():
				state = "windup"
				state_t = 0.55
				velocity.x = 0.0
				Sfx.play_at("charge", global_position, -4.0)
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			if state_t <= 0.0:
				state = "charge"
				state_t = 0.75
				charge_dir = facing
		"charge":
			velocity.x = charge_dir * 560.0 * Run.stats["enemy_speed"]
			if is_on_wall() or not ground_ahead(charge_dir):
				state_t = 0.0
				velocity.x = 0.0
				game.shake(0.2)
			if randf() < 0.5:
				game.fx.dust(global_position + Vector2(0, shape_size.y * 0.5), Neon.fade(col, 0.6), 1)
			if state_t <= 0.0:
				state = "walk"
				cd = randf_range(1.6, 2.6)
	phase += absf(velocity.x) * delta * 0.035

func _draw() -> void:
	var c := draw_color()
	if state == "windup" and fmod(state_t, 0.12) < 0.06:
		c = Color(1.8, 1.8, 1.8)
	var p := Figure.pose(phase, absf(velocity.x) / 160.0, facing, grounded(), Vector2(facing, 0), 0.0, velocity.y, 0.0, 1.42)
	Figure.draw(self, p, c, 3.2, 1.0)
	last_pose = p
	draw_visor(p, Vector2(facing, 0), Color(1.0, 0.85, 0.9))
	# Schulterpanzer
	Neon.line(self, Vector2(-12, -20), Vector2(12, -20), c, 3.0)
