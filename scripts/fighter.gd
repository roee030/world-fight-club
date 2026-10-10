extends CharacterBody3D
class_name GameFighter

signal health_changed(who: int, value: float)
signal meter_changed(who: int, value: float)
signal defeated(who: int)
signal combo_changed(who: int, hits: int)
signal strike_landed(attacker: int, defender: int, move: String, blocked: bool, combo: int)
signal attack_started(attacker: int, move: String)
## A named combo string completed (data/combos.json): name, total combo damage.
signal combo_string(who: int, name: String, damage: float)
## This fighter escaped the rival's combo with the combo breaker.
signal combo_broken(who: int)

const MOVES := {
	"light": {"duration": 0.46, "startup": 0.12, "active": 0.09, "cancel_from": 0.205, "cancel_to": 0.34, "damage": 7.0, "reach": 1.32, "lunge": 2.45, "clip": "jab"},
	"heavy": {"duration": 0.66, "startup": 0.235, "active": 0.105, "cancel_from": 0.365, "cancel_to": 0.51, "damage": 14.0, "reach": 1.58, "lunge": 2.7, "clip": "hook"},
	"kick": {"duration": 0.72, "startup": 0.25, "active": 0.11, "cancel_from": 0.42, "cancel_to": 0.56, "damage": 15.0, "reach": 1.72, "lunge": 2.45, "clip": "kick"},
	"special": {"duration": 0.84, "startup": 0.28, "active": 0.13, "cancel_from": 0.51, "cancel_to": 0.65, "damage": 23.0, "reach": 2.18, "lunge": 2.6, "clip": "kick"}
}
const INPUT_BUFFER_SECONDS := 0.34
# Combo rules live in data/combos.json (routes, scaling, strings, breaker).
const MAX_COMBO_HITS := 4
const COMBO_DATA_PATH := "res://data/combos.json"
static var _combo_data: Dictionary = {}
# Special Energy economy. MAX spends SPECIAL_COST; FINISH (SP) needs the full
# bar. Clean hits charge the attacker, blocked hits charge it a little, and the
# defender receives comeback energy from the damage it actually takes.
const SPECIAL_COST := 55.0
# Global scale for ordinary hits so rounds last long enough to read the rival
# and build Special Energy (play-testing: players died in a handful of hits).
const DAMAGE_SCALE := 0.6
const METER_HIT_BASE := 3.5
const METER_HIT_DAMAGE_SCALE := 0.55
const METER_BLOCKED_ATTACKER := 2.5
const METER_DEFENDER_DAMAGE_SCALE := 0.32
const CpuBrainScript = preload("res://scripts/cpu_brain.gd")
const FighterTuning = preload("res://scripts/fighter_tuning.gd")

var who := 0
var character_id := "bennet"
var is_cpu := false
var cpu_level := 1
var ai_mode := "approach"
var input_axis := 0.0
var input_depth := 0.0
var input_jump := false
var _jump_was_down := false
var _jump_pressed := false
var _air_vx := 0.0
var input_block := false
var input_crouch := false
var attack_request := ""
var buffered_attack := ""
var buffer_time := 0.0
var health := 100.0
var meter := 0.0
var facing := 1.0
var attack_facing := 1.0
var busy := 0.0
var stun := 0.0
var invulnerable := 0.0
var hit_stop := 0.0
var _paused_velocity := Vector3.ZERO
var attack_time := 0.0
var attack_duration := 0.0
var attack_kind := ""
var attack_clip := ""
var attack_hit := false
var attack_confirmed := false
var combo_count := 0
var combo_timer := 0.0
var combo_moves: Array[String] = []
var combo_damage := 0.0
var _pending_string := ""
var _guard_was_down := false
var _last_guard_tap := -10.0
var _combat_clock := 0.0
var attack_lunge := 0.0
var lunge_speed := 0.0
var round_over := false
var knockdown_time := 0.0
var recovery_time := 0.0
var getup_pending := false
var knockdown_rotation := 0.0
var jump_crossing := false
var jump_lane_target_z := 0.0
var jump_phase := ""
var jump_phase_time := 0.0
var rival: GameFighter
var arena_bounds := 5.8
var arena_depth_bounds := 0.82
var ai_clock := 0.0
var cpu_brain: RefCounted
var _visual: Dictionary
var _body_mesh: Node3D
var _animation_paused := false
var _collider: CollisionShape3D
var _standing_capsule: CapsuleShape3D
var cinematic_locked := false
var _authored_hit_ids := {}


