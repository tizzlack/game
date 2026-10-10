# Fadenkreuz statt Mauszeiger während des Spiels.
extends Node2D

const Neon = preload("res://scripts/core/neon.gd")

var game

func _process(_d: float) -> void:
	visible = game != null and game.overlay == null and game.state in ["play", "boss_dead"] and not Controls.using_gamepad
	if visible:
		position = get_viewport().get_mouse_position()
	queue_redraw()

func _draw() -> void:
	var c := Color(0.8, 0.95, 1.0, 0.9)
	var r := 9.0
	if game and game.player and game.player.fire_cd > 0.0:
		r = 11.0
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		Neon.line(self, d * (r - 4.0), d * (r + 5.0), c, 1.6, 0.6)
	draw_circle(Vector2.ZERO, 1.5, Neon.hdr(c, 0.5))
