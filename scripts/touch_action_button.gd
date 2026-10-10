extends Control

## One phone action button drawn as a diamond or a circle.
##
## Each finger is tracked by its touch index, so an action can be pressed while
## another finger holds the movement stick. The hit area is exactly the drawn
## shape, so neighbouring diamonds never steal taps from each other. The action
## fires once on press (`button_down`); release only ends the hold.

signal button_down
signal button_up
signal pressed

const ICONS := ["fist", "cross", "bolt", "boot", "spark", "shield", "none"]

var action := ""
var text := ""
var shape := "diamond"
var icon := "none"
var base_color := Color("#239f9b")
## 0 = locked/dim, 1 = available. `charged` adds the animated electric aura.
var available := true
var charged := false
var _touch_index := -1
var _mouse_held := false
var _flash := 0.0
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func configure(action_name: String, title: String, shape_name: String, icon_name: String, color: Color, rect: Rect2) -> void:
	action = action_name
	text = title
	shape = shape_name
	icon = icon_name if icon_name in ICONS else "none"
	base_color = color
	position = rect.position
	size = rect.size
	name = "Touch_" + action_name.capitalize()
	queue_redraw()


func is_held() -> bool:
	return _touch_index != -1 or _mouse_held


func set_state(is_available: bool, is_charged: bool) -> void:
	if available == is_available and charged == is_charged:
		return
	available = is_available
	charged = is_charged
	queue_redraw()


func hit_polygon() -> PackedVector2Array:
	var center := size * 0.5
	if shape == "circle":
		var points := PackedVector2Array()
		var radius := minf(size.x, size.y) * 0.5
		for i in range(24):
			points.append(center + Vector2.RIGHT.rotated(TAU * float(i) / 24.0) * radius)
		return points
	var h := size * 0.5
	return PackedVector2Array([center + Vector2(0, -h.y), center + Vector2(h.x, 0), center + Vector2(0, h.y), center + Vector2(-h.x, 0)])


func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, hit_polygon())


func press() -> void:
	_flash = 1.0
	queue_redraw()
	button_down.emit()


