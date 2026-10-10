extends Range

## Segmented, slanted fighting-game bar (health or Special Energy).
##
## Extends Range so `value` / `max_value` behave like a ProgressBar. The fill is
## split into slanted segments; `mirrored` drains toward the screen centre for
## the right-hand (CPU) side, matching the HUD reference.

@export var fill_color := Color("#3fe0dc")
@export var back_color := Color(0.02, 0.05, 0.08, 0.9)
@export var segments := 7
@export var skew := 12.0
@export var gap := 5.0
@export var mirrored := false
@export var show_back := true
@export var tail_stripes := 3


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Health is fractional (chip damage); a whole-number step would desync the bar.
	step = 0.0
	value_changed.connect(func(_v: float): queue_redraw())
	changed.connect(queue_redraw)


func set_fill_color(color: Color) -> void:
	if fill_color != color:
		fill_color = color
		queue_redraw()


func ratio_filled() -> float:
	return clampf((value - min_value) / maxf(0.0001, max_value - min_value), 0.0, 1.0)


func _quad(x0: float, x1: float) -> PackedVector2Array:
	# Parallelogram between x0 and x1 leaning toward the screen centre.
	var h := size.y
	if mirrored:
		return PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1 + skew, h), Vector2(x0 + skew, h)])
	return PackedVector2Array([Vector2(x0 + skew, 0), Vector2(x1 + skew, 0), Vector2(x1, h), Vector2(x0, h)])


func _draw() -> void:
	var usable := size.x - skew
	if usable <= 0.0:
		return
	if show_back:
		draw_colored_polygon(_quad(0.0, usable), back_color)
	var ratio := ratio_filled()
	if ratio <= 0.0:
		return
	var tail := float(tail_stripes) * 9.0
	var body := maxf(1.0, usable - tail)
	var segment_width := (body - gap * float(segments - 1)) / float(segments)
	# Fill grows from the outer edge (left for the player, right when mirrored).
	var fill_extent := usable * ratio
	var highlight := fill_color.lightened(0.45)
	for i in range(segments):
		var start := float(i) * (segment_width + gap)
		var end := start + segment_width
		_draw_span(start, end, fill_extent, usable, highlight)
	for i in range(tail_stripes):
		var start := body + float(i) * 9.0 + 2.0
		_draw_span(start, start + 4.0, fill_extent, usable, highlight)


func _draw_span(start: float, end: float, fill_extent: float, usable: float, highlight: Color) -> void:
	var visible_end := minf(end, fill_extent)
	if visible_end <= start:
		return
	var x0 := start
	var x1 := visible_end
	if mirrored:
		x0 = usable - visible_end
		x1 = usable - start
	draw_colored_polygon(_quad(x0, x1), fill_color)
	var top := _quad(x0, x1)
	draw_line(top[0], top[1], Color(highlight, 0.85), 2.0)
