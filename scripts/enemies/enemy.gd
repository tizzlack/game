# Basisklasse aller Gegner: Leben, Treffer-Feedback, Schwerkraft, Sichtlinie, Kontaktschaden, Tod.
extends CharacterBody2D

const Neon = preload("res://scripts/core/neon.gd")
const Figure = preload("res://scripts/core/figure.gd")

var game
var kind := "enemy"
var max_hp := 30.0
var hp := 30.0
var contact_dmg := 12.0
var shot_dmg := 10.0
var speed := 150.0
var score_value := 25
var credit_value := 3
var radius := 14.0
var col := Color(1, 0.25, 0.38)
var uses_gravity := true
var activate_dist := 950.0
var active := false
var dead := false
var flash := 0.0
var facing := -1.0
var phase := 0.0
var aim := Vector2.LEFT
var diff := 0.0
var cd := 0.0
var shape_size := Vector2(22, 54)
var is_boss := false
var knock_resist := 0.0
var last_pose: Dictionary = {}
# Multiplayer
var net_id := -1
var puppet := false  # Client: folgt nur den Schnappschüssen des Hosts
var last_hitter := 1
var pending_hitter := 0
var snap_pos := Vector2.ZERO
var snap_floor := false
var has_snap := false

func setup(g, difficulty: float, color: Color) -> void:
	game = g
	diff = difficulty
	col = color
	_init_stats()
	max_hp *= 1.0 + 0.3 * diff
	hp = max_hp
	contact_dmg *= 1.0 + 0.12 * diff
	shot_dmg *= 1.0 + 0.12 * diff
	speed *= Run.stats["enemy_speed"]
	if Net.active and not Run.net_mode == "versus":
		max_hp *= 1.0 + 0.55 * (Net.player_count() - 1)
		hp = max_hp
	credit_value = int(round(credit_value * (1.0 + 0.15 * diff)))

func _init_stats() -> void:
	pass

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 8
	add_to_group("enemies")
	var shape := CollisionShape2D.new()
	if shape_size.x == shape_size.y:
		var c := CircleShape2D.new()
		c.radius = shape_size.x * 0.5
		shape.shape = c
	else:
		var cap := CapsuleShape2D.new()
		cap.radius = shape_size.x * 0.5
		cap.height = shape_size.y
		shape.shape = cap
	add_child(shape)
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 10.0
	z_index = 11
	cd = randf_range(0.6, 1.6)

func grounded() -> bool:
	return snap_floor if puppet else is_on_floor()

func _physics_process(delta: float) -> void:
	if dead or game == null:
		return
	if puppet:
		_puppet_step(delta)
		return
	var p = game.target_for(global_position)
	if not active:
		if p and global_position.distance_to(p.global_position) < activate_dist:
			active = true
			_on_activate()
		else:
			return
	flash = maxf(0.0, flash - delta)
	if uses_gravity:
		velocity.y = minf(velocity.y + 1900.0 * delta, 1100.0)
	if p and not p.dead:
		_ai(delta, p)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	move_and_slide()
	if contact_dmg > 0.0 and p and not p.dead:
		var d: Vector2 = p.global_position - global_position
		if absf(d.x) < radius + 10.0 and absf(d.y) < shape_size.y * 0.5 + 24.0:
			p.take_damage(contact_dmg, global_position)
	if global_position.y > game.kill_y:
		die(false)
	queue_redraw()

func _on_activate() -> void:
	pass

func _ai(_delta: float, _p) -> void:
	pass

func eye() -> Vector2:
	return global_position + Vector2(0, -14)

func has_los(target: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(eye(), target, 1)
	return space.intersect_ray(q).is_empty()

func ground_ahead(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * (radius + 8.0), 0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, shape_size.y * 0.5 + 50.0), 1 | 8)
	return not space.intersect_ray(q).is_empty()

