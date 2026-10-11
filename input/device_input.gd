extends RefCounted

## Device -> sim input bits (sim/layout.gd). Keyboard and gamepad; touch is
## read by the battle scene from its on-screen widgets.
## Gamepad (Xbox naming, SF layout): X = LP, Y = HP, A = LK, B = HK,
## RB = SP (Easy special), LB or RT = DRIVE, left stick or d-pad = move,
## Start = pause.

const L = preload("res://sim/layout.gd")
const STICK_DEADZONE := 0.45


static func read_keyboard() -> int:
	var bits := 0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): bits |= L.IN_LEFT
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): bits |= L.IN_RIGHT
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): bits |= L.IN_UP
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): bits |= L.IN_DOWN
	if Input.is_key_pressed(KEY_J): bits |= L.IN_LP
	if Input.is_key_pressed(KEY_K): bits |= L.IN_HP
	if Input.is_key_pressed(KEY_U): bits |= L.IN_LK
	if Input.is_key_pressed(KEY_I): bits |= L.IN_HK
	if Input.is_key_pressed(KEY_L): bits |= L.IN_SP
	if Input.is_key_pressed(KEY_O): bits |= L.IN_DRIVE
	return bits


static func read_gamepad(device: int = 0) -> int:
	if not device in Input.get_connected_joypads():
		return 0
	var bits := 0
	var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	if x < -STICK_DEADZONE or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT): bits |= L.IN_LEFT
	if x > STICK_DEADZONE or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT): bits |= L.IN_RIGHT
	if y < -STICK_DEADZONE or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP): bits |= L.IN_UP
	if y > STICK_DEADZONE or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN): bits |= L.IN_DOWN
	if Input.is_joy_button_pressed(device, JOY_BUTTON_X): bits |= L.IN_LP
	if Input.is_joy_button_pressed(device, JOY_BUTTON_Y): bits |= L.IN_HP
	if Input.is_joy_button_pressed(device, JOY_BUTTON_A): bits |= L.IN_LK
	if Input.is_joy_button_pressed(device, JOY_BUTTON_B): bits |= L.IN_HK
	if Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER): bits |= L.IN_SP
	if Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER) or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5: bits |= L.IN_DRIVE
	return bits


static func is_pause_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_P]
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == JOY_BUTTON_START
	return false
