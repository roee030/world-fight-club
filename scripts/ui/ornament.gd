extends Control

## Vector ornaments for the console-style menus (fighter select reference).
##
## One Control draws one decoration kind, so screens stay anchorable and the
## art stays crisp at any resolution:
## - "diamond_pattern": faint diamond lattice (CPU side background)
## - "brackets": cyan corner brackets with tick marks (player frame)
## - "gold_frame": double gold frame with stepped corner ornaments
## - "hex": central tech hexagon lines
## - "title_rule": gold rule that fades outward (title flanks)
## - "hatch": short slanted marks (section headers)
## - "grid": faint square grid (portrait panel)

var kind := "brackets"
var color := Color("#46dcd8")
var mirrored := false


func setup(kind_name: String, rect: Rect2, tint: Color, mirror: bool = false) -> void:
	kind = kind_name
	color = tint
	mirrored = mirror
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "Ornament_" + kind_name.capitalize().replace(" ", "")
	queue_redraw()


func _draw() -> void:
	match kind:
		"diamond_pattern": _draw_diamonds()
		"brackets": _draw_brackets()
		"gold_frame": _draw_gold_frame()
		"hex": _draw_hex()
		"title_rule": _draw_title_rule()
		"hatch": _draw_hatch()
		"grid": _draw_grid()


func _draw_diamonds() -> void:
	var step := 70.0
	var faint := Color(color, 0.10)
	var y := -step
	while y < size.y + step:
		var x := -step
		while x < size.x + step:
			var c := Vector2(x, y)
			draw_polyline(PackedVector2Array([c + Vector2(0, -step * 0.5), c + Vector2(step * 0.5, 0), c + Vector2(0, step * 0.5), c + Vector2(-step * 0.5, 0), c + Vector2(0, -step * 0.5)]), faint, 1.0)
			x += step
		y += step


func _draw_brackets() -> void:
	var arm := 26.0
	var width := 2.5
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]
	for corner in corners:
		var sx := 1.0 if corner.x == 0.0 else -1.0
		var sy := 1.0 if corner.y == 0.0 else -1.0
		draw_line(corner, corner + Vector2(arm * sx, 0), color, width)
		draw_line(corner, corner + Vector2(0, arm * sy), color, width)
		draw_rect(Rect2(corner + Vector2(10 * sx, 10 * sy) - Vector2(2, 2), Vector2(4, 4)), color)
	# Tick marks along the top edge and the left side, like a HUD frame.
	var tick := Color(color, 0.55)
	for i in range(8):
		var x := 120.0 + float(i) * 9.0
		draw_line(Vector2(x, 6), Vector2(x + 5, 6), tick, 2.0)
	for i in range(6):
		var y := size.y * 0.35 + float(i) * 12.0
		draw_line(Vector2(-8, y), Vector2(-8, y + 6), tick, 2.0)


func _draw_gold_frame() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	var inner := outer.grow(-10.0)
	draw_rect(outer, Color(color, 0.85), false, 2.0)
	draw_rect(inner, Color(color, 0.45), false, 1.0)
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]
	for corner in corners:
		var sx := 1.0 if corner.x == 0.0 else -1.0
		var sy := 1.0 if corner.y == 0.0 else -1.0
		# Stepped "key" ornament: three nested L shapes.
		for k in range(3):
			var o := 6.0 + float(k) * 8.0
			var start := corner + Vector2(o * sx, o * sy)
			draw_line(start, start + Vector2((34.0 - o) * sx, 0), color, 2.0)
			draw_line(start, start + Vector2(0, (34.0 - o) * sy), color, 2.0)
		draw_rect(Rect2(corner + Vector2(28 * sx, 28 * sy) - Vector2(3, 3), Vector2(6, 6)), color)


func _draw_hex() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	var faint := Color(color, 0.16)
	for scale_factor in [1.0, 0.72, 0.46]:
		var points := PackedVector2Array()
		for i in range(7):
			points.append(c + Vector2.RIGHT.rotated(TAU * float(i) / 6.0) * r * float(scale_factor) * Vector2(1.35, 1.0))
		draw_polyline(points, faint, 1.5)
	draw_line(Vector2(0, c.y), Vector2(size.x, c.y), Color(color, 0.08), 1.0)
	draw_line(Vector2(size.x * 0.1, size.y * 0.18), Vector2(size.x * 0.9, size.y * 0.18), Color(color, 0.22), 1.5)
	for i in range(5):
		draw_line(Vector2(size.x * 0.12 + i * 6.0, size.y * 0.15), Vector2(size.x * 0.12 + i * 6.0 + 4.0, size.y * 0.21), Color(color, 0.5), 2.0)
		draw_line(Vector2(size.x * 0.86 - i * 6.0, size.y * 0.15), Vector2(size.x * 0.86 - i * 6.0 + 4.0, size.y * 0.21), Color(color, 0.5), 2.0)


func _draw_title_rule() -> void:
	var y := size.y * 0.5
	var steps := 24
	for i in range(steps):
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var alpha := t0 if not mirrored else 1.0 - t0
		var x0 := size.x * t0
		var x1 := size.x * t1
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(color, 0.15 + 0.85 * alpha), 2.0)
	var tip := Vector2(size.x if not mirrored else 0.0, y)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -4), tip + Vector2(4, 0), tip + Vector2(0, 4), tip + Vector2(-4, 0)]), color)


func _draw_hatch() -> void:
	for i in range(6):
		var x := float(i) * 7.0
		draw_line(Vector2(x, size.y), Vector2(x + 5.0, 0), color, 2.0)


func _draw_grid() -> void:
	var step := 28.0
	var faint := Color(color, 0.07)
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), faint, 1.0)
		x += step
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), faint, 1.0)
		y += step
