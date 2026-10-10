# Spielfigur: Laufen, Springen (Coyote-Time, Sprungpuffer, Doppelsprung), Dash, Zielen, Schießen.
extends CharacterBody2D

const Neon = preload("res://scripts/core/neon.gd")
const Figure = preload("res://scripts/core/figure.gd")
const Data = preload("res://scripts/core/data.gd")

signal died

const GRAVITY := 1900.0
const MAX_FALL := 1150.0
const RUN_SPEED := 340.0
const ACCEL_GROUND := 3400.0
const ACCEL_AIR := 2100.0
const FRICTION := 3000.0
const JUMP_V := 740.0
const AIR_JUMP_V := 650.0
const COYOTE := 0.11
const BUFFER := 0.13
const DASH_SPEED := 760.0
const DASH_TIME := 0.17
const DASH_CD := 0.85

var game
var color := Color(0.75, 0.9, 1.0)
var weapon: Dictionary
var hp := 100.0
var invuln := 0.0
var coyote_t := 0.0
var buffer_t := 0.0
var air_jumps_left := 0
var dash_t := 0.0
var dash_cd_t := 0.0
var dash_dir := 1.0
var dash_hits: Array = []
var fire_cd := 0.0
var aim := Vector2.RIGHT
var aim_override := Vector2.ZERO  # für den Testbot
var facing := 1.0
var run_phase := 0.0
var land_squash := 0.0
var recoil := 0.0
var shield_ready := false
var shield_t := 0.0
var drop_t := 0.0
var safe_pos := Vector2.ZERO
var ground_time := 0.0
var ghost_t := 0.0
var frozen := false
var dead := false
var hurt_flash := 0.0
var was_on_floor := false
var god := false  # Testmodus

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 11.0
	cap.height = 54.0
	shape.shape = cap
	add_child(shape)
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 12.0
	floor_constant_speed = true
	z_index = 12
	safe_pos = global_position
	weapon = Data.WEAPONS[Run.weapon_id]
	hp = Run.hp
	shield_ready = Run.stats["shield"] > 0

func max_hp() -> float:
	return Run.stats["max_hp"]

func dash_ready_ratio() -> float:
	return 1.0 - clampf(dash_cd_t / (DASH_CD * Run.stats["dash_cd_mult"]), 0.0, 1.0)

