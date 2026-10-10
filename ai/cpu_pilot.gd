extends RefCounted

## CPU opponent for the new engine. It reads the sim snapshot and returns an
## input bitmask, exactly like a human controller; replays record its inputs,
## so the CPU never needs to be deterministic or part of the sim.
## Level 1..4 scales reaction time, block rate, anti-air rate and combo use.

const L = preload("res://sim/layout.gd")

var level := 2
var rng := RandomNumberGenerator.new()
var _plan: Array[int] = []
var _cooldown := 0


func _init(cpu_level: int = 2, rng_seed: int = 12345) -> void:
	level = clampi(cpu_level, 1, 4)
	rng.seed = rng_seed


func decide(s: PackedInt32Array, me: int, moveset) -> int:
	var b := L.base(me)
	var o := L.base(s[b + L.F_TARGET])
	var dx := s[o + L.F_X] - s[b + L.F_X]
	var dist := absi(dx)
	var toward := L.IN_RIGHT if dx > 0 else L.IN_LEFT
	var away := L.IN_LEFT if dx > 0 else L.IN_RIGHT
	var my_state := s[b + L.F_STATE]
	if my_state in [L.S_HITSTUN, L.S_LAUNCHED, L.S_KNOCKDOWN, L.S_GETUP, L.S_KO]:
		_plan.clear()
		return 0
	if not _plan.is_empty():
		return _plan.pop_front()
	var opp_state := s[o + L.F_STATE]
	# Defend: block an incoming attack (low attacks need a crouch block).
	if opp_state == L.S_ATTACK and dist < 22000 and s[o + L.F_MOVE] >= 0:
		var m: Dictionary = moveset.moves[s[o + L.F_MOVE]]
		if rng.randf() < [0.0, 0.35, 0.55, 0.72, 0.85][level]:
			var low := int(m.level) == 2
			_queue([away | (L.IN_DOWN if low else 0)], 10)
			return _plan.pop_front()
	if my_state == L.S_BLOCKSTUN:
		return away
	# Anti-air a jump-in with the launcher.
	if s[o + L.F_Y] > 3000 and dist < 17000 and rng.randf() < [0.0, 0.15, 0.35, 0.6, 0.8][level]:
		_queue([L.IN_DOWN | L.IN_HP], 1)
		_queue([L.IN_DOWN], 4)
		return _plan.pop_front()
	if _cooldown > 0:
		_cooldown -= 1
		return toward if dist > 11500 else 0
	if dist > 14500:
		var roll := rng.randf()
		if roll < 0.06 * level:
			_queue([toward, 0, toward], 1)
		elif roll < 0.06 * level + 0.03:
			_queue([L.IN_UP | toward], 2)
			_queue([0], 20)
			_queue([L.IN_HK], 1)
		else:
			return toward
		return _plan.pop_front()
	# In range: pick a route. Higher levels use longer and launcher routes.
	var routes := [
		[[L.IN_LP, 1], [0, 6], [L.IN_HP, 1], [0, 11], [L.IN_HK, 1]],
		[[L.IN_DOWN | L.IN_LK, 1], [L.IN_DOWN, 7], [L.IN_HP, 1]],
		[[L.IN_LK, 1], [0, 7], [L.IN_HK, 1]],
		[[L.IN_DOWN | L.IN_HP, 1], [L.IN_DOWN, 12], [L.IN_UP | toward, 3], [0, 3], [L.IN_LP, 1], [0, 5], [L.IN_HP, 1], [0, 7], [L.IN_HK, 1]],
		[[L.IN_DOWN | L.IN_HK, 1]],
	]
	var choices := 2 + level
	var route: Array = routes[rng.randi_range(0, mini(choices, routes.size()) - 1)]
	if rng.randf() < 0.25:
		route = [[L.IN_LP, 1]]
	for step in route:
		_queue([int(step[0])], int(step[1]))
	_cooldown = [0, 40, 26, 16, 10][level] + rng.randi_range(0, 12)
	return _plan.pop_front()


func _queue(inputs: Array, frames: int) -> void:
	for f in range(frames):
		for value in inputs:
			_plan.append(int(value))
