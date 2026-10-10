extends Control

## One-time first-fight tutorial ("wizard").
##
## Runs inside the first real fight: the CPU stands still as a target, the
## round clock is frozen, and each step waits for the player to actually do
## the move (move, JAB, CROSS, KICK, jump, GUARD), then fills Special Energy to
## 100% and points at the glowing SP button for the first finisher. A pulsing
## ring points at the control to use. Completion or SKIP is remembered in
## user:// so the tutorial never shows again on that device.

signal finished(skipped: bool)

enum Phase { INTRO, PRACTICE, COMPLETE }

const SAVE_PATH := "user://tutorial.cfg"
const CYAN := Color("#59f0ff")
const GOLD := Color("#f2c35a")
const PANEL_TOP := 138.0
const DIM_ALPHA := 0.4
const LANE_TOP := 0.2
const LANE_BOTTOM := 0.62
const STEPS := [
	{"id": "move", "title": "MOVE", "text": "Drag the joystick left or right to walk.", "key": "A / D", "target": "stick"},
	{"id": "jab", "title": "JAB", "text": "Tap JAB for a fast punch.", "key": "J", "target": "light"},
	{"id": "cross", "title": "CROSS", "text": "Tap CROSS for a heavy punch.", "key": "K", "target": "heavy"},
	{"id": "kick", "title": "KICK", "text": "Tap KICK for a long-range kick.", "key": "U", "target": "kick"},
	{"id": "jump", "title": "JUMP", "text": "Push the joystick up to jump.", "key": "W", "target": "stick"},
	{"id": "guard", "title": "GUARD", "text": "Hold GUARD to block incoming hits.", "key": "S", "target": "block"},
	{"id": "combo", "title": "COMBO", "text": "Chain JAB, JAB, CROSS fast - each hit lands while the rival still reels. Pause > MOVE LIST shows all combos.", "key": "J, J, K", "target": ["light", "heavy"]},
	{"id": "special", "title": "SPECIAL ENERGY", "text": "Hits fill the gold SPECIAL ENERGY bar. At 100% the SP button lights up - tap SP for your finisher!", "key": "L", "target": "special"},
]

var host: Node
var step := 0
var active := false
var phase: Phase = Phase.INTRO
var _progress := 0.0
var _clock := 0.0
var _panel: Panel
var _title: Label
var _text: Label
var _key: Label
var _dots: Array[Panel] = []
var _intro: Panel
var _complete: Panel
var _font: Font


static func is_completed() -> bool:
	var config := ConfigFile.new()
	return config.load(SAVE_PATH) == OK and bool(config.get_value("tutorial", "done", false))


static func mark_completed(value: bool = true) -> void:
	var config := ConfigFile.new()
	config.set_value("tutorial", "done", value)
	config.save(SAVE_PATH)


