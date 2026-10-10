extends Node3D

## New-engine battle scene (M1/M2 vertical slice): deterministic sim stepped at
## 60 Hz, 3D rigged fighters posed from snapshots, stage, camera director, HUD,
## hit sparks, SFX and a CPU opponent. Keyboard: A/D walk (double-tap = dash),
## W jump, S crouch, J/K = light/heavy punch, U/I = light/heavy kick. Hold back
## to block (down-back for lows). Esc returns to the menu.

const Sim = preload("res://sim/sim.gd")
const L = preload("res://sim/layout.gd")
const Moveset = preload("res://sim/moveset.gd")
const CharacterView = preload("res://present/character_view.gd")
const CpuPilot = preload("res://ai/cpu_pilot.gd")
const AudioManagerScript = preload("res://scripts/audio/audio_manager.gd")

const STAGE_ART := "res://assets/stages/kaplan-junction-arena.jpg"
const MALE := "res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf"
const FEMALE := "res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Female_FullBody.gltf"
const ROUNDS_TO_WIN := 2

var moveset
var state: PackedInt32Array
var views: Array = []
var cpu: RefCounted
var camera: Camera3D
var audio: Node
var _shake := 0.0
var _sparks: Array = []
var _round_wins := [0, 0]
var _round := 1
var _end_timer := 0
var _intro := 90
var cpu_controls_player := false
var headless_inputs: Array = []   # tests: per-frame input pairs

# HUD
var _hp_bars: Array[ProgressBar] = []
var _timer_label: Label
var _combo_labels: Array[Label] = []
var _banner: Label
var _banner_time := 0
var _round_pips: Array[Label] = []


func _ready() -> void:
	moveset = Moveset.compile(["res://data/movesets/universal.json"])
	_build_world()
	_build_hud()
	audio = AudioManagerScript.new()
	add_child(audio)
	_new_round()


func _new_round() -> void:
	state = Sim.new_match(moveset, [{"x": -16000, "hp": 10000}, {"x": 16000, "hp": 10000}], 1000 + _round)
	cpu = CpuPilot.new(2, 77 + _round)
	_intro = 90
	_end_timer = 0
	_show_banner("ROUND %d" % _round, 50)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.68)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.95, 0.88)
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.7
	rim.light_color = Color(0.55, 0.75, 1.0)
	add_child(rim)
	# Backdrop: the stage art on a large card behind the fighting plane.
	var backdrop := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(34.0, 19.1)
	backdrop.mesh = quad
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_texture = load(STAGE_ART)
	backdrop.material_override = bmat
	backdrop.position = Vector3(0, 3.2, -9.0)
	add_child(backdrop)
	# Floor that catches the fighters' shadows.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 12)
	floor_mesh.mesh = plane
	# Invisible floor that only shows shadows, so the stage photo reads as the ground.
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0, 0, 0, 1)
	fmat.shadow_to_opacity = true
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_mesh.material_override = fmat
	floor_mesh.position = Vector3(0, 0, -1.0)
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 38.0
	add_child(camera)
	camera.current = true
	for i in range(2):
		var view := CharacterView.new()
		add_child(view)
		view.setup(MALE if i == 0 else FEMALE, Color(0.85, 0.92, 1.1) if i == 0 else Color(1.1, 0.88, 0.85))
		views.append(view)


func _physics_process(_delta: float) -> void:
	var inputs := PackedInt32Array([0, 0])
	if not headless_inputs.is_empty():
		var pair: Array = headless_inputs.pop_front()
		inputs[0] = int(pair[0])
		inputs[1] = int(pair[1])
	elif _intro > 0:
		_intro -= 1
		if _intro == 30:
			_show_banner("FIGHT!", 40)
			audio.play_voice(&"fight")
	else:
		inputs[0] = cpu.decide(state, 0, moveset) if cpu_controls_player else _read_keyboard()
		inputs[1] = cpu.decide(state, 1, moveset)
	var events := Sim.step(moveset, state, inputs)
	_handle_events(events)
	if state[L.H_WINNER] >= 0:
		_end_timer += 1
		if _end_timer == 1:
			var winner := state[L.H_WINNER]
			if winner < 2: _round_wins[winner] += 1
			_show_banner("K.O." if _any_ko() else "TIME", 90)
		var match_over: bool = _round_wins[0] >= ROUNDS_TO_WIN or _round_wins[1] >= ROUNDS_TO_WIN
		if _end_timer == 150 and match_over:
			_show_banner("YOU WIN" if _round_wins[0] > _round_wins[1] else "YOU LOSE", 120)
		if _end_timer >= (300 if match_over else 210):
			if match_over:
				_round_wins = [0, 0]
				_round = 1
			else:
				_round += 1
			_new_round()


