extends Node3D

const Catalog = preload("res://scripts/finishers/finisher_catalog.gd")
const Director = preload("res://scripts/finishers/finisher_director.gd")
const Rules = preload("res://scripts/finishers/finisher_rules.gd")
const MatchState = preload("res://scripts/finishers/match_state.gd")
const IDS = preload("res://scripts/character_debug.gd").FIGHTERS
const STEP := 1.0 / 60.0
const CELEBRATION_PLAYBACK_SCALE := 0.40
var catalog := Catalog.new()
var director := Director.new()
var attacker: GameFighter
var defender: GameFighter
var arena := Node3D.new()
var camera := Camera3D.new()
var attacker_selector: OptionButton
var defender_selector: OptionButton
var scenario_selector: OptionButton
var roster_finish_buttons: Dictionary = {}
var live_attack_buttons: Dictionary = {}
var status: Label
var event_label: Label
var scrub: HSlider
var speed := 1.0
var paused := true
var elapsed := 0.0
var outcome := "eligible"
var selected := "bennet"
var safe_frame := true
var bounds := true
var overlay: Control
var _updating_scrub := false
var live_mode := false
var _live_attack_request := ""
var celebration_preview := false

func _ready() -> void:
	add_child(arena)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(16, 0.2, 4)
	floor_shape.shape = box; floor_shape.position.y = -0.1; floor_body.add_child(floor_shape); arena.add_child(floor_body)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.6
	camera.position = Vector3(0, 1.4, 5)
	add_child(camera)
	camera.current = true
	add_child(director)
	director.catalog = catalog
	director.configure(self, arena, camera)
	catalog.load_default()
	_build_ui()

func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.name = "LabUI"; layer.layer = 20; add_child(layer)
	var panel := VBoxContainer.new(); panel.name = "Controls"; panel.position = Vector2(24, 16); panel.size = Vector2(1232, 214); layer.add_child(panel)
	var title := Label.new(); title.text = "FINISHER LAB  •  Shared match runtime"; title.add_theme_font_size_override("font_size", 25); panel.add_child(title)
	var row := HBoxContainer.new(); panel.add_child(row)
	attacker_selector = _selector(row, "Attacker", IDS)
	defender_selector = _selector(row, "Defender", IDS); defender_selector.select(2)
	scenario_selector = _selector(row, "Scenario", ["eligible", "hit", "miss", "pause-resume"])
	attacker_selector.item_selected.connect(func(index): preview(IDS[index], outcome))
	defender_selector.item_selected.connect(func(_index): preview(selected, outcome))
	scenario_selector.item_selected.connect(func(index): preview(selected, scenario_selector.get_item_text(index)))
	row = HBoxContainer.new(); row.name = "PlaybackControls"; panel.add_child(row)
	_button(row, "PLAY / PAUSE", func(): set_paused(not paused))
	_button(row, "STEP 1/60", step_frame)
	_button(row, "SPRITE LAB", close)
	var live := Button.new()
	live.name = "LiveFightTest"
	live.text = "LIVE VERSUS TEST"
	live.pressed.connect(func(): start_live_test(IDS[attacker_selector.selected]))
	row.add_child(live)
	var celebration := Button.new()
	celebration.name = "CelebrationPreview"
	celebration.text = "WIN CELEBRATION"
	celebration.pressed.connect(func(): preview_celebration(IDS[attacker_selector.selected]))
	row.add_child(celebration)
	var settings := HBoxContainer.new(); settings.name = "Settings"; panel.add_child(settings)
	for value in [0.25, 0.5, 1.0]: _button(settings, "%s×" % value, func(v = value): set_speed(v))
	_check(settings, "Mobile density", false, set_mobile)
	_check(settings, "Reduced motion", false, set_reduced_motion)
	_check(settings, "SafeFrame", true, func(value): safe_frame = value; overlay.queue_redraw())
	_check(settings, "Bounds", true, func(value): bounds = value; overlay.queue_redraw())
	var legend := Label.new(); legend.text = "Cyan: collision   Green: hurt proxy   Yellow: guard proxy   Orange: reach guide   Mint: world floor"; legend.add_theme_font_size_override("font_size", 14); panel.add_child(legend)
	var combat_row := HBoxContainer.new(); combat_row.name = "LiveCombatControls"; panel.add_child(combat_row)
	for spec in [["JAB", "light"], ["CROSS", "heavy"], ["SPECIAL", "special"]]:
		var attack := Button.new(); attack.name = "Live_" + spec[1]; attack.text = spec[0]
		attack.pressed.connect(func(action = spec[1]): _live_attack_request = action)
		combat_row.add_child(attack); live_attack_buttons[spec[1]] = attack
	var live_finish := Button.new(); live_finish.name = "Live_finisher"; live_finish.text = "FINISH NOW"
	live_finish.pressed.connect(trigger_live_finisher); combat_row.add_child(live_finish); live_attack_buttons.finisher = live_finish
	var roster := GridContainer.new(); roster.name = "FighterFinishGrid"; roster.columns = 7; roster.position = Vector2(24, 218); roster.size = Vector2(1232, 82); layer.add_child(roster)
	for fighter_id in IDS:
		var finish := Button.new()
		finish.name = "Finish_" + fighter_id
		finish.text = "%s  FINISH" % _short_name(fighter_id)
		finish.custom_minimum_size = Vector2(168, 36)
		finish.tooltip_text = "Preview %s Finish Attack and celebration" % fighter_id
		finish.pressed.connect(func(id = fighter_id): preview(id, "hit"))
		roster.add_child(finish)
		roster_finish_buttons[fighter_id] = finish
	status = Label.new(); status.position = Vector2(24, 580); status.size = Vector2(1232, 44); layer.add_child(status)
	event_label = Label.new(); event_label.position = Vector2(24, 630); layer.add_child(event_label)
	scrub = HSlider.new(); scrub.position = Vector2(24, 670); scrub.size = Vector2(1232, 28); scrub.step = STEP; layer.add_child(scrub)
	scrub.value_changed.connect(func(value): if not _updating_scrub: seek(value))
	overlay = Control.new(); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(overlay)
	overlay.draw.connect(_draw_overlays)

