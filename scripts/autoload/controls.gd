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

# Rechter Stick zum Zielen; bleibt bei der letzten Richtung, wenn losgelassen.
# Zielhilfe: Gegner in einem schmalen Kegel um die Stick-Richtung werden leicht angezogen.
func aim_vector(from: Vector2 = Vector2.ZERO, game = null) -> Vector2:
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if v.length() > 0.3:
		stick_aim = v.normalized()
	else:
		var m := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), 0.0)
		if absf(m.x) > 0.4:
			stick_aim = Vector2(signf(m.x), 0.0)
	if game != null and Save.setting("aim_assist"):
		var best := stick_aim
		var best_score := 0.0
		for e in game.enemies:
			if not is_instance_valid(e) or e.dead or not e.active:
				continue
			var to: Vector2 = e.global_position - (from + Vector2(0, -12))
			var d := to.length()
			if d > 700.0 or d < 1.0:
				continue
			var dot := stick_aim.dot(to / d)
			if dot > 0.94:
				var sc := dot - d / 7000.0
				if sc > best_score:
					best_score = sc
					best = to / d
		if best_score > 0.0:
			return stick_aim.lerp(best, 0.65).normalized()
	return stick_aim

func rumble(strength: float, duration: float) -> void:
	if not using_gamepad or not Save.setting("vibration"):
		return
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, clampf(strength * 0.6, 0.0, 1.0), clampf(strength, 0.0, 1.0), duration)

# Kurzname für Buttons in Hinweisen, je nach Gerät
func prompt(action: String) -> String:
	var pad := {"jump": "A", "shoot": "RT", "dash": "B", "pause": "START", "reroll": "Y", "move_down": "↓", "move": "L-STICK", "aim": "R-STICK"}
	var kb := {"jump": "SPACE", "shoot": "LMB", "dash": "SHIFT", "pause": "ESC", "reroll": "R", "move_down": "S", "move": "A / D", "aim": "MOUSE"}
	return (pad if using_gamepad else kb).get(action, action)