func setup(main: Node, font: Font) -> void:
	host = main
	_font = font
	name = "Tutorial"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = Panel.new()
	_panel.name = "CoachPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.03, 0.06, 0.9)
	style.border_color = Color(CYAN, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(CYAN, 0.25)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -330
	_panel.offset_right = 330
	# Sits in the band between the HUD and the fighters' heads so it never hides them.
	_panel.offset_top = PANEL_TOP
	_panel.offset_bottom = PANEL_TOP + 124
	_title = _make_label(font, 24, GOLD, Rect2(22, 10, 470, 32))
	_title.name = "StepTitle"
	_text = _make_label(font, 17, Color("#e9f6f8"), Rect2(22, 44, 616, 50))
	_text.name = "StepText"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_key = _make_label(font, 13, Color("#9fb4ba"), Rect2(22, 94, 300, 22))
	_key.name = "KeyHint"
	var skip := Button.new()
	skip.name = "SkipTutorial"
	skip.text = "SKIP TUTORIAL"
	skip.add_theme_font_override("font", font)
	skip.add_theme_font_size_override("font_size", 13)
	skip.position = Vector2(500, 10)
	skip.size = Vector2(140, 34)
	skip.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		var skip_style := StyleBoxFlat.new()
		skip_style.bg_color = Color("#263845") if state != "hover" else Color("#30485a")
		skip_style.border_color = Color(CYAN, 0.45)
		skip_style.set_border_width_all(1)
		skip_style.set_corner_radius_all(3)
		skip.add_theme_stylebox_override(state, skip_style)
	skip.add_theme_color_override("font_color", Color("#e8eef0"))
	skip.pressed.connect(skip_tutorial)
	_panel.add_child(skip)
	for i in range(STEPS.size()):
		var dot := Panel.new()
		dot.position = Vector2(420 + i * 30, 101)
		dot.size = Vector2(22, 8)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(dot)
		_dots.append(dot)
	_intro = _make_gate("TutorialIntro", "LEARN THE BASICS", "A short practice round. Your rival waits while you learn the controls.", "START TUTORIAL", start_practice, skip_tutorial)
	_complete = _make_gate("TutorialComplete", "TRAINING COMPLETE", "You are ready. The next round is a real fight.", "START FIGHT", confirm_completion)
	visible = false


func _make_gate(node_name: String, title_text: String, body_text: String, button_text: String, action: Callable, skip_action: Callable = Callable()) -> Panel:
	var gate := Panel.new()
	gate.name = node_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.03, 0.06, 0.96)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(GOLD, 0.35)
	style.shadow_size = 20
	gate.add_theme_stylebox_override("panel", style)
	gate.anchor_left = 0.5
	gate.anchor_right = 0.5
	gate.anchor_top = 0.5
	gate.anchor_bottom = 0.5
	gate.offset_left = -260
	gate.offset_right = 260
	gate.offset_top = -115
	gate.offset_bottom = 115
	gate.mouse_filter = Control.MOUSE_FILTER_STOP
	var title := Label.new()
	title.text = title_text
	title.anchor_right = 1.0
	title.offset_left = 24
	title.offset_right = -24
	title.offset_top = 28
	title.offset_bottom = 66
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", GOLD)
	gate.add_child(title)
	var body := Label.new()
	body.text = body_text
	# Anchored to both edges so word-wrap always uses the panel width.
	body.anchor_right = 1.0
	body.offset_left = 40
	body.offset_right = -40
	body.offset_top = 76
	body.offset_bottom = 142
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", _font)
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color("#e9f6f8"))
	gate.add_child(body)
	var button := Button.new()
	button.name = "Confirm"
	button.text = button_text
	button.position = Vector2(150, 154)
	button.size = Vector2(220, 42)
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	gate.add_child(button)
	if skip_action.is_valid():
		var skip := Button.new()
		skip.name = "SkipTutorial"
		skip.text = "SKIP TUTORIAL"
		skip.position = Vector2(170, 204)
		skip.size = Vector2(180, 34)
		skip.focus_mode = Control.FOCUS_NONE
		skip.add_theme_font_override("font", _font)
		skip.add_theme_font_size_override("font_size", 13)
		skip.add_theme_color_override("font_color", Color("#e8eef0"))
		skip.pressed.connect(skip_action)
		gate.add_child(skip)
		gate.offset_top = -135
		gate.offset_bottom = 135
	add_child(gate)
	gate.visible = false
	return gate


func _make_label(font: Font, size_px: int, color: Color, rect: Rect2) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(label)
	return label


func begin() -> void:
	active = true
	visible = true
	step = 0
	phase = Phase.INTRO
	host._track("tutorial_start")
	host.player.attack_started.connect(_on_attack_started)
	host.player.combo_string.connect(_on_combo_string)
	# The match host pauses per-frame updates while a finisher plays, so the SP
	# step uses director signals instead of polling for it. Starting the sequence
	# hides the coach overlay; only the real sequence end completes the tutorial.
	if not host._finisher_director.sequence_started.is_connected(_on_finisher_started):
		host._finisher_director.sequence_started.connect(_on_finisher_started)
	if not host._finisher_director.sequence_finished.is_connected(_on_finisher_finished):
		host._finisher_director.sequence_finished.connect(_on_finisher_finished)
	if not host._finisher_director.cancelled.is_connected(_on_finisher_cancelled):
		host._finisher_director.cancelled.connect(_on_finisher_cancelled)
	_panel.visible = false
	_intro.visible = true
	_complete.visible = false
	queue_redraw()


