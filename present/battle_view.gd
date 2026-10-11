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
const SpriteView = preload("res://present/sprite_view.gd")
const Fx = preload("res://present/fx.gd")
const PrivateRoster = preload("res://scripts/private_roster.gd")
const AudioManagerScript = preload("res://scripts/audio/audio_manager.gd")
const VirtualStickScript = preload("res://scripts/virtual_stick.gd")
const TouchButtonScript = preload("res://scripts/touch_action_button.gd")
const SlantBar = preload("res://scripts/hud/slant_bar.gd")
const Session = preload("res://net/rollback_session.gd")
const CharacterLoader = preload("res://content/character_loader.gd")
const TrainingOverlay = preload("res://present/training_overlay.gd")
const DUMMY_MODES := ["STAND", "CROUCH", "BLOCK ALL", "JUMP", "CPU"]

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
var cpu_controls_player := false
## Online match handed over by the lobby: {"client": ws_client, "player": 0|1, "seed": int}.
static var pending_online: Dictionary = {}
## Fighter select hand-over: {"p1": fighter def, "p2": fighter def, "stage": art path}.
static var pending_selection: Dictionary = {}
var selection: Dictionary = {}
var _direct_launch := false   # started without the select screen (tests, captures)
var online: Dictionary = {}
var session: RefCounted
var local_slot := 0
var _last_event_frame := 0
var _inbox: Array = []
var _match_over_frames := 0
var _prev_winner := -1
## Training mode (F2 toggles; F3 cycles the dummy; F4 refills meters).
static var start_training := false
var training := false
var dummy_mode := 2
var _overlay: Node3D
var _hud_root: Control
## A local private fighter (git-ignored private/, e.g. the owner) plays as P1
## through the 12-pose sprite adapter until it has a rigged 3D model.
var use_private_fighter := true
var player_name := "YOU"
## Easy (auto-combos, one-button specials) is the default on touch screens; Tab toggles.
var easy_controls := DisplayServer.is_touchscreen_available()
var _mode_label: Label
var headless_inputs: Array = []   # tests: per-frame input pairs

# HUD
var _hp_bars: Array = []          # SlantBar per fighter
var _hp_trails: Array = []        # red damage trail behind each health bar
var _timer_label: Label
var _combo_labels: Array[Label] = []
var _banner: Label
var _banner_time := 0
var _round_pips: Array[Label] = []
var _stick: Control
var _projectiles: Dictionary = {}     # slot -> MeshInstance3D
var _cinematic := 0                   # render frames of super cinematic left
var _cine_fighter := 0
var _dim: ColorRect
var _super_bars: Array = []           # per fighter: Array of 3 ProgressBars
var _drive_bars: Array[ProgressBar] = []
var _burnout_labels: Array[Label] = []
var _callout: Label
var _callout_time := 0
var _zoom_punch := 0.0
var _slowmo := 0.0
var _touch_buttons: Dictionary = {}   # input bit -> button
var _hint: Label


func _ready() -> void:
	moveset = Moveset.compile(["res://data/movesets/universal.json", "res://data/movesets/rushdown.json", "res://data/movesets/grappler.json"])
	selection = pending_selection
	pending_selection = {}
	_direct_launch = selection.is_empty()
	if selection.is_empty():
		var defs: Array = CharacterLoader.fighter_definitions()
		if defs.size() >= 2:
			selection = {"p1": defs[0], "p2": defs[1], "stage": STAGE_ART}
	_build_world()
	_build_hud()
	_build_touch()
	audio = AudioManagerScript.new()
	add_child(audio)
	if not pending_online.is_empty():
		online = pending_online
		pending_online = {}
		local_slot = int(online.player)
		online.client.packet_received.connect(func(packet: Dictionary): _inbox.append(packet))
		online.client.opponent_left.connect(func(): _show_banner("OPPONENT LEFT", 600))
	_overlay = TrainingOverlay.new()
	add_child(_overlay)
	_overlay.setup(_hud_root)
	training = start_training and online.is_empty()
	start_training = false
	_overlay.set_active(training)
	_new_match()


