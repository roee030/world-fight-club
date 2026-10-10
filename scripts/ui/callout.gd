extends Control

## Animated announcement banner in the console style.
##
## Wraps a Label (the match `message_label`, or its own label for finisher
## captions). Whenever the label's text changes while visible, the banner plays
## an electric entrance: slanted plate, scale punch, white flash and a short
## lightning crackle. Colour and size follow the message: FIGHT!/KO = gold,
## round won = gold, round lost = red, information/feedback = cyan.

const GOLD := Color("#f2c35a")
const CYAN := Color("#59f0ff")
const RED := Color("#ff4d5e")
const COMPACT_SIZE := 16

var label: Label
var accent := CYAN
## Small static readout (combo counter): fixed size, no scale punch or lightning.
var compact := false
var _last_text := ""
var _was_visible := false
var _t := 10.0
var _bolts: Array = []
var _bolt_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _font: Font


func setup(target: Label, font: Font) -> void:
	name = "Callout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = target
	_font = font
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.95))
	label.add_theme_constant_override("outline_size", 10)


static func style_for(text: String) -> Dictionary:
	var upper := text.to_upper()
	if upper.contains(" DMG"):
		return {"accent": GOLD, "size": 34}
	if upper.contains(" HITS"):
		return {"accent": GOLD, "size": 30}
	if upper.contains("BREAK"):
		return {"accent": GOLD, "size": 44}
	if upper.begins_with("FIGHT") or upper.contains("K.O") or upper == "KO":
		return {"accent": GOLD, "size": 68}
	if upper.contains("ROUND FOR YOU") or upper.contains("YOU WIN"):
		return {"accent": GOLD, "size": 50}
	if upper.contains("LOST") or upper.contains("YOU LOSE"):
		return {"accent": RED, "size": 50}
	if upper.contains("NEEDS") or upper.contains("NOT AVAILABLE") or upper.contains("WAIT") or upper.contains("CLOSER") or upper.contains("READY") or upper.contains("SPECIAL"):
		return {"accent": CYAN, "size": 26}
	return {"accent": CYAN, "size": 46}


func _process(delta: float) -> void:
	if label == null:
		return
	var showing := label.visible and not label.text.is_empty()
	if showing and (label.text != _last_text or not _was_visible):
		_restart()
	_was_visible = showing
	_last_text = label.text if showing else ""
	if not showing:
		if visible: queue_redraw()
		return
	_t += delta
	_bolt_timer -= delta
	if compact:
		label.scale = Vector2.ONE
		queue_redraw()
		return
	if _t < 0.45 and _bolt_timer <= 0.0:
		_bolt_timer = 0.05
		_make_bolts()
	var punch := clampf(_t / 0.14, 0.0, 1.0)
	var s := 1.0 + (1.0 - (1.0 - pow(1.0 - punch, 3.0))) * 0.55
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(s, s)
	queue_redraw()


func _restart() -> void:
	var style := style_for(label.text)
	accent = style.accent
	if compact:
		style.size = COMPACT_SIZE
	label.add_theme_font_size_override("font_size", int(style.size))
	label.add_theme_color_override("font_color", Color.WHITE if accent != CYAN or int(style.size) > 30 else Color("#e8fbff"))
	label.add_theme_color_override("font_shadow_color", Color(accent, 0.6))
	label.add_theme_constant_override("shadow_outline_size", 18)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	_t = 0.0
	_rng.seed = hash(label.text)
	_make_bolts()


func plate_rect() -> Rect2:
	# Plate sized to the rendered text, centred on the label.
	var font := label.get_theme_font("font")
	var size_px := label.get_theme_font_size("font_size")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x if font != null else 300.0
	var center := label.get_global_rect().get_center() - get_global_rect().position
	var plate_size := Vector2(minf(width + (36.0 if compact else 120.0), 1100.0), float(size_px) * 1.45)
	return Rect2(center - plate_size * 0.5, plate_size)


func _make_bolts() -> void:
	_bolts.clear()
	if label == null:
		return
	var rect := plate_rect()
	for i in range(5):
		var left_side := i % 2 == 0
		var start := Vector2(rect.position.x if left_side else rect.end.x, rect.position.y + _rng.randf() * rect.size.y)
		var direction := Vector2(-1.0 if left_side else 1.0, _rng.randf_range(-0.6, 0.6)).normalized() * _rng.randf_range(40.0, 110.0)
		var points := PackedVector2Array([start])
		for step in range(1, 6):
			points.append(start + direction * (float(step) / 5.0) + direction.orthogonal().normalized() * _rng.randf_range(-9.0, 9.0))
		_bolts.append(points)


func _draw() -> void:
	if label == null or not label.visible or label.text.is_empty():
		return
	var rect := plate_rect()
	var skew := rect.size.y * 0.35
	var appear := clampf(_t / 0.12, 0.0, 1.0)
	var plate := PackedVector2Array([rect.position + Vector2(skew, 0), Vector2(rect.end.x, rect.position.y), rect.end - Vector2(skew, 0), Vector2(rect.position.x, rect.end.y)])
	draw_colored_polygon(plate, Color(0.02, 0.05, 0.09, 0.78 * appear))
	var rim := plate.duplicate()
	rim.append(plate[0])
	draw_polyline(rim, Color(accent, 0.9 * appear), 3.0, true)
	# Accent bars on the top and bottom edges.
	draw_line(plate[0] + Vector2(10, -6), plate[0] + Vector2(rect.size.x * 0.35, -6), Color(accent, 0.8 * appear), 3.0)
	draw_line(plate[2] - Vector2(10, -6), plate[2] - Vector2(rect.size.x * 0.35, -6), Color(accent, 0.8 * appear), 3.0)
	if compact:
		return
	var flash := maxf(0.0, 0.6 - _t * 4.0)
	if flash > 0.0:
		draw_colored_polygon(plate, Color(1, 1, 1, flash))
	if _t < 0.45:
		for bolt in _bolts:
			draw_polyline(bolt, Color(0.85, 0.98, 1.0, 0.9), 2.0, true)
			draw_polyline(bolt, Color(accent, 0.35), 6.0, true)