func _selector(row: Node, label: String, values: Array) -> OptionButton:
	var text := Label.new(); text.text = label; row.add_child(text)
	var button := OptionButton.new(); button.custom_minimum_size.x = 155
	for value in values: button.add_item(value)
	row.add_child(button)
	return button

func _short_name(fighter_id: String) -> String:
	return {
		"yair_golan": "Y. GOLAN", "yair_lapid": "Y. LAPID", "aryeh_deri": "DERI",
		"mansour_abbas": "M. ABBAS", "benny_gantz": "GANTZ", "itamar_ben_gvir": "BEN GVIR",
		"bezalel_smotrich": "SMOTRICH", "gadi_eisenkot": "EISENKOT", "joint_list": "JOINT"
	}.get(fighter_id, fighter_id.to_upper())

func _button(row: Node, text: String, callback: Callable) -> void:
	var button := Button.new(); button.text = text; button.pressed.connect(callback); row.add_child(button)

func _check(row: Node, text: String, checked: bool, callback: Callable) -> void:
	var button := CheckBox.new(); button.name = text; button.text = text; button.button_pressed = checked; button.toggled.connect(callback); row.add_child(button)

func preview(fighter_id: String, scenario: String) -> void:
	director.cancel()
	director.diagnostic = ""
	live_mode = false
	celebration_preview = false
	selected = fighter_id if IDS.has(fighter_id) else IDS[0]
	outcome = scenario if ["eligible", "hit", "miss", "pause-resume"].has(scenario) else "eligible"
	camera.current = true
	attacker_selector.select(IDS.find(selected))
	scenario_selector.select(["eligible", "hit", "miss", "pause-resume"].find(outcome))
	for fighter in [attacker, defender]:
		if is_instance_valid(fighter): fighter.free()
	attacker = _fighter(selected, 0, -0.8, false)
	defender = _fighter(IDS[defender_selector.selected], 1, 0.8, false)
	attacker.rival = defender; defender.rival = attacker
	attacker.meter = 100; defender.health = 15
	attacker.facing = 1; defender.facing = -1
	defender._visual.sprite.flip_h = true
	elapsed = 0
	var definition := catalog.definition_for(selected)
	var celebration := catalog.celebration_for(str(definition.get("celebration_id", "")))
	scrub.max_value = float(definition.get("duration", 0)) + float(celebration.get("duration", 0))
	if not catalog.errors.is_empty(): status.text = "CATALOG ERRORS: " + "; ".join(catalog.errors)
	elif not definition.get("implemented", false): status.text = "PLANNED — %s / %s • assets and timeline pending" % [selected, definition.get("finisher_id", "")]
	elif outcome == "eligible":
		var eligible := Rules.is_eligible({"state": MatchState.Value.FIGHTING, "paused": false, "attacker_actionable": true, "meter": attacker.meter}, definition)
		status.text = ("ELIGIBLE" if eligible else "INELIGIBLE") + " — full Special Energy activates on one press"
	else:
		director.force_opening_miss = outcome == "miss"
		director.begin(attacker, defender, definition)
		status.text = "RUNNING — " + str(definition.get("finisher_id", ""))
	set_paused(outcome != "hit" or not director.active)
	_update_display()

