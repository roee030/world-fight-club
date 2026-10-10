extends RefCounted

## Deterministic fighting-game simulation. One call = one 60 Hz frame:
##     var events := Sim.step(moveset, state, inputs)
## `state` is a PackedInt32Array (layout in sim/layout.gd) that the call
## advances in place; `inputs` holds one input bitmask per fighter. No floats,
## no engine physics, no wall clock: identical inputs give identical states,
## which is what replays and rollback netcode rely on (state_hash()).
## Spec: docs/superpowers/specs/2026-10-11-3d-fighter-architecture.md

const L = preload("res://sim/layout.gd")


## fighters: [{"x": int, "hp": int, "walk": int, "team": int}], two or more.
## Fighters face the nearest fighter of the other team.
static func new_match(moveset, fighters: Array, rng_seed: int = 1) -> PackedInt32Array:
	var s := PackedInt32Array()
	s.resize(L.HEADER + L.FIGHTER * fighters.size())
	s[L.H_FRAME] = 0
	s[L.H_RNG] = rng_seed if rng_seed != 0 else 1
	s[L.H_TIMER] = int(moveset.rules.round_frames)
	s[L.H_FIGHTERS] = fighters.size()
	s[L.H_WINNER] = -1
	s[L.H_DATA_VERSION] = int(moveset.rules.data_version)
	for i in range(fighters.size()):
		var b := L.base(i)
		var def: Dictionary = fighters[i]
		s[b + L.F_X] = int(def.get("x", 0))
		s[b + L.F_HP] = int(def.get("hp", 10000))
		s[b + L.F_HP_MAX] = int(def.get("hp", 10000))
		s[b + L.F_WALK] = int(def.get("walk", 541))
		s[b + L.F_TEAM] = int(def.get("team", i % 2))
		s[b + L.F_MOVE] = -1
		s[b + L.F_BUFFER_MOVE] = -1
		s[b + L.F_DRIVE] = int(moveset.rules.drive_max)
		s[b + L.F_STATE] = L.S_IDLE
		s[b + L.F_STATE_FRAME] = 1
	for i in range(fighters.size()):
		var b := L.base(i)
		var target := _nearest_enemy(s, i)
		s[b + L.F_TARGET] = target
		s[b + L.F_FACING] = 1 if s[L.base(target) + L.F_X] >= s[b + L.F_X] else -1
	return s


