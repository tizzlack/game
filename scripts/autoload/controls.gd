# Legt alle Eingabe-Aktionen im Code an (Tastatur, Maus, Gamepad) und merkt sich das zuletzt benutzte Gerät.
extends Node

var using_gamepad := false
var stick_aim := Vector2.RIGHT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("jump", [KEY_SPACE, KEY_W, KEY_UP], [JOY_BUTTON_A], [])
	_action("shoot", [KEY_J], [JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], [MOUSE_BUTTON_LEFT])
	_action("dash", [KEY_SHIFT, KEY_K], [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER], [[JOY_AXIS_TRIGGER_LEFT, 1.0]], [MOUSE_BUTTON_RIGHT])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_action("reroll", [KEY_R], [JOY_BUTTON_Y], [])

func _action(name: String, keys: Array, buttons: Array, axes: Array, mouse: Array = []) -> void:
	if InputMap.has_action(name):
		InputMap.erase_action(name)
	InputMap.add_action(name, 0.35)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(name, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(name, e)
	for m in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = m
		InputMap.action_add_event(name, e)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		using_gamepad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		using_gamepad = true
	elif event is InputEventMouseMotion and event.relative.length() > 2.0:
		using_gamepad = false
	elif event is InputEventKey or event is InputEventMouseButton:
		using_gamepad = false

# Rechter Stick zum Zielen; bleibt bei der letzten Richtung, wenn losgelassen
func aim_vector() -> Vector2:
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if v.length() > 0.3:
		stick_aim = v.normalized()
	else:
		var m := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), 0.0)
		if absf(m.x) > 0.4:
			stick_aim = Vector2(signf(m.x), 0.0)
	return stick_aim
