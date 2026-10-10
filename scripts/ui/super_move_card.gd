extends CanvasLayer

## Full-screen "super move" card shown when a finisher starts.
##
## Layout follows the owner's concept: dark backdrop with radial speed lines,
## the fighter's full-body art sliding in with a cyan glow, the fighter name on
## top and the finisher name as a slanted electric title with lightning arcs.
## The card is driven by `advance(delta)` from the FinisherDirector so it
## pauses with the cinematic, and it removes itself through the director's
## presentation cleanup.

const DURATION := 2.3
const IN_TIME := 0.16
const OUT_TIME := 0.26
const CYAN := Color("#59f0ff")

var elapsed := 0.0
var reduced_motion := false
var dense_effects := true
var _root: Control
var _effects: Control
var _art: TextureRect
var _glow: TextureRect
var _title: Label
var _name: Label
var _flash: ColorRect
var _bolts: Array = []
var _bolt_timer := 0.0
var _rng := RandomNumberGenerator.new()


func setup(fighter_name: String, move_name: String, art: Texture2D, title_font: Font, mirror_art: bool = true) -> void:
	layer = 16
	name = "SuperMoveCard"
	_rng.seed = hash(fighter_name + move_name)
	_root = Control.new()
	_root.name = "CardRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.06, 0.86)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_effects = Control.new()
	_effects.name = "Effects"
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects.draw.connect(_draw_effects)
	_root.add_child(_effects)
	# Fighter art, centred slightly right, with a cyan glow copy behind it.
	for i in range(2):
		var rect := TextureRect.new()
		rect.texture = art
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Face the title on the left (sprites face right; illustrated art is
		# already drawn facing left).
		rect.flip_h = mirror_art
		rect.anchor_left = 0.5
		rect.anchor_right = 0.5
		rect.anchor_top = 0.5
		rect.anchor_bottom = 0.5
		rect.offset_left = -200
		rect.offset_right = 360
		rect.offset_top = -330
		rect.offset_bottom = 360
		if i == 0:
			rect.name = "ArtGlow"
			rect.modulate = Color(CYAN, 0.55)
			rect.scale = Vector2(1.05, 1.05)
			rect.pivot_offset = Vector2(280, 345)
			_glow = rect
		else:
			rect.name = "FighterArt"
			_art = rect
		_root.add_child(rect)
	_name = _make_label(fighter_name.to_upper(), title_font, 40, CYAN)
	_name.name = "FighterName"
	_name.anchor_left = 0.5
	_name.anchor_right = 0.5
	_name.offset_left = -420
	_name.offset_right = 420
	_name.offset_top = 22
	_name.offset_bottom = 82
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title = _make_label(_wrap_title(move_name.to_upper()), title_font, 78, Color("#eafcff"))
	_title.name = "MoveName"
	_title.anchor_top = 0.5
	_title.anchor_bottom = 0.5
	_title.offset_left = 36
	_title.offset_right = 620
	_title.offset_top = -170
	_title.offset_bottom = 110
	_title.rotation = deg_to_rad(-8.0)
	_title.pivot_offset = Vector2(290, 140)
	_title.add_theme_color_override("font_outline_color", Color("#0a3b52"))
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_constant_override("line_spacing", -18)
	_flash = ColorRect.new()
	_flash.color = Color(0.85, 0.98, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_flash)
	_apply(0.0)


static func display_name_for(definition: Dictionary) -> String:
	var custom := str(definition.get("display_name", ""))
	if not custom.is_empty():
		return custom
	return str(definition.get("finisher_id", "FINISH")).replace("_", " ").to_upper()


func is_finished() -> bool:
	return elapsed >= DURATION


func advance(delta: float) -> void:
	elapsed = minf(DURATION, elapsed + delta)
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = 0.06
		_regenerate_bolts()
	_apply(elapsed)


func _make_label(text: String, font: Font, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.07, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_shadow_color", Color(CYAN, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 22)
	_root.add_child(label)
	return label


func _wrap_title(text: String) -> String:
	# Two balanced lines read like the concept ("FINAL / JUDGMENT").
	var words := text.split(" ", false)
	if words.size() < 2:
		return text
	var split := int(ceil(words.size() / 2.0))
	return " ".join(words.slice(0, split)) + "\n" + " ".join(words.slice(split))


func _apply(t: float) -> void:
	var appear := clampf(t / IN_TIME, 0.0, 1.0)
	var vanish := clampf((DURATION - t) / OUT_TIME, 0.0, 1.0)
	var alpha := minf(appear, vanish)
	_root.modulate.a = alpha
	var ease_in := 1.0 - pow(1.0 - appear, 3.0)
	var slide := 0.0 if reduced_motion else (1.0 - ease_in) * 320.0
	_art.offset_left = -200 + slide
	_art.offset_right = 360 + slide
	_glow.offset_left = _art.offset_left
	_glow.offset_right = _art.offset_right
	_glow.modulate.a = 0.35 + 0.25 * sin(t * 30.0)
	var punch := 1.0 if reduced_motion else 1.0 + (1.0 - ease_in) * 0.45
	_title.scale = Vector2(punch, punch)
	_flash.color.a = 0.0 if reduced_motion else maxf(0.0, 0.55 - t * 4.0)
	_effects.queue_redraw()


func _regenerate_bolts() -> void:
	_bolts.clear()
	var count := 6 if dense_effects else 3
	var size := _root.size if _root.size != Vector2.ZERO else Vector2(1280, 720)
	for i in range(count):
		var start := Vector2(_rng.randf_range(0.04, 0.42) * size.x, _rng.randf_range(0.25, 0.75) * size.y)
		var direction := Vector2.RIGHT.rotated(_rng.randf_range(-1.2, 1.2)) * _rng.randf_range(60.0, 180.0)
		var points := PackedVector2Array([start])
		var steps := 6
		for step in range(1, steps + 1):
			var base := start + direction * (float(step) / float(steps))
			points.append(base + direction.orthogonal().normalized() * _rng.randf_range(-14.0, 14.0))
		_bolts.append(points)


func _draw_effects() -> void:
	var size := _effects.size
	var center := Vector2(size.x * 0.56, size.y * 0.5)
	# Radial speed lines.
	var spin := elapsed * 0.6
	for i in range(48 if dense_effects else 24):
		var angle := TAU * float(i) / (48.0 if dense_effects else 24.0) + spin
		var inner := 120.0 + float((i * 37) % 90)
		var outer := maxf(size.x, size.y)
		var color := Color(CYAN, 0.10 + 0.08 * float(i % 3))
		_effects.draw_line(center + Vector2.RIGHT.rotated(angle) * inner, center + Vector2.RIGHT.rotated(angle) * outer, color, 2.0 + float(i % 2))
	# Lightning arcs around the title.
	for bolt in _bolts:
		_effects.draw_polyline(bolt, Color(0.75, 0.97, 1.0, 0.9), 2.5, true)
		_effects.draw_polyline(bolt, Color(CYAN, 0.35), 7.0, true)