func _new_match() -> void:
	var seed_value := int(online.get("seed", 1000 + randi() % 1000))
	# In online play both fighters use the same control rules (Easy auto-combos on).
	var stats0: Dictionary = selection.get("p1", {}).get("stats", {})
	var stats1: Dictionary = selection.get("p2", {}).get("stats", {})
	state = Sim.new_match(moveset, [
		{"x": -16000, "hp": int(stats0.get("hp", 10000)), "walk": int(stats0.get("walk", 541)), "easy": easy_controls or not online.is_empty(), "archetype": str(selection.get("p1", {}).get("moveset", "universal"))},
		{"x": 16000, "hp": int(stats1.get("hp", 10000)), "walk": int(stats1.get("walk", 541)), "easy": true, "archetype": str(selection.get("p2", {}).get("moveset", "universal"))}], seed_value, {"intro": true, "rounds_to_win": 2})
	cpu = CpuPilot.new(2, seed_value)
	_match_over_frames = 0
	_prev_winner = -1
	_last_event_frame = 0
	if not online.is_empty():
		session = Session.new(moveset, state, local_slot, 2)
	_show_banner("ROUND 1", 60)
	if audio != null: _announce_round(1)


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
	bmat.albedo_texture = load(str(selection.get("stage", STAGE_ART)))
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
		var def: Dictionary = selection.get("p1" if i == 0 else "p2", {})
		var private_id := ""
		if bool(def.get("private", false)):
			private_id = str(def.id)
		elif i == 0 and use_private_fighter and _direct_launch and not PrivateRoster.ids().is_empty():
			private_id = str(PrivateRoster.ids()[0])
		if private_id != "":
			var paths: Array = []
			for frame in range(12):
				paths.append(PrivateRoster.sprite_path(private_id, frame))
			var sprite_view := SpriteView.new()
			add_child(sprite_view)
			sprite_view.setup_frames(paths, float(PrivateRoster.info(private_id).get("height_m", 1.8)))
			views.append(sprite_view)
			if i == 0: player_name = str(PrivateRoster.info(private_id).get("name", private_id)).to_upper()
			continue
		var view := CharacterView.new()
		add_child(view)
		var tint: Array = def.get("tint", [1, 1, 1])
		view.setup(str(def.get("model", MALE if i == 0 else FEMALE)), Color(float(tint[0]), float(tint[1]), float(tint[2])))
		view.rig_root.scale = Vector3.ONE * float(def.get("scale", 1.0))
		views.append(view)
		if i == 0 and not def.is_empty(): player_name = str(def.get("name", "YOU"))


func _physics_process(_delta: float) -> void:
	if not online.is_empty():
		_step_online()
	else:
		var inputs := PackedInt32Array([0, 0])
		if not headless_inputs.is_empty():
			var pair: Array = headless_inputs.pop_front()
			inputs[0] = int(pair[0])
			inputs[1] = int(pair[1])
		else:
			inputs[0] = cpu.decide(state, 0, moveset) if cpu_controls_player else _read_keyboard()
			inputs[1] = _dummy_input() if training else cpu.decide(state, 1, moveset)
		var events := Sim.step(moveset, state, inputs)
		_handle_events(events)
		if training:
			_overlay.observe(state, moveset, events)
			_training_refill()
	_round_presentation()


func _step_online() -> void:
	online.client.poll()
	for packet in _inbox:
		session.receive(packet)
	_inbox.clear()
	if not session.should_stall():
		online.client.send_packet(session.add_local_input(_read_keyboard()))
	session.advance()
	state = session.state
	# Present each frame's events once: only frames newer than the last shown.
	for entry in session.events_out:
		if int(entry[0]) > _last_event_frame:
			_handle_events(entry[1])
			_last_event_frame = int(entry[0])
	session.events_out.clear()


