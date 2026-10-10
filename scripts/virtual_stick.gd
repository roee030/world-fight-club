extends Control
class_name VirtualStick

signal axis_changed(value: Vector2)

var axis := Vector2.ZERO
var _finger_index := -1
var _mouse_held := false
var _radius := 74.0


func _ready() -> void:
	custom_minimum_size = Vector2(190, 190)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = DisplayServer.is_touchscreen_available()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger_index == -1:
			_finger_index = event.index
			_update_from_position(event.position)
			accept_event()
		elif not event.pressed and event.index == _finger_index:
			_finger_index = -1
			_set_axis(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag and event.index == _finger_index:
		_update_from_position(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Mouse events emulated from a finger are already handled as touches.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			accept_event()
			return
		if event.pressed and _finger_index == -1:
			_mouse_held = true
			_update_from_position(event.position)
		elif not event.pressed and _mouse_held:
			_mouse_held = false
			_set_axis(Vector2.ZERO)
		accept_event()
	elif event is InputEventMouseMotion and _mouse_held and event.device != InputEvent.DEVICE_ID_EMULATION:
		_update_from_position(event.position)
		accept_event()


func _update_from_position(position: Vector2) -> void:
	var center := size * 0.5
	var offset := position - center
	if offset.length() > _radius:
		offset = offset.normalized() * _radius
	_set_axis(offset / _radius)


func _set_axis(value: Vector2) -> void:
	axis = value.limit_length(1.0)
	axis_changed.emit(axis)
	queue_redraw()


func _draw() -> void:
	# Styled after the HUD reference: a glowing cyan ring, a dark inner plate with
	# faint direction marks, and a small bright thumb nub.
	var center := size * 0.5
	_radius = minf(size.x, size.y) * 0.40
	var cyan := Color(0.36, 0.85, 0.88)
	draw_circle(center, _radius + 16.0, Color(0.02, 0.05, 0.08, 0.50))
	draw_arc(center, _radius + 16.0, 0.0, TAU, 72, Color(cyan, 0.28), 8.0, true)
	draw_arc(center, _radius + 14.0, 0.0, TAU, 72, Color(cyan, 0.85), 2.5, true)
	draw_circle(center, _radius, Color(0.05, 0.10, 0.14, 0.62))
	draw_arc(center, _radius, 0.0, TAU, 64, Color(0.55, 0.70, 0.76, 0.35), 1.5, true)
	draw_arc(center, _radius * 0.55, 0.0, TAU, 48, Color(0.55, 0.70, 0.76, 0.22), 1.0, true)
	var arrow_color := Color(0.70, 0.82, 0.86, 0.45)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction := Vector2.RIGHT.rotated(angle)
		var side := direction.rotated(PI * 0.5)
		var tip := center + direction * (_radius * 0.86)
		draw_polyline(PackedVector2Array([tip - direction * 10.0 + side * 7.0, tip, tip - direction * 10.0 - side * 7.0]), arrow_color, 2.0, true)
	var knob := center + axis * _radius * 0.78
	draw_circle(knob, 20.0, Color(cyan, 0.22))
	draw_circle(knob, 13.0, Color(0.30, 0.88, 0.90, 0.95))
	draw_arc(knob, 13.0, 0.0, TAU, 32, Color(0.90, 1.0, 1.0, 0.9), 2.0, true)
