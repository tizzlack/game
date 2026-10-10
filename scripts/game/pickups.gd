# Credits (Münzen) und Heilung. Werden vom Spieler magnetisch angezogen.
extends Node2D

const Neon = preload("res://scripts/core/neon.gd")

class C:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var heal := false
	var value := 1
	var t := 0.0
	var magnet := false
	var phase := 0.0
	var life := -1.0

var game
var list: Array[C] = []
var coin_streak := 0
var streak_t := 0.0
var time := 0.0
const COIN_COL := Color(1.0, 0.82, 0.3)
const HEAL_COL := Color(0.35, 1.0, 0.5)

func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	z_index = 10

func place_coin(pos: Vector2) -> void:
	var c := C.new()
	c.pos = pos
	c.phase = randf() * TAU
	list.append(c)

func drop_coins(pos: Vector2, total: int) -> void:
	var n := clampi(total, 1, 12)
	var per := maxi(1, int(round(float(total) / n)))
	for i in n:
		var c := C.new()
		c.pos = pos
		c.vel = Vector2.from_angle(randf_range(-PI * 0.9, -PI * 0.1)) * randf_range(150, 380)
		c.value = per
		c.phase = randf() * TAU
		c.life = 14.0
		list.append(c)

func drop_heal(pos: Vector2) -> void:
	var c := C.new()
	c.pos = pos
	c.vel = Vector2(randf_range(-80, 80), -260)
	c.heal = true
	c.value = 15
	c.life = 14.0
	list.append(c)

func clear() -> void:
	list.clear()

func _physics_process(delta: float) -> void:
	time += delta
	streak_t -= delta
	if streak_t <= 0.0:
		coin_streak = 0
	if game == null or game.player == null:
		return
	var player = game.player
	var pp: Vector2 = player.global_position
	var mr: float = 120.0 * Run.stats["magnet"]
	var i := list.size() - 1
	while i >= 0:
		var c := list[i]
		c.t += delta
		var gone := false
		if c.life > 0.0 and c.t > c.life:
			gone = true
		else:
			var dist := c.pos.distance_to(pp)
			if not player.dead and c.t > 0.3 and dist < mr:
				c.magnet = true
			if c.magnet and not player.dead:
				var want := (pp - c.pos).normalized() * (500.0 + c.t * 300.0)
				c.vel = c.vel.lerp(want, clampf(10.0 * delta, 0.0, 1.0))
			else:
				c.vel *= exp(-3.5 * delta)
			c.pos += c.vel * delta
			if not player.dead and dist < 26.0:
				_collect(c, player)
				gone = true
		if gone:
			list[i] = list[list.size() - 1]
			list.pop_back()
		i -= 1
	queue_redraw()

func _collect(c: C, player) -> void:
	if c.heal:
		var amount: float = c.value * Run.stats["heal_mult"]
		if amount > 0.0:
			player.heal(amount)
		Sfx.play("heal", -4.0)
		return
	var v := int(ceil(c.value * Run.stats["credit_mult"]))
	Run.credits += v
	coin_streak += 1
	streak_t = 0.6
	Sfx.play("coin", -9.0, 1.0 + minf(coin_streak, 12) * 0.04, 0.02)
	game.fx.sparks(c.pos, COIN_COL, 2, 120.0)

func _draw() -> void:
	for c in list:
		var bob := Vector2(0, sin(time * 3.0 + c.phase) * 3.0) if not c.magnet else Vector2.ZERO
		var p := c.pos + bob
		var blink := 1.0
		if c.life > 0.0 and c.life - c.t < 3.0:
			blink = 0.3 if fmod(c.t * 8.0, 1.0) < 0.5 else 1.0
		if c.heal:
			var col := Neon.fade(HEAL_COL, blink)
			Neon.line(self, p + Vector2(-6, 0), p + Vector2(6, 0), col, 2.5)
			Neon.line(self, p + Vector2(0, -6), p + Vector2(0, 6), col, 2.5)
		else:
			var s := 4.0 + minf(c.value, 6) * 0.4
			var w := absf(cos(time * 4.0 + c.phase)) * s
			var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(w, 0), p + Vector2(0, s), p + Vector2(-w, 0), p + Vector2(0, -s)])
			Neon.polyline(self, pts, Neon.fade(COIN_COL, blink), 1.6, 0.9)