func start_practice() -> void:
	if not active or phase != Phase.INTRO:
		return
	phase = Phase.PRACTICE
	_intro.visible = false
	_panel.visible = true
	_show_step()


func confirm_completion() -> void:
	if active and phase == Phase.COMPLETE:
		_finish(false)


func current_id() -> String:
	return str(STEPS[step].id) if step < STEPS.size() else ""


func _show_step() -> void:
	_progress = 0.0
	var data: Dictionary = STEPS[step]
	_title.text = "STEP %d / %d  ·  %s" % [step + 1, STEPS.size(), data.title]
	_text.text = str(data.text)
	_key.text = "KEYBOARD: %s" % data.key
	for i in range(_dots.size()):
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = GOLD if i < step else (CYAN if i == step else Color("#33495a"))
		dot_style.set_corner_radius_all(3)
		_dots[i].add_theme_stylebox_override("panel", dot_style)
	if data.id == "special":
		# Fill the bar so the player sees SP light up.
		host.player.meter = 100.0
		host.player.meter_changed.emit(0, 100.0)
	queue_redraw()


func _complete_step() -> void:
	host._track("tutorial_step", {"step": current_id()})
	step += 1
	if step >= STEPS.size():
		_show_completion()
	else:
		_show_step()


func _show_completion() -> void:
	phase = Phase.COMPLETE
	_panel.visible = false
	_complete.visible = true
	queue_redraw()


func abort() -> void:
	# Leaving the fight mid-tutorial: stop without marking it as done.
	if not active:
		return
	active = false
	visible = false
	phase = Phase.INTRO
	_disconnect_host()


func skip_tutorial() -> void:
	if active:
		host._track("tutorial_skip", {"step": "intro" if phase == Phase.INTRO else current_id()})
		_finish(true)


func _finish(skipped: bool) -> void:
	active = false
	visible = false
	phase = Phase.INTRO
	mark_completed()
	_disconnect_host()
	if not skipped:
		host._track("tutorial_complete")
	finished.emit(skipped)


func _on_finisher_started(_attacker_id: String) -> void:
	if active and phase == Phase.PRACTICE and current_id() == "special":
		_panel.visible = false


func _on_finisher_cancelled(_reason: String) -> void:
	# An out-of-range SP opens with a miss and spends the energy. Without this
	# the SP step could never complete and the tutorial stayed stuck with a
	# passive rival. Re-arm the step so the player can get closer and retry.
	if not active or phase != Phase.PRACTICE or current_id() != "special":
		return
	_panel.visible = true
	host.player.meter = 100.0
	host.player.meter_changed.emit(0, 100.0)


func _on_finisher_finished(_lethal: bool) -> void:
	if active and phase == Phase.PRACTICE and current_id() == "special":
		_complete_step()


func _on_combo_string(_who: int, _name: String, _damage: float) -> void:
	# Any named string of three or more hits completes the combo step.
	if active and current_id() == "combo" and host.player.combo_moves.size() >= 3:
		_complete_step()


func _disconnect_host() -> void:
	if is_instance_valid(host.player) and host.player.attack_started.is_connected(_on_attack_started):
		host.player.attack_started.disconnect(_on_attack_started)
	if is_instance_valid(host.player) and host.player.combo_string.is_connected(_on_combo_string):
		host.player.combo_string.disconnect(_on_combo_string)
	if host._finisher_director.sequence_started.is_connected(_on_finisher_started):
		host._finisher_director.sequence_started.disconnect(_on_finisher_started)
	if host._finisher_director.sequence_finished.is_connected(_on_finisher_finished):
		host._finisher_director.sequence_finished.disconnect(_on_finisher_finished)
	if host._finisher_director.cancelled.is_connected(_on_finisher_cancelled):
		host._finisher_director.cancelled.disconnect(_on_finisher_cancelled)


