# Verwaltet alle Projektile. Kollision per Raycast von alter zu neuer Position (kein Durchtunneln bei hohem Tempo).
extends Node2D

const Neon = preload("res://scripts/core/neon.gd")

const MASK_WORLD := 1
const MASK_PLAYER := 2
const MASK_ENEMY := 4

class B:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dmg := 10.0
	var life := 1.0
	var friendly := true
	var pierce := 0
	var bounce := 0
	var explode := 0.0
	var crit := false
	var col := Color.WHITE
	var width := 3.0
	var length := 20.0
	var homing := false
	var chain := 0.0
	var exclude: Array[RID] = []
	var rail := false

var game
var list: Array[B] = []

func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	z_index = 15

func spawn_player(pos: Vector2, vel: Vector2, w: Dictionary, crit: bool) -> void:
	var s: Dictionary = Run.stats
	var b := B.new()
	b.pos = pos
	b.vel = vel
	b.dmg = w["dmg"] * s["dmg_mult"] * (s["crit_mult"] if crit else 1.0)
	b.life = w["life"] * (1.0 + (s["speed_mult"] - 1.0) * 0.5)
	b.friendly = true
	b.pierce = w["pierce"] + s["pierce"]
	b.bounce = s["bounce"]
	b.explode = w["explode"] + s["explode"]
	b.crit = crit
	b.col = Color(1.0, 0.9, 0.5) if crit else w["color"]
	b.width = w["width"] * (1.3 if crit else 1.0)
	b.length = w["length"]
	b.homing = s["homing"]
	b.chain = s["chain"]
	b.rail = w["pierce"] >= 4
	list.append(b)

func spawn_enemy(pos: Vector2, vel: Vector2, dmg: float, col: Color, size: float = 1.0) -> void:
	var b := B.new()
	b.pos = pos
	b.vel = vel
	b.dmg = dmg
	b.life = 4.0
	b.friendly = false
	b.col = col
	b.width = 3.5 * size
	b.length = 16.0 * size
	list.append(b)

func clear() -> void:
	list.clear()

func _physics_process(delta: float) -> void:
	if game == null or game.player == null:
		return
	var space := get_world_2d().direct_space_state
	var player = game.player
	var i := list.size() - 1
	while i >= 0:
		var b := list[i]
		var alive := _step(b, delta, space, player)
		if not alive:
			list[i] = list[list.size() - 1]
			list.pop_back()
		i -= 1
	queue_redraw()

func _step(b: B, delta: float, space: PhysicsDirectSpaceState2D, player) -> bool:
	b.life -= delta
	if b.life <= 0.0:
		if b.explode > 0.0 and b.friendly:
			game.explode(b.pos, b.explode, b.dmg * 0.8)
		return false
	if b.homing:
		var target = game.nearest_enemy(b.pos, 320.0)
		if target:
			var want: Vector2 = (target.global_position - b.pos).normalized() * b.vel.length()
			b.vel = b.vel.lerp(want, clampf(4.0 * delta, 0.0, 1.0)).normalized() * b.vel.length()
	var to := b.pos + b.vel * delta
	var mask := MASK_WORLD | (MASK_ENEMY if b.friendly else MASK_PLAYER)
	var q := PhysicsRayQueryParameters2D.create(b.pos, to, mask, b.exclude)
	q.hit_from_inside = true
	if not b.friendly and player.is_dodging():
		q.collision_mask = MASK_WORLD
	var res := space.intersect_ray(q)
	if res.is_empty():
		if b.rail:
			game.fx.trace(b.pos, to, b.col, b.width * 0.8, 0.22)
		b.pos = to
		return true
	var hit_pos: Vector2 = res["position"]
	var collider = res["collider"]
	if b.rail:
		game.fx.trace(b.pos, hit_pos, b.col, b.width * 0.8, 0.22)
	if b.friendly and collider and collider.is_in_group("enemies"):
		var dir := b.vel.normalized()
		collider.take_damage(b.dmg, dir, b.crit)
		game.fx.hit(hit_pos, b.col, dir)
		if b.chain > 0.0 and randf() < b.chain:
			game.chain_lightning(collider, b.dmg * 0.6)
		if b.explode > 0.0:
			game.explode(hit_pos, b.explode, b.dmg * 0.8)
			return false
		if b.pierce > 0:
			b.pierce -= 1
			b.exclude.append(res["rid"])
			b.pos = hit_pos + dir * 2.0
			return true
		return false
	if not b.friendly and collider == player:
		player.take_damage(b.dmg, b.pos)
		game.fx.hit(hit_pos, b.col, b.vel.normalized())
		return false
	# Wand / Boden
	var n: Vector2 = res["normal"]
	if b.bounce > 0 and n != Vector2.ZERO:
		b.vel = b.vel.bounce(n)
		b.bounce -= 1
		b.pos = hit_pos + n * 2.0
		game.fx.wall_hit(hit_pos, b.col, n)
		return true
	if b.explode > 0.0 and b.friendly:
		game.explode(hit_pos, b.explode, b.dmg * 0.8)
	else:
		game.fx.wall_hit(hit_pos, b.col, n if n != Vector2.ZERO else -b.vel.normalized())
	return false

func _draw() -> void:
	for b in list:
		var dir := b.vel.normalized()
		var tail := b.pos - dir * b.length
		Neon.line(self, tail, b.pos, b.col, b.width, 1.0)
		if not b.friendly:
			Neon.dot(self, b.pos, b.width * 0.9, b.col, 1.0)
		elif b.explode > 0.0:
			Neon.dot(self, b.pos, b.width * 0.8, b.col, 1.0)
