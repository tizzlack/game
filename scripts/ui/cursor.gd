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
	var c := Color(0.75, 0.85, 1.0, 0.85)
	var r := 8.0
	if game and game.player and game.player.fire_cd > 0.0:
		r = 9.5
	Neon.line(self, Vector2(-r, 0), Vector2(r, 0), c, 1.5, 0.5)
	Neon.line(self, Vector2(0, -r), Vector2(0, r), c, 1.5, 0.5)