func take_damage(amount: float, dir: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if dead:
		return
	if puppet:
		# Client: Treffer sofort zeigen, Schaden rechnet der Host
		flash = 0.06
		game.fx.number(global_position + Vector2(randf_range(-8, 8), -shape_size.y * 0.5), amount, crit)
		Sfx.play_at("crit" if crit else "hit", global_position, -8.0)
		Net.hit_enemy.rpc_id(1, net_id, amount, dir, crit)
		return
	last_hitter = pending_hitter if pending_hitter > 0 else Net.my_id()
	pending_hitter = 0
	hp -= amount
	flash = 0.06
	if dir != Vector2.ZERO and knock_resist < 1.0:
		velocity += dir * 90.0 * (1.0 - knock_resist)
	game.fx.number(global_position + Vector2(randf_range(-8, 8), -shape_size.y * 0.5), amount, crit)
	Sfx.play_at("crit" if crit else "hit", global_position, -8.0)
	if not active:
		active = true
		_on_activate()
	if hp <= 0.0:
		die(true)

func die(reward: bool) -> void:
	if dead or puppet:
		return
	dead = true
	if not last_pose.is_empty():
		game.fx.shatter(Figure.to_global(last_pose, global_transform), col, global_position + Vector2(0, 10))
	game.on_enemy_killed(self, reward)
	queue_free()

func shoot(target: Vector2, bullet_speed: float, spread_deg: float = 0.0, count: int = 1, size: float = 1.0) -> void:
	var origin := eye() + (target - eye()).normalized() * (radius + 10.0)
	var base := (target - origin).angle()
	for i in count:
		var off := 0.0
		if count > 1:
			off = deg_to_rad(lerpf(-spread_deg, spread_deg, float(i) / (count - 1)))
		else:
			off = deg_to_rad(randf_range(-spread_deg, spread_deg))
		game.bullets.spawn_enemy(origin, Vector2.from_angle(base + off) * bullet_speed, shot_dmg, col, size)
	game.fx.muzzle(origin, (target - origin).normalized(), col)
	Sfx.play_at("enemy_shoot", global_position, -6.0)

func draw_color() -> Color:
	if flash > 0.0:
		return col.lerp(Color(1.4, 1.4, 1.4), 0.55)
	return col

# --- Multiplayer: Schnappschüsse ---
func net_snapshot() -> PackedFloat32Array:
	var sc := 0
	var st_v = get("state")
	if st_v != null:
		sc = int(game.STATE_CODES.get(st_v, 0))
	var stt = get("state_t")
	var ex := _snap_extra()
	return PackedFloat32Array([net_id, global_position.x, global_position.y, velocity.x, velocity.y, facing, aim.x, aim.y,
		sc, float(stt) if stt != null else 0.0, 1.0 if is_on_floor() else 0.0, hp / max_hp, ex.x, ex.y])

func _snap_extra() -> Vector2:
	return Vector2.ZERO

func apply_snapshot(d: PackedFloat32Array) -> void:
	snap_pos = Vector2(d[1], d[2])
	velocity = Vector2(d[3], d[4])
	facing = d[5]
	aim = Vector2(d[6], d[7])
	if get("state") != null:
		for k in game.STATE_CODES:
			if game.STATE_CODES[k] == int(d[8]):
				set("state", k)
				break
	if get("state_t") != null:
		set("state_t", d[9])
	if get("target_pos") != null:
		set("target_pos", global_position + aim * 300.0)
	snap_floor = d[10] > 0.5
	hp = d[11] * max_hp
	_apply_extra(Vector2(d[12], d[13]))
	if not has_snap:
		global_position = snap_pos
		has_snap = true
	if not active:
		active = true

func _apply_extra(_ex: Vector2) -> void:
	pass

func _puppet_step(delta: float) -> void:
	if not active:
		return
	flash = maxf(0.0, flash - delta)
	snap_pos += velocity * delta
	global_position = global_position.lerp(snap_pos, clampf(14.0 * delta, 0.0, 1.0))
	if global_position.distance_to(snap_pos) > 200.0:
		global_position = snap_pos
	phase += absf(velocity.x) * delta * 0.05
	if get("t") != null:
		set("t", float(get("t")) + delta)
	var p = game.player
	if contact_dmg > 0.0 and p and not p.dead:
		var d: Vector2 = p.global_position - global_position
		if absf(d.x) < radius + 10.0 and absf(d.y) < shape_size.y * 0.5 + 24.0:
			p.take_damage(contact_dmg, global_position)
	_puppet_extra(delta)
	queue_redraw()

func _puppet_extra(_delta: float) -> void:
	pass

# Vom Host gemeldeter Tod
func die_remote(killer: int, reward: bool) -> void:
	if dead:
		return
	dead = true
	if not last_pose.is_empty():
		game.fx.shatter(Figure.to_global(last_pose, global_transform), col, global_position + Vector2(0, 10))
	game.on_enemy_killed(self, reward, killer)
	queue_free()

# Leuchtendes Visier im Kopf, zeigt die Blickrichtung
func draw_visor(p: Dictionary, dir: Vector2, c: Color) -> void:
	var h: Vector2 = p["head"]
	var r: float = p["head_r"]
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2(facing, 0)
	draw_line(h + d * r * 0.1 + Vector2(0, -1), h + d * r * 0.95 + Vector2(0, -1), Neon.hdr(c, 1.6), 2.0)

# Zielhilfe-Linie vor einem Schuss
func draw_telegraph(target_local: Vector2, strength: float) -> void:
	var from := Vector2(0, -14)
	var dir := (target_local - from).normalized()
	var flick := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.05)
	var c := Neon.fade(col, strength * (0.25 + 0.35 * flick))
	var n := 14
	for i in n:
		var a := from + dir * (radius + 12.0 + i * 22.0)
		draw_line(a, a + dir * 11.0, c, 1.5)
