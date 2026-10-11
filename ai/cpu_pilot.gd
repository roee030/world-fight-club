extends RefCounted

## CPU opponent for the new engine. It reads the sim snapshot and returns an
## input bitmask, exactly like a human controller; replays record its inputs,
## so the CPU never needs to be deterministic or part of the sim.
## Level 1..4 scales reaction, block, anti-air and parry rates and combo use.
## It uses Easy-mode inputs (SP + direction) for specials and supers.

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
	if my_state == L.S_THROWN:
		_plan.clear()
		return (L.IN_LP | L.IN_LK) if rng.randf() < 0.08 * level else 0
	if not _plan.is_empty():
		return _plan.pop_front()
	var opp_state := s[o + L.F_STATE]
	var style: String = moveset.archetypes[s[b + L.F_ARCHETYPE]] if "archetypes" in moveset else "universal"
	var has_super := s[b + L.F_SUPER] >= 10000
	var drive_ok := s[b + L.F_BURNOUT] == 0 and s[b + L.F_DRIVE] > 15000
	# Incoming projectile: parry it, jump it or block it.
	for slot in range(L.PROJECTILES):
		var p := L.projectile_base(s, slot)
		if s[p + L.P_ACTIVE] != 0 and s[p + L.P_OWNER] != me and absi(s[p + L.P_X] - s[b + L.F_X]) < 16000:
			var roll := rng.randf()
			if roll < 0.12 * level and drive_ok:
				_queue([L.IN_DRIVE], 8)
			elif roll < 0.2 * level:
				_queue([L.IN_UP | toward], 2)
				_queue([0], 22)
				_queue([L.IN_HK], 1)
			else:
				_queue([away], 14)
			return _plan.pop_front()
	# Defend: block or parry an incoming attack (low attacks need a crouch block).
	if opp_state == L.S_ATTACK and dist < 22000 and s[o + L.F_MOVE] >= 0:
		var m: Dictionary = moveset.moves[s[o + L.F_MOVE]]
		if rng.randf() < [0.0, 0.35, 0.55, 0.72, 0.85][level]:
			if drive_ok and rng.randf() < 0.06 * level:
				_queue([L.IN_DRIVE], 10)
			else:
				_queue([away | (L.IN_DOWN if int(m.level) == 2 else 0)], 10)
			return _plan.pop_front()
	if my_state == L.S_BLOCKSTUN:
		return away
	# Anti-air a jump-in: invincible Rising Fist at higher levels, launcher otherwise.
	if s[o + L.F_Y] > 3000 and dist < 17000 and rng.randf() < [0.0, 0.15, 0.35, 0.6, 0.8][level]:
		if level >= 3 and rng.randf() < 0.5:
			_queue([L.IN_SP | L.IN_DOWN], 1)
		else:
			_queue([L.IN_DOWN | L.IN_HP], 1)
			_queue([L.IN_DOWN], 4)
		return _plan.pop_front()
	# Archetype tactics.
	if style == "grappler" and dist < 12500 and opp_state in [L.S_BLOCKSTUN, L.S_IDLE, L.S_CROUCH, L.S_WALK_B] and rng.randf() < 0.05 * level:
		_queue([L.IN_SP | toward], 1)   # Iron Hug: beats a turtling rival
		_cooldown = 30
		return _plan.pop_front()
	if style == "rushdown" and dist > 12000 and dist < 20000 and rng.randf() < 0.015 * level:
		_queue([L.IN_UP | toward], 2)     # jump in, then Dive Kick
		_queue([0], 9)
		_queue([L.IN_SP | toward], 1)
		_cooldown = 30
		return _plan.pop_front()
	if style == "rushdown" and dist > 13000 and dist < 22000 and rng.randf() < 0.035 * level:
		_queue([L.IN_SP], 1)            # Lightning Dash closes the gap
		_cooldown = 24
		return _plan.pop_front()
	if _cooldown > 0:
		_cooldown -= 1
		return toward if dist > 11500 else 0
	if style == "zoner" and dist > 14000 and s[b + L.F_PROJECTILE_OUT] == 0 and rng.randf() < 0.055 * level:
		_queue([L.IN_SP | (toward if rng.randf() < 0.35 else 0)], 1)   # Rapid Wave or Slow Orb
		_cooldown = 18
		return _plan.pop_front()
	if style == "zoner" and dist < 9000 and rng.randf() < 0.04 * level:
		_queue([away], 1)
		_queue([0], 1)
		_queue([away], 1)                  # back-dash to reset the distance
		return _plan.pop_front()
	if style == "universal" and dist > 20000 and s[b + L.F_PROJECTILE_OUT] == 0 and rng.randf() < 0.05 * level:
		_queue([L.IN_SP], 1)
		_cooldown = 30
		return _plan.pop_front()
	if dist > 14500:
		var roll2 := rng.randf()
		if roll2 < 0.05 * level:
			_queue([toward, 0, toward], 1)
		elif roll2 < 0.05 * level + 0.03 and drive_ok:
			_queue([toward | L.IN_DRIVE], 1)
			_queue([toward], 7)
			_queue([L.IN_LP], 1)
			_queue([0], 6)
			_queue([L.IN_HP], 1)
		elif roll2 < 0.05 * level + 0.06:
			_queue([L.IN_UP | toward], 2)
			_queue([0], 20)
			_queue([L.IN_HK], 1)
		else:
			return toward
		return _plan.pop_front()
	# In range: pick a route. Higher levels use longer, special and super routes.
	var routes := [
		[[L.IN_LP, 1], [0, 6], [L.IN_HP, 1], [0, 11], [L.IN_HK, 1]],
		[[L.IN_DOWN | L.IN_LK, 1], [L.IN_DOWN, 7], [L.IN_HP, 1]],
		[[L.IN_LK, 1], [0, 7], [L.IN_HK, 1]],
		[[L.IN_LP, 1], [0, 6], [L.IN_HP, 1], [0, 9], [L.IN_SP | toward, 1]],
		[[L.IN_DOWN | L.IN_HP, 1], [L.IN_DOWN, 12], [L.IN_UP | toward, 3], [0, 3], [L.IN_LP, 1], [0, 5], [L.IN_HP, 1], [0, 7], [L.IN_HK, 1]],
		[[L.IN_DOWN | L.IN_HK, 1]],
		[[L.IN_LP | L.IN_LK, 1]],
	]
	var route: Array = routes[rng.randi_range(0, mini(2 + level, routes.size()) - 1)]
	if has_super and rng.randf() < 0.2 * level:
		route = [[L.IN_DOWN | L.IN_LP, 1], [L.IN_DOWN, 6], [L.IN_SP | L.IN_HK, 1]]
	elif rng.randf() < 0.12:
		route = [[L.IN_LP | L.IN_LK, 1]] if dist < 10500 else [[L.IN_LP, 1]]
	for step in route:
		_queue([int(step[0])], int(step[1]))
	_cooldown = [0, 40, 26, 16, 10][level] + rng.randi_range(0, 12)
	return _plan.pop_front()


func _queue(inputs: Array, frames: int) -> void:
	for f in range(frames):
		for value in inputs:
			_plan.append(int(value))