func _dummy_input() -> int:
	var b := L.base(1)
	var toward_player := L.IN_LEFT if state[L.base(0) + L.F_X] < state[b + L.F_X] else L.IN_RIGHT
	var away := L.IN_RIGHT if toward_player == L.IN_LEFT else L.IN_LEFT
	match DUMMY_MODES[dummy_mode]:
		"CROUCH": return L.IN_DOWN
		"BLOCK ALL":
			# Blocks highs/mids standing and lows crouching, like a perfect defender.
			var a := L.base(0)
			if state[a + L.F_STATE] == L.S_ATTACK and state[a + L.F_MOVE] >= 0 and int(moveset.moves[state[a + L.F_MOVE]].level) == 2:
				return away | L.IN_DOWN
			return away
		"JUMP": return L.IN_UP
		"CPU": return cpu.decide(state, 1, moveset)
	return 0


func _training_refill() -> void:
	# Training never ends: HP refills once a combo is over, timer is frozen.
	state[L.H_TIMER] = int(moveset.rules.round_frames)
	state[L.H_INTRO] = 0
	for i in range(2):
		var b := L.base(i)
		if state[b + L.F_STATE] in [L.S_IDLE, L.S_WALK_F, L.S_WALK_B, L.S_CROUCH] and state[b + L.F_HITS_TAKEN] == 0:
			state[b + L.F_HP] = state[b + L.F_HP_MAX]
		if state[b + L.F_HP] <= 0 or state[b + L.F_STATE] == L.S_KO:
			state[b + L.F_HP] = state[b + L.F_HP_MAX]
	state[L.H_WINNER] = -1
	state[L.H_MATCH_OVER] = 0


func _announce_round(round_number: int) -> void:
	var final := state[L.H_WINS] == state[L.H_ROUNDS_TO_WIN] - 1 and state[L.H_WINS + 1] == state[L.H_ROUNDS_TO_WIN] - 1
	audio.play_voice(&"final_round" if final else (&"round_one" if round_number == 1 else &"round_two"))


func _round_presentation() -> void:
	# Low-health music when either fighter drops under a quarter of their HP.
	if state[L.H_INTRO] == 0 and state[L.H_WINNER] < 0:
		var low := false
		for i in range(2):
			var b := L.base(i)
			if state[b + L.F_HP] * 4 < state[b + L.F_HP_MAX]: low = true
		audio.set_music_state(&"fight_low_health" if low else &"fight")
	var winner := state[L.H_WINNER]
	if winner >= 0 and _prev_winner < 0:
		_show_banner("K.O." if _any_ko() else "TIME", 90)
	_prev_winner = winner
	if state[L.H_MATCH_OVER] != 0:
		_match_over_frames += 1
		if _match_over_frames == 100:
			_show_banner("YOU WIN" if state[L.H_WINNER] == local_slot else "YOU LOSE", 200)
		if _match_over_frames >= 320 and online.is_empty():
			_new_match()


