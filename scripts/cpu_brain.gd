extends RefCounted

## Adaptive CPU opponent.
##
## The brain watches the player and learns three things during a match:
## - which attack usually follows which (an order-1 Markov table),
## - how often the player guards when the CPU attacks,
## - the distance from which the player likes to attack.
## Each "think" tick it picks an intent (spacing, pressure, bait, defend) by a
## weighted random choice shaped by those observations, the health lead and the
## difficulty level, so it adapts without becoming a fixed, readable pattern.
## Reactions (guard, whiff punish) wait for a level-based reaction time.
## Levels run from 0 (EASY in data/difficulty.json) to 4 (the boss).

const ATTACKS := ["light", "heavy", "kick", "special"]
const INTENTS := ["space", "pressure", "bait", "defend"]

var level := 1
var intent := "space"
var intent_time := 0.0
var think_time := 0.0
var spacing_jitter := 0.0
var guard_time := 0.0
var guard_decided_for := -1
var punish_decided_for := -1
var pre_guard_time := 0.0
var sidestep_time := 0.0
var sidestep_dir := 0.0
var attack_cooldown := 0.0
var string_follow := ""
var observed_attack_id := 0
var _rival_was_attacking := false
var _rival_attack_kind := ""
var _rival_attack_distance := 0.0
var _rival_attack_whiffed := false
var _cpu_was_attacking := false
var _cpu_attack_rival_guarded := false
# Learned statistics (decayed so recent behaviour matters most).
var transitions := {}
var last_player_attack := ""
var player_attack_count := 0.0
var player_guard_rate := 0.3
var player_attack_range := 1.4
var intent_history: Array[String] = []
var attack_history: Array[String] = []
# Combo plan: the string the CPU is executing (same data as the player).
var combo_plan: Array = []
var _plan_made := false
var _requested_at_hits := -1


func _init(cpu_level: int = 1) -> void:
	level = clampi(cpu_level, 0, 4)
	for from in ATTACKS + [""]:
		transitions[from] = {}
		for to in ATTACKS: transitions[from][to] = 0.5


func reaction_time() -> float:
	return 0.20 - 0.025 * float(level)


func guard_skill() -> float:
	return 0.26 + 0.12 * float(level)


func observe(cpu, rival, delta: float) -> void:
	# Track the player's attack lifecycle to learn habits and spot whiffs.
	var attacking: bool = rival.attack_kind != ""
	if attacking and (not _rival_was_attacking or rival.attack_kind != _rival_attack_kind):
		observed_attack_id += 1
		_rival_attack_kind = rival.attack_kind
		_rival_attack_distance = absf(rival.global_position.x - cpu.global_position.x)
		_rival_attack_whiffed = false
		_learn_player_attack(rival.attack_kind, _rival_attack_distance)
	if attacking:
		var move: Dictionary = rival.MOVES.get(rival.attack_kind, {})
		var elapsed: float = rival.attack_duration - rival.attack_time
		if not move.is_empty() and elapsed > float(move.startup) + float(move.active) and not rival.attack_confirmed:
			_rival_attack_whiffed = true
	_rival_was_attacking = attacking
	# Learn how often the player guards CPU attacks.
	var cpu_attacking: bool = cpu.attack_kind != ""
	if cpu_attacking and cpu.attack_hit and not _cpu_attack_rival_guarded:
		_cpu_attack_rival_guarded = true
		var guarded: bool = rival.input_block and not cpu.attack_confirmed
		player_guard_rate = lerpf(player_guard_rate, 1.0 if guarded else 0.0, 0.18)
	if not cpu_attacking and _cpu_was_attacking:
		_cpu_attack_rival_guarded = false
	_cpu_was_attacking = cpu_attacking


func _learn_player_attack(kind: String, distance: float) -> void:
	var row: Dictionary = transitions.get(last_player_attack, transitions[""])
	for move in row:
		row[move] = row[move] * 0.9
	row[kind] = float(row.get(kind, 0.0)) + 1.0
	last_player_attack = kind
	player_attack_count += 1.0
	player_attack_range = lerpf(player_attack_range, distance, 0.2)


func predicted_player_attack() -> Dictionary:
	# Most likely next player attack and how confident the brain is (0..1).
	var row: Dictionary = transitions.get(last_player_attack, transitions[""])
	var total := 0.0
	var best := "light"
	var best_weight := -1.0
	for move in row:
		total += float(row[move])
		if float(row[move]) > best_weight:
			best_weight = float(row[move])
			best = move
	var confidence := best_weight / maxf(0.001, total)
	# Confidence only means something after enough observations.
	confidence *= clampf(player_attack_count / 8.0, 0.0, 1.0)
	return {"move": best, "confidence": confidence}