static func state_hash(s: PackedInt32Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(s.to_byte_array())
	return ctx.finish().hex_encode()


static func step(moveset, s: PackedInt32Array, inputs: PackedInt32Array) -> PackedInt32Array:
	var events := PackedInt32Array()
	var r: Dictionary = moveset.rules
	var count := s[L.H_FIGHTERS]
	s[L.H_FRAME] += 1
	if s[L.H_WINNER] < 0 and s[L.H_TIMER] > 0:
		s[L.H_TIMER] -= 1
	for i in range(count):
		_step_fighter(moveset, r, s, i, inputs[i] if i < inputs.size() else 0, events)
	_resolve_push(r, s, count)
	_resolve_hits(moveset, r, s, count, events)
	if s[L.H_WINNER] < 0 and s[L.H_TIMER] <= 0:
		_decide_by_time(s, count)
	return events


# --- per-fighter update ------------------------------------------------------

static func _step_fighter(moveset, r: Dictionary, s: PackedInt32Array, i: int, inp: int, events: PackedInt32Array) -> void:
	var b := L.base(i)
	var frame := s[L.H_FRAME]
	var prev := s[b + L.F_PREV_INPUT]
	var pressed := inp & ~prev
	s[b + L.F_PREV_INPUT] = inp
	if s[L.H_WINNER] >= 0 and s[b + L.F_STATE] != L.S_KO:
		inp = 0
		pressed = 0
	var facing := s[b + L.F_FACING]
	# Buffer the strongest newly pressed attack button.
	for k in range(L.BUTTONS.size() - 1, -1, -1):
		if pressed & L.BUTTONS[k]:
			s[b + L.F_BUFFER_MOVE] = k
			s[b + L.F_BUFFER_FRAMES] = int(r.buffer_frames)
			break
	# Double-tap detection for dash / back-dash (facing-relative).
	var dash_request := 0
	var h_now := _h(inp, facing)
	var h_before := _h(prev, facing)
	if h_now != 0 and h_now != h_before and _v(inp) == 0:
		var tap_dir := 6 if h_now > 0 else 4
		if s[b + L.F_LAST_TAP_DIR] == tap_dir and frame - s[b + L.F_LAST_TAP_FRAME] <= int(r.dash.double_tap):
			dash_request = h_now
			s[b + L.F_LAST_TAP_DIR] = 0
		else:
			s[b + L.F_LAST_TAP_DIR] = tap_dir
			s[b + L.F_LAST_TAP_FRAME] = frame
	# Hit-stop freezes the fighter completely, buffer included.
	if s[b + L.F_HITSTOP] > 0:
		s[b + L.F_HITSTOP] -= 1
		return
	if s[b + L.F_BUFFER_FRAMES] > 0:
		s[b + L.F_BUFFER_FRAMES] -= 1
		if s[b + L.F_BUFFER_FRAMES] == 0:
			s[b + L.F_BUFFER_MOVE] = -1
	s[b + L.F_STATE_FRAME] += 1
	var state := s[b + L.F_STATE]
	var sf := s[b + L.F_STATE_FRAME]
	match state:
		L.S_IDLE, L.S_WALK_F, L.S_WALK_B, L.S_CROUCH:
			_face_target(s, i)
			facing = s[b + L.F_FACING]
			var h := _h(inp, facing)
			var v := _v(inp)
			if dash_request != 0:
				_enter(s, b, L.S_DASH if dash_request > 0 else L.S_BACKDASH)
				_emit(events, L.EV_DASH, i, dash_request, 0)
			elif s[b + L.F_BUFFER_MOVE] >= 0 and _start_attack(moveset, s, b, 1 if v < 0 else 0, events, i):
				pass
			elif v > 0:
				_enter(s, b, L.S_PREJUMP)
				s[b + L.F_FLAGS] = h + 1
			elif v < 0:
				_set_state(s, b, L.S_CROUCH)
				s[b + L.F_VX] = 0
			elif h > 0:
				_set_state(s, b, L.S_WALK_F)
				s[b + L.F_VX] = facing * s[b + L.F_WALK]
			elif h < 0:
				_set_state(s, b, L.S_WALK_B)
				s[b + L.F_VX] = -facing * s[b + L.F_WALK] * int(r.walk_back_percent) / 100
			else:
				_set_state(s, b, L.S_IDLE)
				s[b + L.F_VX] = 0
		L.S_PREJUMP:
			s[b + L.F_VX] = 0
			if sf > int(r.jump.prejump):
				_launch_jump(r, s, b, s[b + L.F_FLAGS] - 1, int(r.jump.vy))
		L.S_AIR:
			_gravity(r, s, b)
			if s[b + L.F_BUFFER_MOVE] >= 0:
				_start_attack(moveset, s, b, 2, events, i)
		L.S_ATTACK:
			var m: Dictionary = moveset.moves[s[b + L.F_MOVE]]
			var airborne := int(m.posture) == 2
			if airborne:
				_gravity(r, s, b)
			else:
				s[b + L.F_VX] = 0
			var chained := false
			if s[b + L.F_BUFFER_MOVE] >= 0 or _v(inp) > 0:
				chained = _try_cancel(moveset, r, s, b, m, sf, inp, events, i)
			if not chained and sf > int(m.total):
				if airborne:
					_set_state(s, b, L.S_AIR)
					s[b + L.F_MOVE] = -1
				else:
					_enter(s, b, L.S_CROUCH if _v(inp) < 0 else L.S_IDLE)
					s[b + L.F_MOVE] = -1
		L.S_LAND:
			s[b + L.F_VX] = 0
			if sf > int(r.jump.land):
				_enter(s, b, L.S_IDLE)
		L.S_DASH, L.S_BACKDASH:
			var dash: Dictionary = r.dash if state == L.S_DASH else r.backdash
			var dir := facing if state == L.S_DASH else -facing
			s[b + L.F_VX] = dir * int(dash.vx) if sf <= int(dash.move_frames) else 0
			if sf > int(dash.frames):
				_enter(s, b, L.S_IDLE)
		L.S_BLOCKSTUN, L.S_HITSTUN:
			s[b + L.F_VX] = 0
			s[b + L.F_STUN] -= 1
			if s[b + L.F_STUN] <= 0:
				_recover(s, i)
				_enter(s, b, L.S_CROUCH if _v(inp) < 0 else L.S_IDLE)
		L.S_LAUNCHED:
			var g := int(r.launch_gravity) * (100 + s[b + L.F_JUGGLE] * int(r.juggle_gravity_bonus_percent)) / 100
			s[b + L.F_VY] -= g
		L.S_KNOCKDOWN:
			s[b + L.F_VX] = 0
			s[b + L.F_STUN] -= 1
			if s[b + L.F_STUN] <= 0:
				_enter(s, b, L.S_GETUP)
				s[b + L.F_STUN] = int(r.getup_frames)
		L.S_GETUP:
			s[b + L.F_STUN] -= 1
			if s[b + L.F_STUN] <= 0:
				_recover(s, i)
				_enter(s, b, L.S_IDLE)
		L.S_KO:
			if s[b + L.F_Y] > 0:
				s[b + L.F_VY] -= int(r.launch_gravity)
			else:
				s[b + L.F_VX] = s[b + L.F_VX] * 3 / 4
	# Integrate motion.
	s[b + L.F_X] += s[b + L.F_VX] + s[b + L.F_PUSH_VX]
	s[b + L.F_Y] += s[b + L.F_VY]
	var decay := int(r.push_decay)
	if s[b + L.F_PUSH_VX] > 0: s[b + L.F_PUSH_VX] = maxi(0, s[b + L.F_PUSH_VX] - decay)
	elif s[b + L.F_PUSH_VX] < 0: s[b + L.F_PUSH_VX] = mini(0, s[b + L.F_PUSH_VX] + decay)
	if s[b + L.F_Y] <= 0:
		var was_air := s[b + L.F_Y] < 0 or s[b + L.F_VY] < 0
		s[b + L.F_Y] = 0
		if was_air:
			_land(r, s, b, i, events)
	var half := int(r.arena_half_width)
	if s[b + L.F_X] > half: s[b + L.F_X] = half
	elif s[b + L.F_X] < -half: s[b + L.F_X] = -half


static func _land(r: Dictionary, s: PackedInt32Array, b: int, i: int, events: PackedInt32Array) -> void:
	var state := s[b + L.F_STATE]
	var air_attack := state == L.S_ATTACK and _is_air_state(s, b)
	s[b + L.F_VY] = 0
	s[b + L.F_FLAGS] = s[b + L.F_FLAGS] & ~256
	if state == L.S_AIR or air_attack:
		s[b + L.F_MOVE] = -1
		_enter(s, b, L.S_LAND)
		s[b + L.F_VX] = 0
		_emit(events, L.EV_LAND, i, 0, 0)
	elif state == L.S_LAUNCHED:
		_enter(s, b, L.S_KNOCKDOWN)
		s[b + L.F_STUN] = int(r.knockdown_frames)
		s[b + L.F_VX] = 0
		_emit(events, L.EV_LAND, i, 1, 0)
	elif state == L.S_KO:
		s[b + L.F_VX] = s[b + L.F_VX] / 2


static func _is_air_state(s: PackedInt32Array, b: int) -> bool:
	return (s[b + L.F_FLAGS] & 256) != 0


static func _launch_jump(r: Dictionary, s: PackedInt32Array, b: int, h: int, vy: int) -> void:
	_enter(s, b, L.S_AIR)
	s[b + L.F_VY] = vy
	var facing := s[b + L.F_FACING]
	if h > 0: s[b + L.F_VX] = facing * int(r.jump.vx_forward)
	elif h < 0: s[b + L.F_VX] = -facing * int(r.jump.vx_back)
	else: s[b + L.F_VX] = 0
	s[b + L.F_Y] = maxi(s[b + L.F_Y], 1)


static func _gravity(r: Dictionary, s: PackedInt32Array, b: int) -> void:
	s[b + L.F_VY] -= int(r.jump.gravity_rise) if s[b + L.F_VY] > 0 else int(r.jump.gravity_fall)


static func _start_attack(moveset, s: PackedInt32Array, b: int, posture: int, events: PackedInt32Array, i: int) -> bool:
	var button: String = L.BUTTON_NAMES[s[b + L.F_BUFFER_MOVE]]
	var move: int = moveset.move_for(posture, button)
	if move < 0 and posture == 1:
		move = moveset.move_for(0, button)
	if move < 0:
		return false
	_begin_move(s, b, move, posture == 2)
	_emit(events, L.EV_ATTACK, i, move, 0)
	return true


static func _begin_move(s: PackedInt32Array, b: int, move: int, airborne: bool) -> void:
	_enter(s, b, L.S_ATTACK)
	s[b + L.F_MOVE] = move
	s[b + L.F_MOVE_CONNECT] = 0
	s[b + L.F_BUFFER_MOVE] = -1
	s[b + L.F_BUFFER_FRAMES] = 0
	if airborne: s[b + L.F_FLAGS] = s[b + L.F_FLAGS] | 256
	else: s[b + L.F_FLAGS] = s[b + L.F_FLAGS] & ~256


static func _try_cancel(moveset, r: Dictionary, s: PackedInt32Array, b: int, m: Dictionary, sf: int, inp: int, events: PackedInt32Array, i: int) -> bool:
	var connect := s[b + L.F_MOVE_CONNECT]
	if connect == 0 or sf < int(m.cancel_from) or sf > int(m.cancel_to):
		return false
	if bool(m.cancel_hit_only) and connect != 1:
		return false
	var into: Array = m.cancel_into
	if _v(inp) > 0 and -2 in into:
		_launch_jump(r, s, b, _h(inp, s[b + L.F_FACING]), int(r.jump.vy) * 108 / 100)
		s[b + L.F_MOVE] = -1
		s[b + L.F_FLAGS] = s[b + L.F_FLAGS] & ~256
		return true
	if s[b + L.F_BUFFER_MOVE] < 0:
		return false
	var posture := int(m.posture)
	if posture != 2:
		posture = 1 if _v(inp) < 0 else 0
	var button: String = L.BUTTON_NAMES[s[b + L.F_BUFFER_MOVE]]
	var candidate: int = moveset.move_for(posture, button)
	if candidate < 0 or not candidate in into:
		# Crouch-held chains may also continue into a standing target.
		candidate = moveset.move_for(0, button) if posture == 1 else -1
		if candidate < 0 or not candidate in into:
			return false
	_begin_move(s, b, candidate, posture == 2)
	_emit(events, L.EV_ATTACK, i, candidate, 1)
	return true


static func _recover(s: PackedInt32Array, i: int) -> void:
	# The defender acts again: the combo against it is over.
	var b := L.base(i)
	s[b + L.F_HITS_TAKEN] = 0
	s[b + L.F_JUGGLE] = 0
	s[b + L.F_COUNTER] = 0
	var count := s[L.H_FIGHTERS]
	for j in range(count):
		var bj := L.base(j)
		if s[bj + L.F_TARGET] == i:
			s[bj + L.F_COMBO] = 0
			s[bj + L.F_COMBO_DAMAGE] = 0


static func _enter(s: PackedInt32Array, b: int, state: int) -> void:
	s[b + L.F_STATE] = state
	s[b + L.F_STATE_FRAME] = 1


static func _set_state(s: PackedInt32Array, b: int, state: int) -> void:
	# Like _enter, but keeps the frame counter when the state does not change
	# (so walk cycles keep their phase).
	if s[b + L.F_STATE] != state:
		_enter(s, b, state)


static func _face_target(s: PackedInt32Array, i: int) -> void:
	var b := L.base(i)
	var t := L.base(s[b + L.F_TARGET])
	var dx := s[t + L.F_X] - s[b + L.F_X]
	if dx > 0: s[b + L.F_FACING] = 1
	elif dx < 0: s[b + L.F_FACING] = -1


static func _h(inp: int, facing: int) -> int:
	var right := 1 if inp & L.IN_RIGHT else 0
	var left := 1 if inp & L.IN_LEFT else 0
	var h := right - left      # SOCD: left+right = neutral
	return h * facing


static func _v(inp: int) -> int:
	var up := 1 if inp & L.IN_UP else 0
	var down := 1 if inp & L.IN_DOWN else 0
	return up - down


# --- pair resolution -----------------------------------------------------------

static func _resolve_push(r: Dictionary, s: PackedInt32Array, count: int) -> void:
	var half := int(r.push_half_width)
	var arena := int(r.arena_half_width)
	for i in range(count):
		for j in range(i + 1, count):
			var bi := L.base(i)
			var bj := L.base(j)
			# Bodies only collide near the floor, so a jump can cross over.
			if s[bi + L.F_Y] > 8000 or s[bj + L.F_Y] > 8000:
				continue
			if s[bi + L.F_STATE] in [L.S_KNOCKDOWN, L.S_KO] or s[bj + L.F_STATE] in [L.S_KNOCKDOWN, L.S_KO]:
				continue
			var dx := s[bj + L.F_X] - s[bi + L.F_X]
			var overlap := half * 2 - absi(dx)
			if overlap <= 0:
				continue
			var side := 1 if dx > 0 else (-1 if dx < 0 else s[bi + L.F_FACING])
			var push_i := overlap / 2
			var push_j := overlap - push_i
			s[bi + L.F_X] -= side * push_i
			s[bj + L.F_X] += side * push_j
			# A fighter pinned at the edge does not move; the other one yields.
			if absi(s[bi + L.F_X]) > arena:
				var excess := absi(s[bi + L.F_X]) - arena
				s[bi + L.F_X] = signi(s[bi + L.F_X]) * arena
				s[bj + L.F_X] += side * excess
			if absi(s[bj + L.F_X]) > arena:
				var excess2 := absi(s[bj + L.F_X]) - arena
				s[bj + L.F_X] = signi(s[bj + L.F_X]) * arena
				s[bi + L.F_X] -= side * excess2


static func _resolve_hits(moveset, r: Dictionary, s: PackedInt32Array, count: int, events: PackedInt32Array) -> void:
	# Collect every contact from the same pre-hit state first, then apply them,
	# so two simultaneous active hitboxes trade instead of depending on order.
	var contacts: Array[int] = []
	for a in range(count):
		var ba := L.base(a)
		if s[ba + L.F_STATE] != L.S_ATTACK or s[ba + L.F_MOVE_CONNECT] != 0 or s[ba + L.F_HITSTOP] > 0:
			continue
		var m: Dictionary = moveset.moves[s[ba + L.F_MOVE]]
		var sf := s[ba + L.F_STATE_FRAME]
		# Frame data convention: "startup" is the first active frame.
		if sf < int(m.startup) or sf >= int(m.startup) + int(m.active):
			continue
		var hb: PackedInt32Array = m.hitbox
		var facing := s[ba + L.F_FACING]
		var hx0 := s[ba + L.F_X] + (hb[0] if facing > 0 else -hb[0] - hb[2])
		var hy0 := s[ba + L.F_Y] + hb[1]
		for d in range(count):
			if d == a or s[L.base(d) + L.F_TEAM] == s[ba + L.F_TEAM]:
				continue
			var bd := L.base(d)
			var dstate := s[bd + L.F_STATE]
			if dstate in [L.S_KNOCKDOWN, L.S_GETUP, L.S_KO]:
				continue
			var hurt := _hurtbox(moveset, r, s, bd)
			if hx0 < hurt[2] and hx0 + hb[2] > hurt[0] and hy0 < hurt[3] and hy0 + hb[3] > hurt[1]:
				contacts.append(a)
				contacts.append(d)
				break
	for k in range(0, contacts.size(), 2):
		_apply_hit(moveset, r, s, contacts[k], contacts[k + 1], events)


static func _hurtbox(moveset, r: Dictionary, s: PackedInt32Array, bd: int) -> PackedInt32Array:
	# Returns [x0, y0, x1, y1] in world units.
	var state := s[bd + L.F_STATE]
	var x := s[bd + L.F_X]
	var y := s[bd + L.F_Y]
	var box: Array = r.stand.hurt
	var height := int(box[3])
	var bottom := y + int(box[1])
	if state == L.S_CROUCH or (state == L.S_ATTACK and int(moveset.moves[s[bd + L.F_MOVE]].posture) == 1) or (state == L.S_BLOCKSTUN and (s[bd + L.F_FLAGS] & 512) != 0):
		height = int(r.crouch.hurt_height)
	elif y > 0 or state in [L.S_AIR, L.S_LAUNCHED]:
		box = r.air_hurt
		height = int(box[3])
		bottom = y + int(box[1])
	return PackedInt32Array([x + int(box[0]), bottom, x + int(box[0]) + int(box[2]), bottom + height])


static func _apply_hit(moveset, r: Dictionary, s: PackedInt32Array, a: int, d: int, events: PackedInt32Array) -> void:
	var ba := L.base(a)
	var bd := L.base(d)
	var move := s[ba + L.F_MOVE]
	if move < 0:
		return
	var m: Dictionary = moveset.moves[move]
	var facing := s[ba + L.F_FACING]
	var dstate := s[bd + L.F_STATE]
	var d_input := s[bd + L.F_PREV_INPUT]
	var d_facing := -facing
	var holding_back := _h(d_input, d_facing) < 0
	var crouching := _v(d_input) < 0
	var can_block := dstate in [L.S_IDLE, L.S_WALK_F, L.S_WALK_B, L.S_CROUCH, L.S_BLOCKSTUN] and s[bd + L.F_Y] == 0
	var level := int(m.level)
	var blocked := can_block and holding_back and not (level == 2 and not crouching) and not (level == 3 and crouching)
	var hitstop := int(m.hitstop)
	if blocked:
		var chip := int(m.damage) * int(r.chip_percent) / 100
		s[bd + L.F_HP] = maxi(1, s[bd + L.F_HP] - chip)
		_enter(s, bd, L.S_BLOCKSTUN)
		s[bd + L.F_STUN] = int(m.blockstun)
		s[bd + L.F_FACING] = d_facing
		if crouching: s[bd + L.F_FLAGS] = s[bd + L.F_FLAGS] | 512
		else: s[bd + L.F_FLAGS] = s[bd + L.F_FLAGS] & ~512
		s[ba + L.F_MOVE_CONNECT] = 2
		_push(r, s, ba, bd, facing, int(m.pushback))
		s[ba + L.F_HITSTOP] = maxi(s[ba + L.F_HITSTOP], hitstop - 2)
		s[bd + L.F_HITSTOP] = maxi(s[bd + L.F_HITSTOP], hitstop - 2)
		_emit(events, L.EV_BLOCK, a, move, chip)
		return
	var counter := dstate == L.S_ATTACK and s[bd + L.F_MOVE] >= 0 and s[bd + L.F_STATE_FRAME] < int(moveset.moves[s[bd + L.F_MOVE]].startup)
	var scaling: Array = r.scaling
	var taken := s[bd + L.F_HITS_TAKEN]
	var scale := maxi(int(r.scaling_min), int(scaling[mini(taken, scaling.size() - 1)]))
	var damage := int(m.damage) * scale / 100
	if counter:
		damage = damage * int(r.counter_hit.damage_percent) / 100
		hitstop += int(r.counter_hit.hitstop_bonus)
	damage = maxi(1, damage)
	s[bd + L.F_HP] = maxi(0, s[bd + L.F_HP] - damage)
	s[bd + L.F_HITS_TAKEN] = taken + 1
	s[bd + L.F_COUNTER] = 1 if counter else 0
	s[ba + L.F_COMBO] = taken + 1
	s[ba + L.F_COMBO_DAMAGE] = (s[ba + L.F_COMBO_DAMAGE] if taken > 0 else 0) + damage
	s[ba + L.F_MOVE_CONNECT] = 1
	s[bd + L.F_MOVE] = -1
	s[bd + L.F_FACING] = d_facing
	s[bd + L.F_FLAGS] = s[bd + L.F_FLAGS] & ~256
	var airborne := s[bd + L.F_Y] > 0 or dstate in [L.S_AIR, L.S_LAUNCHED]
	if airborne or int(m.launch_vy) != 0:
		var vx := int(m.air_launch_vx) if airborne else int(m.launch_vx)
		var vy := int(m.air_launch_vy) if airborne else int(m.launch_vy)
		if s[bd + L.F_JUGGLE] >= int(r.juggle_budget):
			vy = mini(vy, -200)
		s[bd + L.F_JUGGLE] += 1
		_enter(s, bd, L.S_LAUNCHED)
		s[bd + L.F_VX] = facing * vx
		s[bd + L.F_VY] = vy
		s[bd + L.F_PUSH_VX] = 0
		s[bd + L.F_Y] = maxi(s[bd + L.F_Y], 1)
		_emit(events, L.EV_LAUNCH, d, move, 0)
	else:
		_enter(s, bd, L.S_HITSTUN)
		s[bd + L.F_STUN] = int(m.hitstun) + (int(r.counter_hit.hitstun_bonus) if counter else 0)
		_push(r, s, ba, bd, facing, int(m.pushback))
	s[ba + L.F_HITSTOP] = maxi(s[ba + L.F_HITSTOP], hitstop)
	s[bd + L.F_HITSTOP] = maxi(s[bd + L.F_HITSTOP], hitstop)
	_emit(events, L.EV_HIT, a, move, damage)
	if counter:
		_emit(events, L.EV_COUNTER, a, move, 0)
	if s[bd + L.F_HP] <= 0:
		_enter(s, bd, L.S_KO)
		s[bd + L.F_VX] = facing * 300
		s[bd + L.F_VY] = maxi(s[bd + L.F_VY], 700)
		s[bd + L.F_Y] = maxi(s[bd + L.F_Y], 1)
		s[L.H_WINNER] = s[ba + L.F_TEAM]
		_emit(events, L.EV_KO, d, a, 0)


static func _push(r: Dictionary, s: PackedInt32Array, ba: int, bd: int, facing: int, amount: int) -> void:
	# Push the defender away; if it is pinned at the wall, the attacker recoils.
	var arena := int(r.arena_half_width)
	if absi(s[bd + L.F_X]) >= arena - 200 and signi(s[bd + L.F_X]) == facing:
		s[ba + L.F_PUSH_VX] = -facing * amount
		s[bd + L.F_PUSH_VX] = 0
	else:
		s[bd + L.F_PUSH_VX] = facing * amount


static func _decide_by_time(s: PackedInt32Array, count: int) -> void:
	var best := -1
	var best_ratio := -1
	var draw := false
	for i in range(count):
		var b := L.base(i)
		var ratio := s[b + L.F_HP] * 1000 / maxi(1, s[b + L.F_HP_MAX])
		if ratio > best_ratio:
			best_ratio = ratio
			best = s[b + L.F_TEAM]
			draw = false
		elif ratio == best_ratio and s[b + L.F_TEAM] != best:
			draw = true
	s[L.H_WINNER] = 99 if draw else best


static func _nearest_enemy(s: PackedInt32Array, i: int) -> int:
	var b := L.base(i)
	var best := i
	var best_dist := 1 << 30
	for j in range(s[L.H_FIGHTERS]):
		if j == i or s[L.base(j) + L.F_TEAM] == s[b + L.F_TEAM]:
			continue
		var dist := absi(s[L.base(j) + L.F_X] - s[b + L.F_X])
		if dist < best_dist:
			best_dist = dist
			best = j
	return best


static func _emit(events: PackedInt32Array, kind: int, fighter: int, a: int, b: int) -> void:
	events.append(kind)
	events.append(fighter)
	events.append(a)
	events.append(b)