func _process(delta: float) -> void:
	for i in range(views.size()):
		views[i].show_state(state, i, moveset)
	_update_camera(delta)
	_update_sparks(delta)
	_update_hud()


func _read_keyboard() -> int:
	var bits := 0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): bits |= L.IN_LEFT
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): bits |= L.IN_RIGHT
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): bits |= L.IN_UP
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): bits |= L.IN_DOWN
	if Input.is_key_pressed(KEY_J): bits |= L.IN_LP
	if Input.is_key_pressed(KEY_K): bits |= L.IN_HP
	if Input.is_key_pressed(KEY_U): bits |= L.IN_LK
	if Input.is_key_pressed(KEY_I): bits |= L.IN_HK
	return bits


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _any_ko() -> bool:
	for i in range(state[L.H_FIGHTERS]):
		if state[L.base(i) + L.F_STATE] == L.S_KO: return true
	return false


func _handle_events(events: PackedInt32Array) -> void:
	for e in range(0, events.size(), L.EVENT_SIZE):
		var kind := events[e]
		var who := events[e + 1]
		match kind:
			L.EV_HIT:
				var m: Dictionary = moveset.moves[events[e + 2]]
				var heavy := int(m.damage) >= 600
				_shake = maxf(_shake, 0.16 if heavy else 0.07)
				_spark(who, m, Color(1.0, 0.85, 0.35) if heavy else Color(1.0, 0.97, 0.8), 0.55 if heavy else 0.35)
				var anim := str(m.anim)
				audio.play_sfx(&"kick_hit" if anim == "kick" else (&"cross_hit" if heavy else &"jab_hit"))
			L.EV_BLOCK:
				_spark(who, moveset.moves[events[e + 2]], Color(0.45, 0.75, 1.0), 0.3)
				audio.play_sfx(&"guard_hit")
			L.EV_COUNTER:
				_show_banner("COUNTER!", 35)
				_shake = maxf(_shake, 0.2)
			L.EV_LAUNCH:
				_shake = maxf(_shake, 0.12)
			L.EV_KO:
				_shake = 0.35
				audio.play_sfx(&"finisher")
			L.EV_LAND:
				if events[e + 2] == 1: _shake = maxf(_shake, 0.1)
			L.EV_ATTACK:
				if events[e + 3] == 0: audio.play_sfx(&"whiff")


func _spark(attacker: int, m: Dictionary, color: Color, size: float) -> void:
	var b := L.base(attacker)
	var facing := state[b + L.F_FACING]
	var hb: PackedInt32Array = m.hitbox
	var x := (state[b + L.F_X] + facing * (hb[0] + hb[2] * 3 / 4)) / 10000.0
	var y := (state[b + L.F_Y] + hb[1] + hb[3] / 2) / 10000.0
	var spark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size
	spark.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.material_override = mat
	spark.position = Vector3(x, y, 0.25)
	add_child(spark)
	_sparks.append({"node": spark, "life": 0.16, "max": 0.16})


func _update_sparks(delta: float) -> void:
	for k in range(_sparks.size() - 1, -1, -1):
		var sp: Dictionary = _sparks[k]
		sp.life -= delta
		var node: MeshInstance3D = sp.node
		var t: float = 1.0 - sp.life / sp.max
		node.scale = Vector3.ONE * (1.0 + t * 1.6)
		(node.material_override as StandardMaterial3D).albedo_color.a = 1.0 - t
		if sp.life <= 0.0:
			node.queue_free()
			_sparks.remove_at(k)


