extends Control

## Result-card effects: falling gold confetti and sparkles for a win, red
## cracks with drifting embers for a loss. Purely decorative, code-drawn.

var mode := "win"
var _t := 0.0
var _pieces: Array = []
var _cracks: Array = []
var _rng := RandomNumberGenerator.new()


func setup(kind: String) -> void:
	name = "ResultFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_mode(kind)


func set_mode(kind: String) -> void:
	mode = kind
	_t = 0.0
	_rng.seed = 20261009 if kind == "win" else 7
	_pieces.clear()
	for i in range(46):
		_pieces.append({"x": _rng.randf(), "y": _rng.randf(), "speed": _rng.randf_range(0.06, 0.18), "spin": _rng.randf_range(-4.0, 4.0), "size": _rng.randf_range(4.0, 9.0), "phase": _rng.randf() * TAU})
	_cracks.clear()
	for i in range(5):
		var start := Vector2(_rng.randf_range(0.05, 0.95), _rng.randf_range(0.2, 0.55))
		var points := PackedVector2Array([start])
		var direction := Vector2.RIGHT.rotated(_rng.randf_range(-2.6, 2.6))
		for step in range(5):
			direction = direction.rotated(_rng.randf_range(-0.6, 0.6))
			points.append(points[-1] + direction * _rng.randf_range(0.03, 0.08))
		_cracks.append(points)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var area := size
	if mode == "win":
		for piece in _pieces:
			var y := fmod(float(piece.y) + _t * float(piece.speed), 1.0)
			var at := Vector2(float(piece.x) * area.x + sin(_t * 2.0 + float(piece.phase)) * 10.0, y * area.y)
			var angle := _t * float(piece.spin) + float(piece.phase)
			var half := Vector2(float(piece.size), float(piece.size) * 0.45)
			var corners := PackedVector2Array([at + (-half).rotated(angle), at + Vector2(half.x, -half.y).rotated(angle), at + half.rotated(angle), at + Vector2(-half.x, half.y).rotated(angle)])
			var shade := 0.75 + 0.25 * sin(angle * 2.0)
			draw_colored_polygon(corners, Color(1.0, 0.80 * shade, 0.30 * shade, 0.85))
	else:
		for crack in _cracks:
			var scaled := PackedVector2Array()
			for point in crack: scaled.append(point * area)
			draw_polyline(scaled, Color(1.0, 0.25, 0.3, 0.75), 2.0, true)
			draw_polyline(scaled, Color(1.0, 0.2, 0.25, 0.18), 7.0, true)
		for piece in _pieces:
			var y := 1.0 - fmod(float(piece.y) + _t * float(piece.speed) * 0.6, 1.0)
			var at := Vector2(float(piece.x) * area.x, y * area.y)
			draw_circle(at, float(piece.size) * 0.3, Color(1.0, 0.35, 0.2, 0.55 * (1.0 - y)))
