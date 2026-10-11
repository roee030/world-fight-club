extends SceneTree

## Gamepad and keyboard readers return sim input bits; Start / Esc pause.

const DeviceInput = preload("res://input/device_input.gd")
const L = preload("res://sim/layout.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	# (Key state itself comes from the OS keyboard, which a headless test cannot press.)
	if DeviceInput.read_keyboard() != 0:
		return _fail("no keys are held in a headless run")
	var pause_key := InputEventKey.new()
	pause_key.keycode = KEY_ESCAPE
	pause_key.pressed = true
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	if not DeviceInput.is_pause_event(pause_key) or not DeviceInput.is_pause_event(start):
		return _fail("Esc and gamepad Start must pause")
	if DeviceInput.read_gamepad(7) != 0:
		return _fail("a disconnected gamepad must read as no input")
	print("PASS: device input (keyboard, gamepad mapping, pause events)")
	quit()