func is_dodging() -> bool:
	return dash_t > 0.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	var s: Dictionary = Run.stats
	invuln = maxf(0.0, invuln - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	dash_cd_t = maxf(0.0, dash_cd_t - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	buffer_t = maxf(0.0, buffer_t - delta)
	coyote_t = maxf(0.0, coyote_t - delta)
	land_squash = maxf(0.0, land_squash - delta * 4.0)
	recoil = maxf(0.0, recoil - delta * 10.0)
	if s["shield"] > 0 and not shield_ready:
		shield_t -= delta
		if shield_t <= 0.0:
			shield_ready = true
			game.fx.ring(global_position, color, 40.0, 0.4)
	if drop_t > 0.0:
		drop_t -= delta
		if drop_t <= 0.0:
			set_collision_mask_value(4, true)

	var input_x := 0.0 if frozen else Input.get_axis("move_left", "move_right")
	_update_aim()
	if not frozen and Input.is_action_just_pressed("jump"):
		buffer_t = BUFFER
	var on_floor := is_on_floor()
	if on_floor:
		coyote_t = COYOTE
		air_jumps_left = s["air_jumps"]

	if dash_t > 0.0:
		dash_t -= delta
		velocity = Vector2(dash_dir * DASH_SPEED, 0.0)
		ghost_t -= delta
		if ghost_t <= 0.0:
			ghost_t = 0.025
			game.fx.ghost(Figure.to_global(_pose(), global_transform), color)
		if s["dash_dmg"] > 0.0:
			for e in game.enemies_near(global_position, 40.0):
				if not e in dash_hits:
					dash_hits.append(e)
					e.take_damage(s["dash_dmg"] * s["dmg_mult"], Vector2(dash_dir, -0.3).normalized(), false)
	else:
		var target := input_x * RUN_SPEED * s["move_mult"]
		var accel := ACCEL_GROUND if on_floor else ACCEL_AIR
		if absf(input_x) < 0.1 and on_floor:
			accel = FRICTION
		velocity.x = move_toward(velocity.x, target, accel * delta)
		velocity.y = minf(velocity.y + GRAVITY * s["grav_mult"] * delta, MAX_FALL)
		if buffer_t > 0.0 and Input.is_action_pressed("move_down") and on_floor and _on_ledge():
			drop_t = 0.25
			buffer_t = 0.0
			set_collision_mask_value(4, false)
			position.y += 2.0
		elif buffer_t > 0.0:
			if coyote_t > 0.0:
				_jump(JUMP_V)
				coyote_t = 0.0
			elif air_jumps_left > 0:
				air_jumps_left -= 1
				_jump(AIR_JUMP_V)
				game.fx.ring(global_position + Vector2(0, 24), color, 30.0, 0.3)
		if not frozen and Input.is_action_just_released("jump") and velocity.y < -250.0:
			velocity.y *= 0.5
		if not frozen and Input.is_action_just_pressed("dash") and dash_cd_t <= 0.0:
			_start_dash(input_x)

	move_and_slide()

	on_floor = is_on_floor()
	if on_floor and not was_on_floor:
		land_squash = 1.0
		game.fx.dust(global_position + Vector2(0, 27), Neon.fade(color, 0.6), 5)
		Sfx.play("land", -14.0)
	was_on_floor = on_floor
	if on_floor:
		run_phase += absf(velocity.x) * delta * 0.045
		ground_time += delta
		if ground_time > 0.25 and _solid_below():
			safe_pos = global_position
			ground_time = 0.0
	else:
		ground_time = 0.0

	if not frozen and Input.is_action_pressed("shoot") and fire_cd <= 0.0:
		_shoot()
	queue_redraw()

func _update_aim() -> void:
	if aim_override != Vector2.ZERO:
		aim = aim_override.normalized()
	elif Controls.using_gamepad:
		aim = Controls.aim_vector()
	else:
		var m := get_global_mouse_position() - (global_position + Vector2(0, -12))
		if m.length() > 4.0:
			aim = m.normalized()
	if absf(aim.x) > 0.05:
		facing = signf(aim.x)

func _jump(v: float) -> void:
	velocity.y = -v
	buffer_t = 0.0
	Sfx.play("jump", -10.0)
	game.fx.dust(global_position + Vector2(0, 27), Neon.fade(color, 0.5), 4)

func _start_dash(input_x: float) -> void:
	dash_dir = signf(input_x) if absf(input_x) > 0.2 else facing
	dash_t = DASH_TIME
	dash_cd_t = DASH_CD * Run.stats["dash_cd_mult"]
	dash_hits.clear()
	Sfx.play("dash", -6.0)
	game.shake(0.12)

func _on_ledge() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c and c.is_in_group("ledge"):
			return true
	return false

# Sicherer Rücksetzpunkt: fester Boden direkt unter der Figur, nicht am Abgrund
func _solid_below() -> bool:
	var space := get_world_2d().direct_space_state
	for ox in [-26.0, 26.0]:
		var from := global_position + Vector2(ox, 0)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 60), 1)
		if space.intersect_ray(q).is_empty():
			return false
	return true

func gun_tip() -> Vector2:
	return global_position + Vector2(0, -14) + aim * (27.0 + weapon["length"] * 0.4)

func _shoot() -> void:
	var s: Dictionary = Run.stats
	var rate: float = weapon["rate"] * s["rate_mult"]
	if s["adrenaline"] and hp < max_hp() * 0.35:
		rate *= 1.4
	fire_cd = 1.0 / rate
	var base_count: int = weapon["count"]
	var count: int = base_count + s["extra_proj"]
	var origin := gun_tip()
	var spread: float = weapon["spread"]
	var speed: float = weapon["speed"] * s["speed_mult"]
	for i in count:
		var ang := aim.angle()
		if base_count == 1 and count > 1:
			ang += deg_to_rad((i - (count - 1) * 0.5) * 7.0) + deg_to_rad(randf_range(-spread, spread) * 0.5)
		else:
			ang += deg_to_rad(randf_range(-spread, spread))
		var crit := randf() < s["crit"]
		game.bullets.spawn_player(origin, Vector2.from_angle(ang) * speed * randf_range(0.94, 1.06), weapon, crit)
	game.fx.muzzle(origin, aim, weapon["color"])
	Sfx.play(weapon["sfx"], -7.0)
	recoil = 1.0
	if weapon["shake"] > 0.0:
		game.shake(weapon["shake"])
	if base_count > 1 and not is_on_floor():
		velocity -= aim * 120.0  # Rückstoß der Streukanone in der Luft