func release() -> void:
	button_up.emit()
	pressed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and _has_point(event.position):
			_touch_index = event.index
			press()
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			release()
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Browsers also emulate a mouse from the first finger. Those events carry
		# the emulation device ID and are ignored, or one tap would act twice.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			accept_event()
			return
		if event.pressed and not _mouse_held and _touch_index == -1:
			_mouse_held = true
			press()
		elif not event.pressed and _mouse_held:
			_mouse_held = false
			release()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and is_held():
		_touch_index = -1
		_mouse_held = false
		button_up.emit()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		queue_redraw()
	elif charged:
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var outline := hit_polygon()
	var fill := base_color
	if not available:
		fill = base_color.darkened(0.55)
		fill.s *= 0.35
	if is_held():
		fill = fill.lightened(0.18)
	fill.a = 0.92 if available else 0.62
	if charged:
		_draw_electric_aura(center)
	draw_colored_polygon(outline, fill.darkened(0.25))
	var inner := PackedVector2Array()
	for point in outline:
		inner.append(center + (point - center) * 0.88)
	draw_colored_polygon(inner, fill)
	var closed := outline.duplicate()
	closed.append(outline[0])
	var rim := base_color.lightened(0.5) if available else Color(0.55, 0.6, 0.64, 0.6)
	if charged:
		rim = Color("#fff3a8").lerp(Color.WHITE, 0.5 + 0.5 * sin(_clock * 9.0))
	draw_polyline(closed, rim, 3.0, true)
	if _flash > 0.0:
		draw_colored_polygon(inner, Color(1, 1, 1, 0.45 * _flash))
	var text_color := Color("#fffaf0") if available else Color(0.78, 0.8, 0.82, 0.75)
	var font := get_theme_default_font()
	var font_size := int(clampf(minf(size.x, size.y) * 0.2, 14.0, 26.0))
	var has_icon := icon != "none"
	var text_y := center.y + (font_size * 0.62 if has_icon else font_size * 0.35)
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, Vector2(center.x - text_width * 0.5, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.02, 0.04, 0.07, 0.85))
	draw_string(font, Vector2(center.x - text_width * 0.5, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	if has_icon:
		_draw_icon(center + Vector2(0, -font_size * 0.55), font_size * 0.62, text_color)


func _draw_icon(at: Vector2, scale_px: float, color: Color) -> void:
	match icon:
		"fist":
			draw_rect(Rect2(at + Vector2(-scale_px * 0.7, -scale_px * 0.45), Vector2(scale_px * 1.4, scale_px * 0.95)), color, true)
			for i in range(4):
				draw_line(at + Vector2(-scale_px * 0.7 + scale_px * 0.35 * (i + 1), -scale_px * 0.45), at + Vector2(-scale_px * 0.7 + scale_px * 0.35 * (i + 1), -scale_px * 0.05), Color(0, 0, 0, 0.35), 1.5)
		"cross":
			draw_line(at + Vector2(-scale_px * 0.55, -scale_px * 0.55), at + Vector2(scale_px * 0.55, scale_px * 0.55), color, 3.0, true)
			draw_line(at + Vector2(scale_px * 0.55, -scale_px * 0.55), at + Vector2(-scale_px * 0.55, scale_px * 0.55), color, 3.0, true)
		"bolt":
			draw_colored_polygon(PackedVector2Array([at + Vector2(scale_px * 0.15, -scale_px * 0.8), at + Vector2(-scale_px * 0.45, scale_px * 0.1), at + Vector2(-scale_px * 0.02, scale_px * 0.1), at + Vector2(-scale_px * 0.2, scale_px * 0.8), at + Vector2(scale_px * 0.45, -scale_px * 0.15), at + Vector2(scale_px * 0.02, -scale_px * 0.15)]), color)
		"boot":
			# Side view of a raised boot: shin, foot and sole.
			draw_colored_polygon(PackedVector2Array([at + Vector2(-scale_px * 0.35, -scale_px * 0.8), at + Vector2(scale_px * 0.05, -scale_px * 0.8), at + Vector2(scale_px * 0.05, scale_px * 0.05), at + Vector2(scale_px * 0.75, scale_px * 0.2), at + Vector2(scale_px * 0.75, scale_px * 0.6), at + Vector2(-scale_px * 0.35, scale_px * 0.6)]), color)
		"spark":
			for i in range(4):
				var direction := Vector2.UP.rotated(PI * 0.5 * float(i))
				draw_colored_polygon(PackedVector2Array([at + direction * scale_px * 0.75, at + direction.rotated(PI * 0.5) * scale_px * 0.16, at - direction.rotated(PI * 0.5) * scale_px * 0.16]), color)
		"shield":
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -scale_px * 0.65), at + Vector2(scale_px * 0.55, -scale_px * 0.4), at + Vector2(scale_px * 0.45, scale_px * 0.25), at + Vector2(0, scale_px * 0.7), at + Vector2(-scale_px * 0.45, scale_px * 0.25), at + Vector2(-scale_px * 0.55, -scale_px * 0.4)]), color)


func _draw_electric_aura(center: Vector2) -> void:
	var radius := minf(size.x, size.y) * 0.5
	var pulse := 0.5 + 0.5 * sin(_clock * 6.0)
	draw_circle(center, radius * (1.08 + 0.06 * pulse), Color(1.0, 0.86, 0.3, 0.16 + 0.12 * pulse))
	# Deterministic jagged arcs that rotate around the button.
	for arc in range(5):
		var start_angle := _clock * 2.4 + TAU * float(arc) / 5.0
		var points := PackedVector2Array()
		for step in range(7):
			var angle := start_angle + float(step) * 0.16
			var jitter := sin(_clock * 31.0 + float(step * 7 + arc * 13)) * radius * 0.09
			points.append(center + Vector2.RIGHT.rotated(angle) * (radius * 1.04 + jitter))
		draw_polyline(points, Color(1.0, 0.97, 0.75, 0.9), 2.0, true)