func _process(delta: float) -> void:
	if _slowmo > 0.0:
		# KO slow motion (presentation only: it slows the local 60 Hz stepping).
		_slowmo = maxf(0.0, _slowmo - delta / maxf(0.05, Engine.time_scale))
		Engine.time_scale = 0.3 if _slowmo > 0.0 else 1.0
	for i in range(views.size()):
		views[i].show_state(state, i, moveset)
	_update_camera(delta)
	_update_sparks(delta)
	_update_projectiles()
	if training:
		_overlay.draw_boxes(state, moveset)
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
	if Input.is_key_pressed(KEY_L): bits |= L.IN_SP
	if Input.is_key_pressed(KEY_O): bits |= L.IN_DRIVE
	# Phone: virtual stick + four attack buttons (held state; the sim finds presses).
	if _stick != null and _stick.visible:
		var axis: Vector2 = _stick.axis
		if axis.x < -0.35: bits |= L.IN_LEFT
		elif axis.x > 0.35: bits |= L.IN_RIGHT
		if axis.y < -0.5: bits |= L.IN_UP
		elif axis.y > 0.5: bits |= L.IN_DOWN
		for bit in _touch_buttons:
			if _touch_buttons[bit].is_held(): bits |= int(bit)
	return bits


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2 and online.is_empty():
		training = not training
		_overlay.set_active(training)
		_show_callout("TRAINING  ·  DUMMY: %s" % DUMMY_MODES[dummy_mode] if training else "VERSUS CPU", 60)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3 and training:
		dummy_mode = (dummy_mode + 1) % DUMMY_MODES.size()
		_show_callout("DUMMY: %s" % DUMMY_MODES[dummy_mode], 50)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F4 and training:
		for i in range(2):
			state[L.base(i) + L.F_SUPER] = int(moveset.rules.super_max)
			state[L.base(i) + L.F_DRIVE] = int(moveset.rules.drive_max)
			state[L.base(i) + L.F_BURNOUT] = 0
		_show_callout("METERS FULL", 40)
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		easy_controls = not easy_controls
		var b := L.base(0)
		if easy_controls: state[b + L.F_FLAGS] = state[b + L.F_FLAGS] | L.FLAG_EASY
		else: state[b + L.F_FLAGS] = state[b + L.F_FLAGS] & ~L.FLAG_EASY
		_show_callout("EASY CONTROLS" if easy_controls else "PRO CONTROLS", 40)


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
				if heavy: _zoom_punch = maxf(_zoom_punch, 0.35)
				var victim := state[L.base(who) + L.F_TARGET]
				if views[victim].has_method("flash"): views[victim].flash()
				_spark(who, m, Color(1.0, 0.85, 0.35) if heavy else Color(1.0, 0.97, 0.8), 0.55 if heavy else 0.35)
				var anim := str(m.anim)
				audio.play_sfx(&"kick_hit" if anim == "kick" else (&"cross_hit" if heavy else &"jab_hit"))
			L.EV_BLOCK:
				_spark(who, moveset.moves[events[e + 2]], Color(0.45, 0.75, 1.0), 0.3)
				audio.play_sfx(&"guard_hit")
			L.EV_COUNTER:
				_show_banner("PUNISH COUNTER!" if events[e + 3] == 2 else "COUNTER!", 35)
				_shake = maxf(_shake, 0.2)
			L.EV_LAUNCH:
				_shake = maxf(_shake, 0.12)
			L.EV_ROUND_START:
				_show_banner("ROUND %d" % events[e + 2], 60)
				_announce_round(events[e + 2])
			L.EV_FIGHT:
				_show_banner("FIGHT!", 40)
				audio.play_voice(&"fight")
				audio.set_music_state(&"fight")
			L.EV_MATCH_OVER:
				audio.set_music_state(&"result")
				audio.play_sfx(&"victory" if events[e + 2] == local_slot else &"loss")
				audio.play_voice(&"you_win" if events[e + 2] == local_slot else &"you_lose")
			L.EV_KO:
				_shake = 0.35
				if online.is_empty(): _slowmo = 1.1
				_zoom_punch = 0.6
				audio.play_sfx(&"finisher")
			L.EV_LAND:
				if events[e + 2] == 1: _shake = maxf(_shake, 0.1)
			L.EV_ATTACK:
				if events[e + 3] == 0: audio.play_sfx(&"whiff")
			L.EV_SPECIAL:
				_show_callout(str(moveset.moves[events[e + 2]].display_name).to_upper(), 45)
				audio.play_sfx(&"special")
			L.EV_SUPER:
				_cinematic = int(events[e + 3]) + 6
				_cine_fighter = who
				_show_callout(str(moveset.moves[events[e + 2]].display_name).to_upper(), 70)
				audio.play_sfx(&"special_ready")
			L.EV_PARRY:
				_show_callout("PERFECT PARRY!" if events[e + 2] == 1 else "PARRY", 35)
				_spark_at(who, Color(0.4, 1.0, 0.75), 0.6)
				audio.play_sfx(&"guard_hit")
			L.EV_THROW:
				_show_callout("THROW", 30)
				_shake = maxf(_shake, 0.18)
				audio.play_sfx(&"kick_hit")
			L.EV_TECH:
				_show_callout("TECH!", 30)
				audio.play_sfx(&"guard_hit")
			L.EV_WALL:
				_show_callout("WALL SPLAT!", 40)
				_shake = maxf(_shake, 0.3)
			L.EV_ARMOR:
				_spark_at(who, Color(1.0, 0.4, 0.2), 0.7)
				audio.play_sfx(&"guard_hit")
			L.EV_BURNOUT:
				_show_callout("BURNOUT", 50)
			L.EV_RUSH:
				audio.play_sfx(&"jump")