func enter_cinematic_lock(anchor: Vector3, facing_value: float) -> void:
	cinematic_locked = true
	_authored_hit_ids.clear()
	position = anchor
	facing = 1.0 if facing_value >= 0.0 else -1.0
	velocity = Vector3.ZERO
	input_axis = 0.0
	input_depth = 0.0
	input_jump = false
	input_block = false
	input_crouch = false
	attack_request = ""
	buffered_attack = ""
	buffer_time = 0.0
	attack_kind = ""
	attack_time = 0.0
	busy = 0.0
	stun = 0.0
	hit_stop = 0.0
	knockdown_time = 0.0
	recovery_time = 0.0
	getup_pending = false
	if not _visual.is_empty():
		_visual.sprite.flip_h = facing < 0.0
		_visual.sprite.rotation.z = 0.0
		_visual.sprite.position.y = float(_visual.ground_y)
		_visual.motion.freeze_motion(true)
		_visual.sprite.play("idle")


func enter_defeated_cinematic_lock(anchor: Vector3, facing_value: float) -> void:
	enter_cinematic_lock(anchor, facing_value)
	round_over = true
	knockdown_time = 999.0
	if not _visual.is_empty():
		_visual.motion.play_state("knockdown", false)
		_visual.motion.freeze_motion(true)
		_visual.sprite.play("knockdown")
		_visual.sprite.frame = _visual.sprite.sprite_frames.get_frame_count("knockdown") - 1
		_visual.sprite.pause()


func apply_authored_hit(event_id: String, damage: float, direction: float, reaction: String) -> bool:
	if not cinematic_locked or event_id.is_empty() or _authored_hit_ids.has(event_id) or health <= 0.0 or damage <= 0.0:
		return false
	_authored_hit_ids[event_id] = true
	health = maxf(0.0, health - damage)
	velocity = Vector3.ZERO
	if not _visual.is_empty():
		facing = -signf(direction)
		_visual.sprite.flip_h = facing < 0.0
		var clip := "knockdown" if reaction == "finish_fall" or health <= 0.0 else "hit"
		_visual.sprite.play(clip)
		if health <= 0.0:
			_visual.sprite.frame = _visual.sprite.sprite_frames.get_frame_count(clip) - 1
			_visual.sprite.pause()
	health_changed.emit(who, health)
	if health <= 0.0:
		round_over = true
		defeated.emit(who)
	return true


func exit_cinematic_lock() -> void:
	cinematic_locked = false
	velocity = Vector3.ZERO
	attack_request = ""
	buffered_attack = ""
	buffer_time = 0.0
	input_axis = 0.0
	input_depth = 0.0
	input_jump = false
	input_block = false
	if not _visual.is_empty():
		_visual.motion.freeze_motion(false)
		if health > 0.0:
			_visual.sprite.play("idle")


func setup(id: String, player_index: int, cpu: bool, level: int = 1) -> void:
	character_id = id
	who = player_index
	is_cpu = cpu
	cpu_level = level


func _ready() -> void:
	floor_snap_length = 0.28
	_body_mesh = Node3D.new()
	_body_mesh.name = "AnimatedBody"
	add_child(_body_mesh)
	_visual = FighterVisual.build(character_id)
	_body_mesh.add_child(_visual.root)
	facing = 1.0 if who == 0 else -1.0
	_visual.sprite.flip_h = facing < 0.0
	_standing_capsule = CapsuleShape3D.new()
	_standing_capsule.radius = 0.32 * float(_visual.height_m) / 1.82
	_standing_capsule.height = float(_visual.height_m)
	_collider = CollisionShape3D.new()
	_collider.shape = _standing_capsule
	_collider.position.y = float(_visual.height_m) * 0.5
	add_child(_collider)
	# Fighter collision is resolved deliberately in the pair-separation step.
	# This lets a real jump pass over the rival while both still collide with the floor.
	collision_layer = 2
	collision_mask = 1
	health = max_health()
	if is_cpu:
		ai_mode = "approach"


