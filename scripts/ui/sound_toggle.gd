extends Button

## Always-visible sound state for the menu and the fight HUD.
##
## Draws a speaker with sound waves (on) or a red cross (muted), labelled
## SOUND / MUTED. Tapping toggles mute through the AudioManager; it also follows
## changes made in the Settings screen, so both stay in sync.

const ON_COLOR := Color("#dff3f3")
const MUTED_COLOR := Color("#ff5a66")

var host: Node
var _shown_muted := false


func setup(main: Node, font: Font) -> void:
	host = main
	name = "SoundToggle"
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", 12)
	tooltip_text = "Toggle sound"
	pressed.connect(_toggle)
	_refresh(true)


func is_muted() -> bool:
	return host != null and host.audio_manager != null and host.audio_manager.is_muted()


func _toggle() -> void:
	if host == null or host.audio_manager == null:
		return
	host.audio_manager.set_muted(not host.audio_manager.is_muted())
	host._track("sound_toggle", {"muted": host.audio_manager.is_muted()})
	if host.has_method("_sync_settings_controls"):
		host._sync_settings_controls()
	_refresh(true)


func _process(_delta: float) -> void:
	# Follow mute changes made elsewhere (Settings screen).
	if is_muted() != _shown_muted:
		_refresh(true)


func _refresh(force: bool) -> void:
	var muted := is_muted()
	if not force and muted == _shown_muted:
		return
	_shown_muted = muted
	text = "MUTED" if muted else "SOUND"
	var tint := MUTED_COLOR if muted else ON_COLOR
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(key, tint)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#3a1820") if muted else Color("#1d3140")
		if state == "hover": style.bg_color = style.bg_color.lightened(0.12)
		style.border_color = Color(MUTED_COLOR, 0.8) if muted else Color(0.27, 0.86, 0.85, 0.35)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.content_margin_right = 8
		add_theme_stylebox_override(state, style)
	queue_redraw()


func _draw() -> void:
	# Speaker glyph drawn in code (the bundled font has no speaker symbol).
	var tint := MUTED_COLOR if _shown_muted else ON_COLOR
	var center := Vector2(16, size.y * 0.5)
	draw_rect(Rect2(center + Vector2(-7, -4), Vector2(5, 8)), tint)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-2, -4), center + Vector2(4, -9), center + Vector2(4, 9), center + Vector2(-2, 4)]), tint)
	if _shown_muted:
		draw_line(center + Vector2(7, -5), center + Vector2(15, 5), tint, 2.5, true)
		draw_line(center + Vector2(15, -5), center + Vector2(7, 5), tint, 2.5, true)
	else:
		draw_arc(center + Vector2(4, 0), 6.0, -0.9, 0.9, 10, tint, 2.0, true)
		draw_arc(center + Vector2(4, 0), 10.0, -0.9, 0.9, 12, tint, 2.0, true)