func take_damage(amount: float, from_pos: Vector2) -> void:
	if dead or invuln > 0.0 or dash_t > 0.0 or frozen or god:
		return
	if shield_ready:
		shield_ready = false
		shield_t = 12.0 / Run.stats["shield"]
		invuln = 0.6
		game.fx.ring(global_position, color, 60.0, 0.5)
		game.fx.sparks(global_position, color, 14, 400.0)
		Sfx.play("shield", -3.0)
		return
	var dmg: float = amount * Run.stats["dmg_taken"]
	hp -= dmg
	Run.section_damage += dmg
	invuln = 0.9
	hurt_flash = 0.3
	var dir := signf(global_position.x - from_pos.x)
	if dir == 0.0:
		dir = -facing
	velocity = Vector2(dir * 320.0, -320.0)
	game.shake(0.5)
	game.hitstop(0.05)
	game.on_player_hurt(dmg)
	Sfx.play("hurt", -2.0)
	game.fx.sparks(global_position, Color(1, 0.3, 0.3), 12, 380.0)
	if hp <= 0.0:
		hp = 0.0
		_die()

func heal(amount: float) -> void:
	if dead:
		return
	var before := hp
	hp = minf(max_hp(), hp + amount)
	if hp > before:
		game.fx.text(global_position + Vector2(0, -50), "+%d" % int(hp - before), Color(0.4, 1.0, 0.5), 16.0)

func _die() -> void:
	dead = true
	visible = false
	set_physics_process(false)
	game.fx.explosion(global_position, color, 1.6)
	died.emit()

func revive(at: Vector2, hp_ratio: float) -> void:
	dead = false
	visible = true
	set_physics_process(true)
	global_position = at
	velocity = Vector2.ZERO
	hp = max_hp() * hp_ratio
	invuln = 2.0
	game.fx.ring(global_position, color, 90.0, 0.6)

func respawn_safe(damage: float) -> void:
	global_position = safe_pos + Vector2(0, -10)
	velocity = Vector2.ZERO
	invuln = 0.0
	take_damage(damage, global_position + Vector2(facing * -10, 0))
	if not dead:
		invuln = 1.2
		game.fx.ring(global_position, color, 70.0, 0.5)

func _pose() -> Dictionary:
	var md := signf(velocity.x) if absf(velocity.x) > 20.0 else facing
	var p := Figure.pose(run_phase, absf(velocity.x) / RUN_SPEED, md, is_on_floor() or dash_t > 0.0, aim, 10.0 + weapon["length"] * 0.4, velocity.y, recoil)
	if land_squash > 0.0:
		var sq := 1.0 - land_squash * 0.12
		for seg in p["segs"]:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			seg[0] = Vector2(a.x, 27.0 - (27.0 - a.y) * sq)
			seg[1] = Vector2(b.x, 27.0 - (27.0 - b.y) * sq)
		var h: Vector2 = p["head"]
		p["head"] = Vector2(h.x, 27.0 - (27.0 - h.y) * sq)
	return p

func _draw() -> void:
	var c := color
	if hurt_flash > 0.0:
		c = c.lerp(Color(1, 0.25, 0.25), hurt_flash / 0.3)
	if invuln > 0.0 and fmod(invuln, 0.16) < 0.08:
		c = Neon.fade(c, 0.35)
	if dash_t > 0.0:
		c = Neon.hdr(c, 0.4)
	Figure.draw(self, _pose(), c, 2.3, 1.1)
	if shield_ready:
		draw_arc(Vector2(0, -2), 34.0, 0.0, TAU, 32, Neon.fade(color, 0.25 + 0.1 * sin(Time.get_ticks_msec() * 0.006)), 1.5)