func max_health() -> float:
	return FighterTuning.value(character_id, "hp")


func set_controls(axis: float, jump: bool, block: bool, crouch: bool, requested_attack: String, depth: float = 0.0) -> void:
	if cinematic_locked:
		return
	input_axis = clampf(axis, -1.0, 1.0)
	input_depth = clampf(depth, -1.0, 1.0)
	if jump and not _jump_was_down: _jump_pressed = true
	_jump_was_down = jump
	input_jump = jump
	if block and not _guard_was_down:
		# Combo breaker: a second GUARD tap within the window while being hit.
		if stun > 0.0 and _combat_clock - _last_guard_tap <= float(combo_data().breaker.double_tap):
			try_combo_breaker()
		_last_guard_tap = _combat_clock
	_guard_was_down = block
	input_block = block
	input_crouch = crouch
	if requested_attack != "":
		attack_request = requested_attack


func _physics_process(delta: float) -> void:
	if cinematic_locked:
		return
	if rival == null or round_over:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		if not is_on_floor(): velocity.y -= 22.0 * delta
		move_and_slide()
		_clamp_to_arena()
		return
	_combat_clock += delta
	if is_cpu:
		_run_cpu(delta)
	if attack_request != "":
		if stun <= 0.0 and knockdown_time <= 0.0 and recovery_time <= 0.0:
			buffered_attack = attack_request
			buffer_time = INPUT_BUFFER_SECONDS
		attack_request = ""
	if hit_stop > 0.0:
		hit_stop = maxf(0.0, hit_stop - delta)
		if not _animation_paused:
			_paused_velocity = velocity
			_visual.sprite.pause()
			_visual.motion.freeze_motion(true)
			_animation_paused = true
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if _animation_paused:
		_visual.sprite.play()
		_visual.motion.freeze_motion(false)
		_animation_paused = false
		velocity = _paused_velocity
	if buffer_time > 0.0:
		buffer_time = maxf(0.0, buffer_time - delta)
		if buffer_time <= 0.0: buffered_attack = ""
	# Facing is free only in neutral. Committed attacks and hit reactions keep
	# their direction so crossing bodies cannot reverse a strike mid-animation.
	if attack_kind == "" and stun <= 0.0 and knockdown_time <= 0.0 and recovery_time <= 0.0 and is_on_floor():
		var facing_delta_x := rival.global_position.x - global_position.x
		if absf(facing_delta_x) > 0.08: facing = signf(facing_delta_x)
	if attack_kind == "": _visual.sprite.flip_h = facing < 0.0
	busy = maxf(0.0, busy - delta)
	stun = maxf(0.0, stun - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	knockdown_time = maxf(0.0, knockdown_time - delta)
	recovery_time = maxf(0.0, recovery_time - delta)
	if getup_pending and knockdown_time <= 0.0 and recovery_time <= 0.0:
		recovery_time = 0.25
		getup_pending = false
		invulnerable = maxf(invulnerable, 0.32)
	if recovery_time > 0.0 and recovery_time <= delta:
		_visual.sprite.rotation.z = 0.0
		_visual.sprite.position.y = float(_visual.ground_y)
	if combo_count > 0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0 and attack_kind == "": _clear_combo()
	if attack_kind != "":
		attack_time = maxf(0.0, attack_time - delta)
		var move: Dictionary = MOVES[attack_kind]
		var elapsed := attack_duration - attack_time
		if not attack_hit and elapsed >= move.startup and elapsed <= move.startup + move.active:
			_try_hit()
		if _can_chain_now(move, elapsed) and buffer_time > 0.0 and _can_chain_to(buffered_attack):
			var next_move := buffered_attack
			buffered_attack = ""
			buffer_time = 0.0
			_start_attack(next_move, true)
		elif attack_time <= 0.0:
			_finish_attack()
	var speed := FighterTuning.value(character_id, "walk_speed")
	if is_cpu: speed *= 0.90 + 0.035 * cpu_level
	var action_allowed := stun <= 0.0 and busy <= 0.0 and attack_kind == "" and knockdown_time <= 0.0 and recovery_time <= 0.0
	var move_input := input_axis if action_allowed and not input_block else 0.0
	if input_crouch: move_input *= 0.65
	if move_input * facing < 0.0: move_input *= FighterTuning.motion("back_factor")
	var acceleration := FighterTuning.motion("walk_accel") if absf(move_input) > 0.01 else (FighterTuning.motion("walk_decel") if action_allowed else FighterTuning.motion("stun_decel"))
	if is_on_floor():
		velocity.x = move_toward(velocity.x, move_input * speed, acceleration * delta)
	elif action_allowed:
		# Committed arc: horizontal speed was fixed at take-off; the air only drifts.
		var drift := clampf(input_axis, -1.0, 1.0) * speed * FighterTuning.motion("air_drift")
		velocity.x = move_toward(velocity.x, _air_vx + drift, FighterTuning.motion("air_accel") * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FighterTuning.motion("stun_decel") * delta)
	var depth_input := input_depth if action_allowed and not input_block and not input_crouch else 0.0
	velocity.z = move_toward(velocity.z, depth_input * 1.7, (12.0 if absf(depth_input) > 0.01 else 17.0) * delta)
	if jump_crossing and not is_on_floor():
		var lane_error := jump_lane_target_z - global_position.z
		velocity.z = move_toward(velocity.z, clampf(lane_error * 6.0, -2.4, 2.4), 12.0 * delta)
	elif jump_crossing and is_on_floor():
		jump_crossing = false
	# Lunge is part of the committed attack only. Being hit cancels the move and
	# must also cancel its residual forward impulse (otherwise hit-stun can look
	# like a fresh punch or make the victim slide into the attacker).
	if attack_lunge > 0.0 and attack_kind != "" and stun <= 0.0 and knockdown_time <= 0.0:
		velocity.x = lunge_speed
		attack_lunge = maxf(0.0, attack_lunge - delta)
	else:
		attack_lunge = 0.0
		lunge_speed = 0.0
	if _jump_pressed and is_on_floor() and action_allowed:
		_air_vx = move_input * speed
		velocity.y = FighterTuning.motion("jump_velocity")
		jump_phase = "takeoff"
		jump_phase_time = 0.10
		jump_crossing = absf(rival.global_position.x - global_position.x) < 1.65 and signf(rival.global_position.x - global_position.x) == signf(input_axis) and absf(rival.global_position.z - global_position.z) < 0.54
		if jump_crossing:
			jump_lane_target_z = clampf(rival.global_position.z + (-0.60 if who == 0 else 0.60), -arena_depth_bounds, arena_depth_bounds)
	if not is_on_floor(): velocity.y -= (FighterTuning.motion("gravity_rise") if velocity.y > 0.0 else FighterTuning.motion("gravity_fall")) * delta
	elif velocity.y < 0.0: velocity.y = 0.0
	if action_allowed and not input_block and not input_crouch and buffered_attack != "":
		var opening_move := buffered_attack
		buffered_attack = ""
		buffer_time = 0.0
		_start_attack(opening_move)
	if input_block and action_allowed:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	var grounded_before_move := is_on_floor()
	move_and_slide()
	_clamp_to_arena()
	if grounded_before_move and not is_on_floor():
		jump_phase = "takeoff"
		jump_phase_time = 0.10
	elif not grounded_before_move and is_on_floor():
		jump_phase = "landing"
		jump_phase_time = 0.11
	if jump_phase_time > 0.0:
		jump_phase_time = maxf(0.0, jump_phase_time - delta)
	var separation := global_position.x - rival.global_position.x
	var lane_separation := absf(global_position.z - rival.global_position.z)
	if is_on_floor() and rival.is_on_floor() and knockdown_time <= 0.0 and rival.knockdown_time <= 0.0 and lane_separation < 0.54 and absf(separation) < 1.05:
		var side := 1.0 if separation >= 0.0 else -1.0
		global_position.x = rival.global_position.x + side * 1.05
		velocity.x = 0.0
		_clamp_to_arena()
		# Pinned against the edge: the rival yields instead of pushing this
		# fighter out of the arena.
		if absf(global_position.x - rival.global_position.x) < 1.05:
			rival.global_position.x = global_position.x - side * 1.05
			rival._clamp_to_arena()
	_animate()
	input_jump = false
	_jump_pressed = false


# The arena edge is the visible screen edge (main.gd sets arena_bounds from the
# fight camera), so nothing may leave it: walking, knockback, lunges or pushes.
func _clamp_to_arena() -> void:
	var clamped_x := clampf(position.x, -arena_bounds, arena_bounds)
	if clamped_x != position.x and signf(velocity.x) == signf(position.x):
		velocity.x = 0.0
	position.x = clamped_x
	position.z = clampf(position.z, -arena_depth_bounds, arena_depth_bounds)


func _run_cpu(delta: float) -> void:
	ai_clock += delta
	if cpu_brain == null or cpu_brain.level != cpu_level:
		cpu_brain = CpuBrainScript.new(cpu_level)
	var controls: Dictionary = cpu_brain.decide(self, rival, delta)
	ai_mode = cpu_brain.intent
	if stun > 0.0 or knockdown_time > 0.0 or recovery_time > 0.0:
		attack_request = ""
	set_controls(float(controls.axis), false, bool(controls.block), bool(controls.crouch), str(controls.request), float(controls.depth))


func _start_attack(kind: String, chained: bool = false) -> void:
	if kind == "special" and meter < SPECIAL_COST: return
	if not MOVES.has(kind): return
	if chained and not _can_chain_to(kind): return
	if kind == "special":
		meter -= SPECIAL_COST
		meter_changed.emit(who, meter)
	var move: Dictionary = MOVES[kind]
	attack_kind = kind
	attack_facing = facing
	attack_hit = false
	attack_confirmed = false
	attack_duration = move.duration
	attack_time = move.duration
	busy = move.duration
	attack_lunge = 0.12 if kind == "light" else (0.15 if kind == "heavy" else 0.16)
	lunge_speed = attack_facing * move.lunge
	var clip_name := str(move.clip)
	_visual.sprite.animation = clip_name
	attack_clip = clip_name
	_visual.sprite.set_frame_and_progress(0, 0.0)
	_visual.sprite.play()
	_animate()
	attack_started.emit(who, kind)


func _can_chain_now(move: Dictionary, elapsed: float) -> bool:
	return attack_confirmed and elapsed >= move.cancel_from and elapsed <= move.cancel_to and combo_count < MAX_COMBO_HITS


func _can_chain_to(next_move: String) -> bool:
	if attack_kind == "special" or combo_count >= MAX_COMBO_HITS: return false
	var routes: Dictionary = combo_data().routes
	return next_move in routes.get(attack_kind, [])


static func combo_data() -> Dictionary:
	if _combo_data.is_empty():
		var file := FileAccess.open(COMBO_DATA_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		_combo_data = parsed if parsed is Dictionary else {"max_hits": 4, "scaling": [1.0], "finale_relief": 0.5, "routes": {}, "universal": [], "signature": {}, "breaker": {"cost": 35, "push": 3.4, "invulnerable": 0.45, "double_tap": 0.35}}
	return _combo_data


func combo_strings() -> Array:
	# This fighter's signature string first, then the universal strings.
	var strings: Array = []
	var signature: Dictionary = combo_data().signature.get(character_id, {})
	if not signature.is_empty():
		strings.append(signature)
	strings.append_array(combo_data().universal)
	return strings


func _completed_string(moves: Array) -> Dictionary:
	for entry in combo_strings():
		if Array(entry.sequence) == moves:
			return entry
	return {}


func _string_is_terminal(moves: Array) -> bool:
	# Terminal when no longer string of this fighter continues from here.
	for entry in combo_strings():
		var sequence: Array = entry.sequence
		if sequence.size() > moves.size() and sequence.slice(0, moves.size()) == moves:
			return false
	return true


func _apply_finale(kind: String) -> void:
	if rival == null or rival.health <= 0.0:
		return
	match kind:
		"knockback": rival.velocity.x = attack_facing * 5.2
		"knockdown": rival.knock_down_and_recover()
		"stagger": rival.hit_stop = maxf(rival.hit_stop, 0.2)


func try_combo_breaker() -> bool:
	# Escape the rival's combo: costs Special Energy, pushes the rival back and
	# grants a short invulnerability. Breaking ends that combo, so it can be
	# used once per combo.
	var rules: Dictionary = combo_data().breaker
	if stun <= 0.0 or knockdown_time > 0.0 or round_over or cinematic_locked or rival == null:
		return false
	if rival.combo_count < 1 or meter < float(rules.cost):
		return false
	meter -= float(rules.cost)
	meter_changed.emit(who, meter)
	var away := signf(rival.global_position.x - global_position.x)
	rival._finish_attack()
	rival._clear_combo()
	rival.stun = maxf(rival.stun, 0.25)
	rival.busy = maxf(rival.busy, 0.25)
	rival.velocity.x = away * float(rules.push)
	stun = 0.0
	busy = 0.0
	hit_stop = 0.0
	invulnerable = float(rules.invulnerable)
	combo_broken.emit(who)
	return true


func _finish_attack() -> void:
	var ended_move := attack_kind
	var connected := attack_confirmed
	attack_kind = ""
	attack_clip = ""
	attack_time = 0.0
	attack_duration = 0.0
	attack_hit = false
	attack_confirmed = false
	busy = 0.0
	attack_lunge = 0.0
	buffered_attack = ""
	buffer_time = 0.0
	if ended_move == "special" or not connected: _clear_combo()


func _try_hit() -> void:
	var dx := rival.global_position.x - global_position.x
	var distance := absf(dx)
	var move: Dictionary = MOVES[attack_kind]
	if distance > move.reach or dx * attack_facing <= 0.0 or absf(rival.global_position.z - global_position.z) > 0.58: return
	if absf(rival.global_position.y - global_position.y) > 0.95 and attack_kind != "special": return
	# Ducking evades a high heavy strike; the attacker still spends its active window.
	if attack_kind == "heavy" and rival.input_crouch and rival.is_on_floor():
		attack_hit = true
		return
	attack_hit = true
	var blocked := rival.input_block and rival.stun <= 0.0 and rival.is_on_floor()
	if blocked:
		# Guard absorbs most of the strike, but it must still deal visible chip
		# damage. Previously this branch only charged the attacker's meter, so a
		# guarding CPU looked completely immune and its HP bar never moved.
		rival.receive_hit(float(move.damage) * DAMAGE_SCALE, attack_facing, attack_kind)
		_gain_meter(METER_BLOCKED_ATTACKER)
		rival.stun = maxf(rival.stun, 0.18)
		rival.hit_stop = maxf(rival.hit_stop, 0.045)
		hit_stop = maxf(hit_stop, 0.045)
		_clear_combo()
		strike_landed.emit(who, rival.who, attack_kind, true, combo_count)
		return
	var damage: float = move.damage * DAMAGE_SCALE
	damage *= FighterTuning.value(character_id, "damage_mult")
	if is_cpu: damage *= 0.92 + 0.06 * cpu_level
	if attack_kind == "special": damage *= 1.18
	if attack_kind == "light": damage *= FighterTuning.value(character_id, "light_mult")
	attack_confirmed = true
	# A hit continues the combo only while the rival is still reeling from the
	# previous one (standard true-combo counting), however it was input.
	var continues := combo_count > 0 and (rival.stun > 0.0 or rival.hit_stop > 0.0)
	if combo_count > 0 and not continues:
		_clear_combo()
	combo_moves.append(attack_kind)
	var rules := combo_data()
	var scaling: Array = rules.scaling
	var hit_scale := float(scaling[mini(combo_moves.size() - 1, scaling.size() - 1)])
	var completed := _completed_string(combo_moves)
	var terminal := not completed.is_empty() and _string_is_terminal(combo_moves)
	if terminal:
		# The finale keeps more of its damage so the payoff feels strong.
		hit_scale = 1.0 - (1.0 - hit_scale) * float(rules.finale_relief)
	damage *= hit_scale
	combo_count += 1
	combo_damage += damage
	combo_timer = 0.9
	combo_changed.emit(who, combo_count)
	rival.receive_hit(damage, attack_facing, attack_kind)
	if not completed.is_empty():
		_pending_string = str(completed.name)
	if terminal:
		_apply_finale(str(completed.get("finale", "none")))
		combo_string.emit(who, _pending_string, combo_damage)
		_pending_string = ""
	rival.hit_stop = maxf(rival.hit_stop, 0.075 if attack_kind != "light" else 0.055)
	hit_stop = maxf(hit_stop, 0.055 if attack_kind == "light" else 0.075)
	if attack_kind != "special":
		_gain_meter(METER_HIT_BASE + damage * METER_HIT_DAMAGE_SCALE)
	strike_landed.emit(who, rival.who, attack_kind, false, combo_count)


func receive_hit(damage: float, direction: float, kind: String) -> void:
	if cinematic_locked:
		return
	if invulnerable > 0.0 or round_over or knockdown_time > 0.0 or recovery_time > 0.0: return
	var blocked := input_block and stun <= 0.0 and is_on_floor()
	if blocked:
		damage *= 0.22
		stun = 0.18
	else:
		stun = 0.34 if kind == "light" else (0.48 if kind in ["heavy", "kick"] else 0.55)
		_clear_combo()
		attack_kind = ""
		attack_clip = ""
		attack_time = 0.0
		attack_duration = 0.0
		attack_hit = false
		attack_confirmed = false
		attack_lunge = 0.0
		lunge_speed = 0.0
		busy = stun
		buffered_attack = ""
		buffer_time = 0.0
		attack_request = ""
	var taken := minf(health, damage)
	health = maxf(0.0, health - damage)
	if taken > 0.0: _gain_meter(taken * METER_DEFENDER_DAMAGE_SCALE)
	var defeated_now := health <= 0.0
	if defeated_now:
		round_over = true
		knockdown_time = 999.0
		getup_pending = false
		stun = 999.0
		busy = 999.0
	velocity.x = direction * (0.75 if blocked else (2.3 if kind == "light" else 2.85))
	if not blocked:
		facing = -signf(direction)
		_visual.sprite.flip_h = facing < 0.0
	if not defeated_now and not blocked and kind == "special":
		# A special knockback ends in a brief grounded knockdown and visible get-up.
		knockdown_time = 0.62
		getup_pending = true
		stun = knockdown_time
		busy = knockdown_time
		# Keep the capsule active so the fighter stays on the arena floor.
		knockdown_rotation = 0.0
		_visual.sprite.rotation.z = 0.0
		_visual.sprite.position.y = float(_visual.ground_y)
		_visual.sprite.scale = Vector3.ONE
	# Switch to hit/fall art immediately, before either fighter's hit-stop can
	# freeze the victim on the last frame of a punch.
	_animate()
	if defeated_now and not _visual.is_empty():
		_visual.motion.play_state("knockdown", false)
		_visual.sprite.play("knockdown")
		_visual.sprite.frame = _visual.sprite.sprite_frames.get_frame_count("knockdown") - 1
		_visual.sprite.pause()
	invulnerable = 0.12
	health_changed.emit(who, health)
	if defeated_now: defeated.emit(who)


func reset_round(position_x: float, health_value: float = 100.0, keep_meter: bool = false) -> void:
	exit_cinematic_lock()
	_authored_hit_ids.clear()
	position = Vector3(position_x, 0.0, 0.0)
	facing = 1.0 if who == 0 else -1.0
	attack_facing = facing
	velocity = Vector3.ZERO
	health = health_value
	# Special Energy carries over between rounds of one match; a new match
	# creates new fighters, which start empty.
	if not keep_meter: meter = 0.0
	stun = 0.0
	busy = 0.0
	attack_kind = ""
	attack_clip = ""
	attack_time = 0.0
	attack_duration = 0.0
	attack_hit = false
	attack_confirmed = false
	attack_lunge = 0.0
	lunge_speed = 0.0
	hit_stop = 0.0
	_paused_velocity = Vector3.ZERO
	_animation_paused = false
	knockdown_time = 0.0
	recovery_time = 0.0
	getup_pending = false
	knockdown_rotation = 0.0
	jump_crossing = false
	# A fresh brain each match; learning carries across the rounds of one match.
	if cpu_brain != null and not keep_meter: cpu_brain = null
	jump_phase = ""
	jump_phase_time = 0.0
	_collider.disabled = false
	_visual.sprite.rotation.z = 0.0
	_visual.sprite.position.y = float(_visual.ground_y)
	combo_timer = 0.0
	combo_count = 0
	combo_moves.clear()
	combo_damage = 0.0
	_pending_string = ""
	buffered_attack = ""
	buffer_time = 0.0
	# round_over already protects both fighters during the announcer intro. Keeping
	# a second invulnerability timer here made the first attacks after FIGHT! miss.
	invulnerable = 0.0
	input_block = false
	input_crouch = false
	input_axis = 0.0
	input_depth = 0.0
	attack_request = ""
	round_over = false
	if not _visual.is_empty():
		_visual.sprite.flip_h = facing < 0.0
		_visual.motion.set_facing(facing)
		_visual.motion.play_state("idle", true)
	combo_changed.emit(who, 0)
	health_changed.emit(who, health)
	meter_changed.emit(who, meter)


func knock_down_and_recover() -> void:
	# A survivable heavy blow (finisher that did not KO): brief grounded
	# knockdown, then the normal get-up with a short invulnerability window.
	attack_kind = ""
	attack_clip = ""
	attack_time = 0.0
	buffered_attack = ""
	buffer_time = 0.0
	attack_request = ""
	knockdown_time = 0.62
	getup_pending = true
	stun = knockdown_time
	busy = knockdown_time
	velocity = Vector3.ZERO
	if not _visual.is_empty():
		_visual.sprite.rotation.z = 0.0
		_visual.sprite.position.y = float(_visual.ground_y)
	_animate()


func _gain_meter(amount: float) -> void:
	if amount <= 0.0: return
	meter = minf(100.0, meter + amount)
	meter_changed.emit(who, meter)


func _clear_combo() -> void:
	if not _pending_string.is_empty():
		# A shorter string completed and the combo stopped there.
		combo_string.emit(who, _pending_string, combo_damage)
		_pending_string = ""
	combo_moves.clear()
	combo_damage = 0.0
	if combo_count != 0:
		combo_count = 0
		combo_timer = 0.0
		combo_changed.emit(who, 0)


func _animate() -> void:
	var sprite = _visual.sprite
	var clip := "idle"
	if knockdown_time > 0.0: clip = "knockdown"
	elif recovery_time > 0.0: clip = "getup"
	elif stun > 0.0: clip = "hit"
	elif input_block and is_on_floor(): clip = "block"
	elif attack_kind != "": clip = attack_clip
	elif input_crouch and is_on_floor(): clip = "crouch"
	elif not is_on_floor(): clip = "jump_start" if jump_phase == "takeoff" and jump_phase_time > 0.0 else "jump_air"
	elif jump_phase == "landing" and jump_phase_time > 0.0: clip = "jump_land"
	elif absf(velocity.x) > 0.35:
		clip = "walk_forward" if velocity.x * facing > 0.0 else "walk_back"
	if sprite.animation != clip: sprite.play(clip)
	sprite.flip_h = (attack_facing if attack_kind != "" else facing) < 0.0
	var motion_state := clip
	if knockdown_time > 0.0: motion_state = "knockdown"
	elif recovery_time > 0.0: motion_state = "getup"
	var target_duration := 0.0
	if attack_kind != "": target_duration = attack_duration
	elif knockdown_time > 0.0: target_duration = maxf(knockdown_time, 0.08)
	elif recovery_time > 0.0: target_duration = maxf(recovery_time, 0.08)
	elif stun > 0.0: target_duration = maxf(stun, 0.08)
	_visual.motion.play_state(motion_state, false, target_duration)
	_visual.motion.set_facing(attack_facing if attack_kind != "" else facing)
	var walking := clip in ["walk_forward", "walk_back"]
	if knockdown_time <= 0.0 and recovery_time <= 0.0:
		sprite.position.y = float(_visual.ground_y)
		sprite.scale.y = 1.0
		sprite.rotation.z = 0.0
	if recovery_time <= 0.0 and knockdown_time <= 0.0 and is_on_floor():
		sprite.rotation.z = 0.0
	_visual.shadow.scale.x = 1.45 + (0.15 if not is_on_floor() else 0.0)
	_visual.shadow.scale.z = 0.63 + (0.07 if not is_on_floor() else 0.0)
	# The visual root follows the fighter capsule into the air. Counter that world
	# height so the projected contact shadow remains attached to the arena floor.
	_visual.shadow.position.y = 0.018 - global_position.y