func decide(cpu, rival, delta: float) -> Dictionary:
	observe(cpu, rival, delta)
	think_time -= delta
	intent_time -= delta
	guard_time = maxf(0.0, guard_time - delta)
	pre_guard_time = maxf(0.0, pre_guard_time - delta)
	sidestep_time = maxf(0.0, sidestep_time - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var controls := {"axis": 0.0, "block": false, "crouch": false, "request": "", "depth": 0.0}
	var dx: float = rival.global_position.x - cpu.global_position.x
	var dir: float = signf(dx) if absf(dx) > 0.01 else float(cpu.facing)
	var distance := absf(dx)
	var lane_gap: float = rival.global_position.z - cpu.global_position.z
	if cpu.stun > 0.0 or cpu.knockdown_time > 0.0 or cpu.recovery_time > 0.0:
		# Keep holding a committed guard through blockstun.
		controls.block = guard_time > 0.0
		# Combo breaker: higher levels escape long player combos more often.
		if cpu.stun > 0.0 and rival.combo_count >= 2 and cpu.meter >= float(cpu.combo_data().breaker.cost) and randf() < delta * breaker_rate():
			cpu.try_combo_breaker()
		return controls
	if intent_time <= 0.0:
		_choose_intent(cpu, rival)
	var rival_move: Dictionary = rival.MOVES.get(rival.attack_kind, {})
	var rival_elapsed: float = rival.attack_duration - rival.attack_time if not rival_move.is_empty() else 0.0
	var threatened: bool = not rival_move.is_empty() and distance <= float(rival_move.reach) + 0.35 and absf(lane_gap) < 0.6
	# 1. Whiff punish: the player's attack missed and is still recovering.
	if not rival_move.is_empty() and _rival_attack_whiffed and punish_decided_for != observed_attack_id and cpu.attack_kind == "" and rival_elapsed >= reaction_time():
		punish_decided_for = observed_attack_id
		var punish := "light" if rival.attack_time < 0.24 else "heavy"
		if distance <= float(cpu.MOVES[punish].reach) + 0.45 and randf() < 0.35 + 0.15 * float(level):
			controls.request = punish
			controls.axis = dir
			attack_cooldown = 0.25
			_record_attack(punish)
			return controls
	# 2. Guard decision, once per player attack, after the reaction time.
	if threatened and guard_decided_for != observed_attack_id and rival_elapsed >= reaction_time() and rival_elapsed <= float(rival_move.startup) + float(rival_move.active):
		guard_decided_for = observed_attack_id
		var chance := guard_skill() * (0.85 if intent == "pressure" else 1.0)
		var prediction := predicted_player_attack()
		if prediction.move == rival.attack_kind: chance += 0.45 * float(prediction.confidence)
		if randf() < clampf(chance, 0.05, 0.85):
			guard_time = float(rival_move.startup) + float(rival_move.active) - rival_elapsed + 0.08
		elif level >= 2 and randf() < 0.25:
			sidestep_time = 0.35
			sidestep_dir = -signf(lane_gap) if absf(lane_gap) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	if guard_time > 0.0 or pre_guard_time > 0.0:
		controls.block = true
		return controls
	if sidestep_time > 0.0:
		controls.depth = sidestep_dir
		return controls
	# 3. Continue a confirmed hit along a named combo string (hit-confirm: a
	# blocked opener never starts a plan, because blocked hits do not confirm).
	var own_move: Dictionary = cpu.MOVES.get(cpu.attack_kind, {})
	if not own_move.is_empty() and cpu.attack_confirmed:
		var own_elapsed: float = cpu.attack_duration - cpu.attack_time
		if not _plan_made:
			_plan_combo(cpu)
			_plan_made = true
		# One follow-up request per confirmed hit, inside the cancel window.
		if own_elapsed >= float(own_move.cancel_from) - 0.04 and cpu.combo_count < combo_plan.size() and _requested_at_hits != cpu.combo_count:
			controls.request = str(combo_plan[cpu.combo_count])
			_requested_at_hits = cpu.combo_count
			_record_attack(controls.request)
		return controls
	if cpu.combo_count == 0:
		combo_plan = []
		_plan_made = false
		_requested_at_hits = -1
	if cpu.attack_kind != "" or cpu.busy > 0.0:
		return controls
	# 4. Lane alignment: get back in line before trading hits.
	if absf(lane_gap) > 0.5:
		controls.depth = signf(lane_gap)
	# 5. Intent-driven footwork and attacks.
	var my_reach: float = float(cpu.MOVES.light.reach)
	var kick_reach: float = float(cpu.MOVES.kick.reach)
	match intent:
		"space":
			# Hover just outside the player's preferred attack range.
			var target := clampf(player_attack_range + 0.25 + spacing_jitter, 1.45, 2.3)
			if distance > target + 0.15: controls.axis = dir
			elif distance < target - 0.15: controls.axis = -dir
			if distance <= kick_reach and distance > my_reach and attack_cooldown <= 0.0 and randf() < delta * (0.6 + 0.2 * float(level)):
				controls.request = _pick_attack(cpu, distance)
		"pressure":
			if distance > my_reach - 0.1: controls.axis = dir
			if distance <= kick_reach and attack_cooldown <= 0.0 and randf() < delta * (1.6 + 0.5 * float(level)):
				controls.request = _pick_attack(cpu, distance)
		"bait":
			# Step in and straight back out to draw a whiff, then punish.
			var phase := fmod(intent_time, 0.8)
			controls.axis = dir if phase > 0.4 else -dir
		"defend":
			if distance < 1.6: controls.axis = -dir
			var prediction := predicted_player_attack()
			if distance < player_attack_range + 0.2 and float(prediction.confidence) > 0.45 and randf() < delta * 2.0 * float(prediction.confidence):
				pre_guard_time = 0.3
	if controls.request != "":
		attack_cooldown = randf_range(0.22, 0.5) - 0.04 * float(level)
		_record_attack(controls.request)
	return controls


func breaker_rate() -> float:
	# Chance per second of breaking a player combo (level 1 rarely, boss often).
	return [0.15, 0.35, 0.9, 1.6, 2.4][clampi(level, 0, 4)]


func _plan_combo(cpu) -> void:
	# Pick a string that starts with the move that just landed. Level gates the
	# length (L1-L2: 3 hits, L3+: signature). Some openers are left alone so
	# the CPU stays unpredictable.
	combo_plan = []
	if cpu.combo_moves.is_empty():
		return
	var max_length: int = [3, 3, 4, 4][clampi(level, 1, 4) - 1]
	var candidates: Array = []
	for entry in cpu.combo_strings():
		var sequence: Array = entry.sequence
		if sequence.size() <= max_length and sequence[0] == cpu.combo_moves[0]:
			candidates.append(sequence)
	if candidates.is_empty() or randf() < 0.1:
		return
	# Longer strings are favoured (weight = length squared) but short ones stay
	# possible. Copy: the plan must never alias the shared combo data.
	var weights := {}
	for i in range(candidates.size()):
		weights[str(i)] = float(candidates[i].size() * candidates[i].size())
	combo_plan = Array(candidates[int(_weighted_pick(weights))]).duplicate()
	# With enough energy, cap the string with the special move when the route allows.
	var routes: Dictionary = cpu.combo_data().routes
	if combo_plan.size() < cpu.MAX_COMBO_HITS and cpu.meter >= cpu.SPECIAL_COST and "special" in routes.get(combo_plan[-1], []) and randf() < 0.8:
		combo_plan.append("special")


func _choose_intent(cpu, rival) -> void:
	var lead: float = cpu.health / cpu.max_health() - rival.health / rival.max_health()
	var weights := {
		"space": 1.0,
		"pressure": 1.1 + 0.25 * float(level) - lead * 1.2,
		"bait": 0.25 + 0.15 * float(level) + (0.5 if player_attack_count > 6 else 0.0),
		"defend": 0.5 + lead * 1.5
	}
	# An aggressive player gets baited; a guarding player gets pressured
	# with long-range kicks and delayed attacks.
	if player_attack_count > 6: weights.bait += 0.4
	if player_guard_rate > 0.5: weights.pressure += 0.4
	# Never repeat the same intent three times in a row.
	if intent_history.size() >= 2 and intent_history[-1] == intent_history[-2]:
		weights[intent_history[-1]] = 0.05
	intent = _weighted_pick(weights)
	intent_history.append(intent)
	if intent_history.size() > 12: intent_history.pop_front()
	intent_time = randf_range(0.7, 1.6)
	spacing_jitter = randf_range(-0.2, 0.25)


func _pick_attack(cpu, distance: float) -> String:
	var weights := {"light": 1.2, "heavy": 0.8, "kick": 0.6}
	if distance > float(cpu.MOVES.light.reach): weights.light = 0.1
	if distance > float(cpu.MOVES.heavy.reach): weights.heavy = 0.1
	if player_guard_rate > 0.5: weights.kick += 0.6
	if cpu.meter >= cpu.SPECIAL_COST and distance <= float(cpu.MOVES.special.reach): weights["special"] = 0.5 + 0.1 * float(level)
	# Avoid three identical attacks in a row so strings stay unreadable.
	if attack_history.size() >= 2 and attack_history[-1] == attack_history[-2] and weights.has(attack_history[-1]):
		weights[attack_history[-1]] *= 0.15
	return _weighted_pick(weights)


func _record_attack(kind: String) -> void:
	attack_history.append(kind)
	if attack_history.size() > 24: attack_history.pop_front()


func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for key in weights: total += maxf(0.0, float(weights[key]))
	var roll := randf() * total
	for key in weights:
		roll -= maxf(0.0, float(weights[key]))
		if roll <= 0.0: return key
	return weights.keys()[0]