func _spark(attacker: int, m: Dictionary, color: Color, size: float) -> void:
	var b := L.base(attacker)
	var facing := state[b + L.F_FACING]
	var hb: PackedInt32Array = m.hitbox
	var x := (state[b + L.F_X] + facing * (hb[0] + hb[2] * 3 / 4)) / 10000.0
	var y := (state[b + L.F_Y] + hb[1] + hb[3] / 2) / 10000.0
	Fx.burst(self, Vector3(x, y, 0.3), color, size * 1.6)


func _spark_at(fighter: int, color: Color, size: float) -> void:
	var fake := {"hitbox": PackedInt32Array([0, 9000, 4000, 4000])}
	_spark(fighter, fake, color, size)


func _update_projectiles() -> void:
	for slot in range(L.PROJECTILES):
		var p := L.projectile_base(state, slot)
		var active := state[p + L.P_ACTIVE] != 0
		if active and not _projectiles.has(slot):
			var owner := state[p + L.P_OWNER]
			var node := Fx.projectile(Color(0.35, 0.85, 1.0) if owner == 0 else Color(1.0, 0.45, 0.3))
			add_child(node)
			_projectiles[slot] = node
		if _projectiles.has(slot):
			var node: Node3D = _projectiles[slot]
			if not active:
				node.queue_free()
				_projectiles.erase(slot)
			else:
				var m: Dictionary = moveset.moves[state[p + L.P_MOVE]]
				var box: PackedInt32Array = m.proj_box
				node.position = Vector3(state[p + L.P_X] / 10000.0, (state[p + L.P_Y] + box[1] + box[3] / 2) / 10000.0, 0.15)
				var shell := node.get_node("Shell") as Node3D
				shell.scale = Vector3.ONE * (1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.03))
				# The tail trails behind the direction of travel.
				(node.get_node("Tail") as Node3D).position.x = -signf(float(state[p + L.P_VX])) * 0.3


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
	_zoom_punch = maxf(0.0, _zoom_punch - delta * 2.5)
	distance -= _zoom_punch * 1.2
	var target := Vector3(mid, 1.15 + distance * 0.06, distance)
	var look := Vector3(mid, 1.0, 0)
	if _cinematic > 0:
		# Super Art: swing in close on the attacker and dim the world.
		_cinematic -= 1
		var fb := L.base(_cine_fighter)
		var fx := state[fb + L.F_X] / 10000.0
		var ff := state[fb + L.F_FACING]
		target = Vector3(fx + ff * 1.6, 1.45, 2.4)
		look = Vector3(fx, 1.25, 0)
		camera.position = camera.position.lerp(target, minf(1.0, delta * 10.0))
		camera.look_at(look, Vector3.UP)
		_dim.color.a = lerpf(_dim.color.a, 0.45, minf(1.0, delta * 12.0))
		return
	_dim.color.a = lerpf(_dim.color.a, 0.0, minf(1.0, delta * 8.0))
	camera.position = camera.position.lerp(target, minf(1.0, delta * 6.0)) if camera.position != Vector3.ZERO else target
	_shake = maxf(0.0, _shake - delta * 1.6)
	var offset := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.25
	camera.look_at_from_position(camera.position + offset, look + offset, Vector3.UP)