func _on_attack_started(attacker: int, move: String) -> void:
	if not active or phase != Phase.PRACTICE or attacker != 0:
		return
	var want := {"jab": "light", "cross": "heavy", "kick": "kick"}
	if want.get(current_id(), "") == move:
		_complete_step()


func advance(delta: float) -> void:
	# Called by the match host every frame while the tutorial runs.
	if not active or phase != Phase.PRACTICE:
		return
	_clock += delta
	var player = host.player
	match current_id():
		"move":
			if absf(player.velocity.x) > 0.8: _progress += delta
			if _progress >= 0.35: _complete_step()
		"jump":
			if not player.is_on_floor(): _complete_step()
		"guard":
			if player.input_block: _progress += delta
			if _progress >= 0.35: _complete_step()
	queue_redraw()


func target_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if phase != Phase.PRACTICE:
		return rects
	var data: Dictionary = STEPS[mini(step, STEPS.size() - 1)]
	var targets: Array = data.target if data.target is Array else [data.target]
	for target in targets:
		var node: Control = host.stick if str(target) == "stick" else host.buttons.get(str(target))
		if node == null or not node.is_visible_in_tree():
			continue
		rects.append(Rect2(node.get_global_rect().position - get_global_rect().position, node.get_global_rect().size))
	return rects


func target_rect() -> Rect2:
	var rects := target_rects()
	return rects[0] if not rects.is_empty() else Rect2()


func _draw() -> void:
	if not active:
		return
	var full := Rect2(Vector2.ZERO, size)
	var dim := Color(0.0, 0.01, 0.03, DIM_ALPHA)
	var rects := target_rects()
	if rects.is_empty():
		draw_rect(full, dim)
		return
	# The fight lane stays clear so both fighters are always readable; the dim only
	# covers the HUD above it and the controls below it, with a hole at the targets.
	var lane_top := full.size.y * LANE_TOP
	var lane_bottom := full.size.y * LANE_BOTTOM
	draw_rect(Rect2(full.position, Vector2(full.size.x, lane_top)), dim)
	var hole := rects[0].grow(18.0)
	for rect in rects:
		hole = hole.merge(rect.grow(18.0))
	hole = hole.intersection(Rect2(0.0, lane_bottom, full.size.x, full.size.y - lane_bottom))
	draw_rect(Rect2(Vector2(0, lane_bottom), Vector2(full.size.x, maxf(0.0, hole.position.y - lane_bottom))), dim)
	draw_rect(Rect2(Vector2(0, hole.position.y), Vector2(hole.position.x, hole.size.y)), dim)
	draw_rect(Rect2(Vector2(hole.end.x, hole.position.y), Vector2(full.end.x - hole.end.x, hole.size.y)), dim)
	draw_rect(Rect2(Vector2(0, hole.end.y), Vector2(full.size.x, full.end.y - hole.end.y)), dim)
	var pulse := 0.5 + 0.5 * sin(_clock * 6.0)
	for rect in rects:
		var center := rect.get_center()
		var radius := maxf(rect.size.x, rect.size.y) * (0.6 + 0.08 * pulse)
		draw_arc(center, radius, 0.0, TAU, 48, Color(GOLD, 0.9), 4.0, true)
		draw_arc(center, radius + 10.0, 0.0, TAU, 48, Color(GOLD, 0.3 * pulse), 8.0, true)
		# Arrow from the coach panel toward the control.
		var tip := center - Vector2(0, radius + 8.0)
		var bob := Vector2(0, -8.0 * pulse)
		draw_colored_polygon(PackedVector2Array([tip + bob, tip + bob + Vector2(-14, -22), tip + bob + Vector2(14, -22)]), GOLD)
	if current_id() == "special" and host.player_meter_bar != null:
		var bar: Control = host.player_meter_bar
		var bar_rect := Rect2(bar.get_global_rect().position - get_global_rect().position, bar.get_global_rect().size).grow(6)
		draw_rect(bar_rect, Color(GOLD, 0.5 + 0.5 * pulse), false, 3.0)