func _update_camera(delta: float) -> void:
	var x0 := state[L.base(0) + L.F_X] / 10000.0
	var x1 := state[L.base(1) + L.F_X] / 10000.0
	var mid := (x0 + x1) * 0.5
	var spread := absf(x1 - x0)
	var distance := clampf(4.6 + spread * 0.55, 5.2, 9.0)
	var target := Vector3(mid, 1.15 + distance * 0.06, distance)
	camera.position = camera.position.lerp(target, minf(1.0, delta * 6.0)) if camera.position != Vector3.ZERO else target
	_shake = maxf(0.0, _shake - delta * 1.6)
	var offset := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.25
	camera.look_at_from_position(camera.position + offset, Vector3(mid, 1.0, 0) + offset, Vector3.UP)


# --- HUD -------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	for i in range(2):
		var bar := ProgressBar.new()
		bar.max_value = 10000
		bar.value = 10000
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 26)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#3fd0e0") if i == 0 else Color("#ff5a6a")
		fill.set_corner_radius_all(4)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.55)
		bg.set_corner_radius_all(4)
		bg.border_color = Color(1, 1, 1, 0.5)
		bg.set_border_width_all(2)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
		if i == 0:
			bar.anchor_left = 0.03
			bar.anchor_right = 0.44
		else:
			bar.anchor_left = 0.56
			bar.anchor_right = 0.97
		bar.offset_top = 22
		bar.offset_bottom = 48
		root.add_child(bar)
		_hp_bars.append(bar)
		var name_label := _label(root, "YOU" if i == 0 else "CPU", 18, HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
		name_label.anchor_left = bar.anchor_left
		name_label.anchor_right = bar.anchor_right
		name_label.offset_top = 50
		name_label.offset_bottom = 74
		var pip := _label(root, "", 18, HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT)
		pip.anchor_left = bar.anchor_left
		pip.anchor_right = bar.anchor_right
		pip.offset_top = 50
		pip.offset_bottom = 74
		_round_pips.append(pip)
		var combo := _label(root, "", 30, HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
		combo.anchor_left = 0.04 if i == 0 else 0.6
		combo.anchor_right = 0.4 if i == 0 else 0.96
		combo.offset_top = 150
		combo.offset_bottom = 230
		combo.add_theme_color_override("font_color", Color("#ffd75a"))
		_combo_labels.append(combo)
	_timer_label = _label(root, "99", 40, HORIZONTAL_ALIGNMENT_CENTER)
	_timer_label.anchor_left = 0.44
	_timer_label.anchor_right = 0.56
	_timer_label.offset_top = 12
	_timer_label.offset_bottom = 64
	_banner = _label(root, "", 72, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.32
	_banner.anchor_bottom = 0.32
	_banner.offset_bottom = 100
	var hint := _label(root, "A/D move (double-tap dash)  W jump  S crouch  J/K punch  U/I kick  hold back = block  Esc menu", 14, HORIZONTAL_ALIGNMENT_CENTER)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -30
	hint.offset_bottom = -8
	hint.modulate = Color(1, 1, 1, 0.7)


func _label(parent: Control, text: String, size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _show_banner(text: String, frames: int) -> void:
	_banner.text = text
	_banner_time = frames


func _update_hud() -> void:
	for i in range(2):
		var b := L.base(i)
		_hp_bars[i].value = state[b + L.F_HP]
		var combo := state[b + L.F_COMBO]
		_combo_labels[i].text = ("%d HITS\n%d DMG" % [combo, state[b + L.F_COMBO_DAMAGE]]) if combo >= 2 else ""
		_round_pips[i].text = "* ".repeat(_round_wins[i]).strip_edges()
	_timer_label.text = str(int(ceil(state[L.H_TIMER] / 60.0)))
	if _banner_time > 0:
		_banner_time -= 1
		if _banner_time == 0: _banner.text = ""