# --- HUD -------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_hud_root = root
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dim)
	for i in range(2):
		# Super gauge (3 bars) along the bottom edge, Drive gauge under the HP bar.
		var supers: Array = []
		for k in range(3):
			var sb := _meter_bar(root, Color("#ffd23f"), 10000)
			var left := 0.03 + k * 0.075 if i == 0 else 0.97 - (k + 1) * 0.075 + 0.005
			sb.anchor_left = left
			sb.anchor_right = left + 0.07
			sb.anchor_top = 1.0
			sb.anchor_bottom = 1.0
			sb.offset_top = -62
			sb.offset_bottom = -46
			supers.append(sb)
		_super_bars.append(supers)
		var db := _meter_bar(root, Color("#4ff08a"), 60000)
		db.anchor_left = 0.03 if i == 0 else 0.56
		db.anchor_right = 0.44 if i == 0 else 0.97
		db.offset_top = 80
		db.offset_bottom = 90
		db.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
		_drive_bars.append(db)
		var burn := _label(root, "", 14, HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
		burn.anchor_left = db.anchor_left
		burn.anchor_right = db.anchor_right
		burn.offset_top = 92
		burn.offset_bottom = 112
		burn.add_theme_color_override("font_color", Color("#ff6a3d"))
		_burnout_labels.append(burn)
	for i in range(2):
		# Damage trail (drains slowly) under the segmented slanted health bar.
		var trail = SlantBar.new()
		trail.max_value = 10000
		trail.value = 10000
		trail.fill_color = Color("#ff3b3b")
		trail.mirrored = i == 1
		var bar = SlantBar.new()
		bar.max_value = 10000
		bar.value = 10000
		bar.fill_color = Color("#3fe0dc") if i == 0 else Color("#ff6b5a")
		bar.mirrored = i == 1
		bar.show_back = false
		for b in [trail, bar]:
			if i == 0:
				b.anchor_left = 0.03
				b.anchor_right = 0.44
			else:
				b.anchor_left = 0.56
				b.anchor_right = 0.97
			b.offset_top = 22
			b.offset_bottom = 50
		root.add_child(trail)
		_hp_trails.append(trail)
		root.add_child(bar)
		_hp_bars.append(bar)
		var name_label := _label(root, _name_for(i), 18, HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
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
	_mode_label = _label(root, "", 13, HORIZONTAL_ALIGNMENT_CENTER)
	_mode_label.anchor_left = 0.44
	_mode_label.anchor_right = 0.56
	_mode_label.offset_top = 66
	_mode_label.offset_bottom = 84
	_mode_label.add_theme_color_override("font_color", Color("#9fe8ff"))
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
	_callout = _label(root, "", 34, HORIZONTAL_ALIGNMENT_CENTER)
	_callout.anchor_left = 0.0
	_callout.anchor_right = 1.0
	_callout.anchor_top = 0.2
	_callout.anchor_bottom = 0.2
	_callout.offset_bottom = 50
	_callout.add_theme_color_override("font_color", Color("#ffe27a"))
	_hint = _label(root, "A/D move  W jump  S crouch  J/K punch  U/I kick  L special (+dir)  L+I super  O drive (hold parry, +fwd rush, +K impact)  J+U throw  back = block  Esc menu", 13, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -30
	_hint.offset_bottom = -8
	_hint.modulate = Color(1, 1, 1, 0.7)


func _build_touch() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var show := DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios") or "--touch" in OS.get_cmdline_user_args()
	_stick = VirtualStickScript.new()
	root.add_child(_stick)
	_stick.anchor_top = 1.0
	_stick.anchor_bottom = 1.0
	_stick.offset_left = 40
	_stick.offset_right = 230
	_stick.offset_top = -290
	_stick.offset_bottom = -100
	_stick.visible = show
	var pad := Control.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.anchor_left = 1.0
	pad.anchor_right = 1.0
	pad.anchor_top = 1.0
	pad.anchor_bottom = 1.0
	pad.offset_left = -300
	pad.offset_top = -380
	pad.offset_right = -20
	pad.offset_bottom = -90
	pad.visible = show
	root.add_child(pad)
	var layout := [[L.IN_LP, "LP", "fist", Color("#239f9b"), Vector2(20, 90)], [L.IN_HP, "HP", "cross", Color("#c8443f"), Vector2(110, 10)],
		[L.IN_LK, "LK", "boot", Color("#2f7fd0"), Vector2(110, 170)], [L.IN_HK, "HK", "bolt", Color("#d08a2f"), Vector2(200, 90)],
		[L.IN_SP, "SP", "spark", Color("#c9a227"), Vector2(-70, 180)], [L.IN_DRIVE, "DRIVE", "shield", Color("#2fb36a"), Vector2(-70, 60)]]
	if show and _hint != null:
		_hint.visible = false   # keyboard help is noise on a phone
	for entry in layout:
		var button = TouchButtonScript.new()
		pad.add_child(button)
		button.configure(str(entry[1]).to_lower(), str(entry[1]), "diamond", str(entry[2]), entry[3], Rect2(entry[4], Vector2(86, 86)))
		_touch_buttons[int(entry[0])] = button


func _name_for(i: int) -> String:
	if not pending_online.is_empty() or not online.is_empty():
		var slot := int((pending_online if not pending_online.is_empty() else online).player)
		return "YOU" if i == slot else "RIVAL"
	return player_name if i == 0 else "CPU"


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


func _meter_bar(parent: Control, color: Color, max_value: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar


func _show_callout(text: String, frames: int) -> void:
	_callout.text = text
	_callout_time = frames


func _show_banner(text: String, frames: int) -> void:
	_banner.text = text
	_banner_time = frames


func _update_hud() -> void:
	for i in range(2):
		var b := L.base(i)
		_hp_bars[i].max_value = state[b + L.F_HP_MAX]
		_hp_bars[i].value = state[b + L.F_HP]
		_hp_trails[i].max_value = state[b + L.F_HP_MAX]
		# The red trail catches up only after a combo ends (classic damage readout).
		if state[b + L.F_HITS_TAKEN] == 0 or _hp_trails[i].value < state[b + L.F_HP]:
			_hp_trails[i].value = move_toward(_hp_trails[i].value, state[b + L.F_HP], 45.0)
		var combo := state[b + L.F_COMBO]
		_combo_labels[i].text = ("%d HITS\n%d DMG" % [combo, state[b + L.F_COMBO_DAMAGE]]) if combo >= 2 else ""
		_round_pips[i].text = "* ".repeat(state[L.H_WINS + i]).strip_edges()
	_timer_label.text = str(int(ceil(state[L.H_TIMER] / 60.0)))
	_mode_label.text = "EASY  (TAB)" if easy_controls else "PRO  (TAB)"
	for i in range(2):
		var b := L.base(i)
		var sup := state[b + L.F_SUPER]
		for k in range(3):
			(_super_bars[i][k] as ProgressBar).value = clampi(sup - k * 10000, 0, 10000)
		_drive_bars[i].value = state[b + L.F_DRIVE]
		_burnout_labels[i].text = "BURNOUT" if state[b + L.F_BURNOUT] != 0 else ""
	if _callout_time > 0:
		_callout_time -= 1
		if _callout_time == 0: _callout.text = ""
	if _banner_time > 0:
		_banner_time -= 1
		if _banner_time == 0: _banner.text = ""