func _fighter(id: String, who: int, x: float, active: bool = false) -> GameFighter:
	var fighter := GameFighter.new(); fighter.setup(id, who, false); arena.add_child(fighter)
	fighter.position.x = x; fighter.set_physics_process(active)
	return fighter


func start_live_test(fighter_id: String) -> void:
	director.cancel()
	director.diagnostic = ""
	live_mode = true
	celebration_preview = false
	selected = fighter_id if IDS.has(fighter_id) else IDS[0]
	for fighter in [attacker, defender]:
		if is_instance_valid(fighter): fighter.free()
	attacker = _fighter(selected, 0, -0.8, true)
	defender = _fighter(IDS[defender_selector.selected], 1, 0.8, true)
	attacker.rival = defender; defender.rival = attacker
	attacker.meter = 100.0; defender.health = 15.0
	attacker.facing = 1; defender.facing = -1; defender._visual.sprite.flip_h = true
	attacker.round_over = false; defender.round_over = false
	elapsed = 0.0
	set_paused(false)
	status.text = "LIVE VERSUS — A/D move · W jump · S guard · J/K/L attacks · F finisher"
	event_label.text = "RIVAL HP 15%   •   SPECIAL ENERGY 100%   •   FINISH READY"


func trigger_live_finisher() -> bool:
	if not live_mode or not is_instance_valid(attacker) or not is_instance_valid(defender) or director.active:
		return false
	var definition := catalog.definition_for(selected)
	var eligible := Rules.is_eligible({
		"state": MatchState.Value.FIGHTING, "paused": false,
		"attacker_actionable": attacker.busy <= 0.0 and attacker.stun <= 0.0 and attacker.knockdown_time <= 0.0 and attacker.recovery_time <= 0.0 and not attacker.round_over,
		"meter": attacker.meter
	}, definition)
	if not eligible:
		status.text = "FINISH NEEDS 100% SPECIAL ENERGY AND AN ACTIONABLE FIGHTER"
		return false
	_live_attack_request = ""
	var in_range := attacker.position.distance_to(defender.position) <= float(definition.get("activation_range", 1.75))
	var started := director.begin(attacker, defender, definition, in_range)
	if started:
		status.text = ("LIVE FINISHER — " if in_range else "LIVE FINISHER MISS — ") + str(definition.get("finisher_id", ""))
	return started


func preview_celebration(fighter_id: String) -> bool:
	preview(fighter_id, "eligible")
	var definition := catalog.definition_for(selected)
	var celebration_id := str(definition.get("celebration_id", ""))
	var started := director.begin_celebration(attacker, defender, celebration_id)
	if started:
		celebration_preview = true
		set_paused(false)
		status.text = "WIN CELEBRATION — %s" % selected.to_upper()
		event_label.text = "WINNER POSE • RESULT-SCREEN VISIBILITY QA"
	else:
		status.text = "CELEBRATION UNAVAILABLE — %s" % selected.to_upper()
	return started


func _unhandled_input(event: InputEvent) -> void:
	if not live_mode or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_J, KEY_1: _live_attack_request = "light"
		KEY_K, KEY_2: _live_attack_request = "heavy"
		KEY_L, KEY_3: _live_attack_request = "special"
		KEY_F: trigger_live_finisher()


func _physics_process(_delta: float) -> void:
	if not live_mode or paused or director.active or not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	var axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis += 1.0
	attacker.set_controls(axis, Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP), Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_H), Input.is_key_pressed(KEY_C), _live_attack_request)
	defender.set_controls(0.0, false, false, false, "")
	_live_attack_request = ""

func _process(delta: float) -> void:
	if not visible: return
	if not paused and director.active:
		var playback_delta := delta * speed * (CELEBRATION_PLAYBACK_SCALE if celebration_preview else 1.0)
		director.advance(playback_delta); elapsed += playback_delta
	elif live_mode and is_instance_valid(attacker) and is_instance_valid(defender):
		event_label.text = "RIVAL HP %d%%   •   SPECIAL ENERGY %d%%   •   %s" % [roundi(defender.health), roundi(attacker.meter), "FINISH READY" if attacker.meter >= 100.0 else "LIVE COMBAT"]
	_update_display()

func set_speed(value: float) -> void:
	if value in [0.25, 0.5, 1.0]:
		speed = value
		set_paused(paused)

func set_paused(value: bool) -> void:
	paused = value; director.set_paused(value)
	for fighter in [attacker, defender]:
		if is_instance_valid(fighter):
			fighter._visual.motion.freeze_motion(value)
			fighter._visual.sprite.speed_scale = 0 if value else speed

func step_frame() -> void:
	if not paused or not director.active: return
	director.set_paused(false); director.advance(STEP); elapsed += STEP; set_paused(true)
	_update_display()

func seek(seconds: float) -> void:
	var target := clampf(seconds, 0, scrub.max_value)
	preview(selected, outcome)
	set_paused(true)
	if not director.active: return
	for _frame in range(int(floor(target / STEP))): step_frame()

func set_mobile(value: bool) -> void: director.set_effect_density("mobile" if value else "desktop")
func set_reduced_motion(value: bool) -> void: director.set_reduced_motion(value)

func _update_display() -> void:
	if not director.diagnostic.is_empty(): status.text = "DIRECTOR: " + director.diagnostic
	if not live_mode or director.active:
		event_label.text = "EVENT: %s   •   %.3fs   •   %s×   •   %s   •   consumed hits: %s" % [director.current_event_key(), elapsed, speed, "PAUSED" if paused else "PLAYING", ", ".join(director.consumed_hit_ids())]
	_updating_scrub = true; scrub.value = elapsed; _updating_scrub = false
	overlay.queue_redraw()

func _draw_overlays() -> void:
	if safe_frame: overlay.draw_rect(Rect2(64, 36, 1152, 648), Color(0.8, 0.7, 0.3, 0.7), false, 1)
	var a := camera.unproject_position(Vector3(-5, 0, 0)); var b := camera.unproject_position(Vector3(5, 0, 0))
	overlay.draw_line(a, b, Color(0.3, 0.9, 0.65, 0.8), 2)
	if not bounds: return
	for fighter in [attacker, defender]:
		if not is_instance_valid(fighter): continue
		var feet := camera.unproject_position(fighter.position)
		var shape: CapsuleShape3D = fighter._standing_capsule
		var head := camera.unproject_position(fighter.position + Vector3(0, shape.height, 0))
		var height := feet.y - head.y
		var radius := absf(camera.unproject_position(fighter.position + Vector3(shape.radius, 0, 0)).x - feet.x)
		overlay.draw_rect(Rect2(head - Vector2(radius, 0), Vector2(radius * 2, height)), Color.CYAN, false)
		overlay.draw_rect(Rect2(head - Vector2(radius + 4, 3), Vector2(radius * 2 + 8, height + 3)), Color.GREEN, false)
		var reach := 1.32 if fighter.attack_kind.is_empty() else float(GameFighter.MOVES[fighter.attack_kind].reach)
		var edge := camera.unproject_position(fighter.position + Vector3(fighter.facing * reach, 0.9, 0))
		overlay.draw_line(camera.unproject_position(fighter.position + Vector3(0, 0.9, 0)), edge, Color.ORANGE, 2)
		overlay.draw_circle(camera.unproject_position(fighter.position + Vector3(fighter.facing * 0.4, 1, 0)), 12, Color.YELLOW, false)

func close() -> void:
	director.cancel(); live_mode = false; visible = false; get_node("LabUI").visible = false
	get_parent().stage.visible = true; get_parent().get_node("DebugUI").visible = true
	get_parent().get_node("SpriteLabCamera").current = true
