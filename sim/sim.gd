extends RefCounted

## Deterministic fighting-game simulation. One call = one 60 Hz frame:
##     var events := Sim.step(moveset, state, inputs)
## `state` is a PackedInt32Array (layout in sim/layout.gd) that the call
## advances in place; `inputs` holds one input bitmask per fighter. No floats,
## no engine physics, no wall clock: identical inputs give identical states,
## which is what replays and rollback netcode rely on (state_hash()).
## Spec: docs/superpowers/specs/2026-10-11-3d-fighter-architecture.md
##
## Systems: frame data, hit/hurt boxes, hit-stop, hitstun/blockstun, block
## levels, chains, specials from motion inputs (Pro) or the SP button + a
## direction (Easy), projectiles, invincible reversals, armor, Super Art with a
## super-freeze, Drive gauge (parry, rush, impact, burnout), throws and tech,
## launchers and air juggles, wall splat, counter-hit, damage scaling, KO/time.

const L = preload("res://sim/layout.gd")
const T_NORMAL := 0
const T_SPECIAL := 1
const T_SUPER := 2
const T_DRIVE := 3
const T_THROW := 4
const THROWABLE := [L.S_IDLE, L.S_WALK_F, L.S_WALK_B, L.S_CROUCH, L.S_ATTACK, L.S_DASH, L.S_BACKDASH, L.S_LAND, L.S_PARRY, L.S_RUSH]
const NEUTRAL := [L.S_IDLE, L.S_WALK_F, L.S_WALK_B, L.S_CROUCH]


## fighters: [{"x": int, "hp": int, "walk": int, "team": int}], two or more.
## Fighters face the nearest fighter of the other team.
static func new_match(moveset, fighters: Array, rng_seed: int = 1) -> PackedInt32Array:
	var s := PackedInt32Array()
	s.resize(L.HEADER + L.FIGHTER * fighters.size() + L.PROJECTILE * L.PROJECTILES)
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
		s[b + L.F_SPECIAL_BUFFER] = -1
		s[b + L.F_DRIVE] = int(moveset.rules.drive_max)
		s[b + L.F_SUPER] = int(def.get("super", 0))
		if bool(def.get("easy", false)): s[b + L.F_FLAGS] = s[b + L.F_FLAGS] | L.FLAG_EASY
		s[b + L.F_STATE] = L.S_IDLE
		s[b + L.F_STATE_FRAME] = 1
		for k in range(L.HIST_LEN):
			s[b + L.F_HIST + k] = 5
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
	_step_projectiles(moveset, r, s, events)
	_resolve_push(r, s, count)
	_resolve_hits(moveset, r, s, count, events)
	if s[L.H_WINNER] < 0 and s[L.H_TIMER] <= 0:
		_decide_by_time(s, count)
	return events


# --- input -----------------------------------------------------------------------

static func _h(inp: int, facing: int) -> int:
	var right := 1 if inp & L.IN_RIGHT else 0
	var left := 1 if inp & L.IN_LEFT else 0
	return (right - left) * facing      # SOCD: left+right = neutral


static func _v(inp: int) -> int:
	var up := 1 if inp & L.IN_UP else 0
	var down := 1 if inp & L.IN_DOWN else 0
	return up - down


static func _numpad(inp: int, facing: int) -> int:
	return 5 + _h(inp, facing) + 3 * _v(inp)


## True when `seq` (numpad digits) appears in order in the last `window` frames.
static func _motion(s: PackedInt32Array, b: int, seq: String, window: int) -> bool:
	var idx := seq.length() - 1
	var pos := s[b + L.F_HIST_POS]
	for k in range(mini(window, L.HIST_LEN)):
		var dir := s[b + L.F_HIST + (pos - k + L.HIST_LEN) % L.HIST_LEN]
		if dir == seq.unicode_at(idx) - 48:
			idx -= 1
			if idx < 0:
				return true
	return false


static func _read_commands(moveset, r: Dictionary, s: PackedInt32Array, b: int, inp: int, pressed: int) -> void:
	# Throw: both light buttons together.
	if (pressed & (L.IN_LP | L.IN_LK)) != 0 and (inp & L.IN_LP) != 0 and (inp & L.IN_LK) != 0:
		_buffer_special(r, s, b, int(moveset.named.get("THROW", -1)))
		return
	var facing := s[b + L.F_FACING]
	# Drive: DRIVE + HP = Impact (Drive Rush and Parry are read in neutral).
	if ((pressed & L.IN_DRIVE) != 0 and (inp & L.IN_HP) != 0) or ((pressed & L.IN_HP) != 0 and (inp & L.IN_DRIVE) != 0):
		_buffer_special(r, s, b, int(moveset.named.get("IMPACT", -1)))
		return
	# Easy mode: SP + direction picks the special; SP + HK = Super.
	if (pressed & L.IN_SP) != 0:
		var code := "N"
		if (inp & L.IN_HK) != 0: code = "SUPER"
		elif _v(inp) < 0: code = "D"
		elif _h(inp, facing) > 0: code = "F"
		elif _h(inp, facing) < 0: code = "B"
		for move in moveset.specials:
			if str(moveset.moves[move].easy) == code:
				_buffer_special(r, s, b, move)
				s[b + L.F_FLAGS] = s[b + L.F_FLAGS] | L.FLAG_ASSISTED
				return
		return
	# Pro mode: motion + button class.
	var punch := (pressed & (L.IN_LP | L.IN_HP)) != 0
	var kick := (pressed & (L.IN_LK | L.IN_HK)) != 0
	if not punch and not kick:
		return
	var windows: Dictionary = r.command_window
	for move in moveset.specials:
		var m: Dictionary = moveset.moves[move]
		var cls := str(m.button_class)
		if (cls == "P" and not punch) or (cls == "K" and not kick):
			continue
		var command := str(m.command)
		if _motion(s, b, command, int(windows.get(command, 12))):
			if int(m.type) == T_SUPER and s[b + L.F_SUPER] < int(m.super_cost):
				continue
			_buffer_special(r, s, b, move)
			s[b + L.F_FLAGS] = s[b + L.F_FLAGS] & ~L.FLAG_ASSISTED
			return


static func _buffer_special(r: Dictionary, s: PackedInt32Array, b: int, move: int) -> void:
	if move < 0:
		return
	s[b + L.F_SPECIAL_BUFFER] = move
	s[b + L.F_SPECIAL_FRAMES] = int(r.special_buffer)
	s[b + L.F_BUFFER_MOVE] = -1
	s[b + L.F_BUFFER_FRAMES] = 0


# --- per-fighter update ------------------------------------------------------------

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
	# Input history (facing-relative numpad) for motion commands.
	var pos := (s[b + L.F_HIST_POS] + 1) % L.HIST_LEN
	s[b + L.F_HIST_POS] = pos
	s[b + L.F_HIST + pos] = _numpad(inp, facing)
	# Buffer the strongest newly pressed attack button, then look for commands.
	for k in range(L.BUTTONS.size() - 1, -1, -1):
		if pressed & L.BUTTONS[k]:
			s[b + L.F_BUFFER_MOVE] = k
			s[b + L.F_BUFFER_FRAMES] = int(r.buffer_frames)
			break
	if pressed != 0:
		_read_commands(moveset, r, s, b, inp, pressed)
	# Double-tap detection for dash / back-dash.
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
	var rush_request := (pressed & L.IN_DRIVE) != 0 and h_now > 0 and (inp & L.IN_HP) == 0
	# Super freeze and hit-stop freeze the fighter completely, buffers included.
	if s[b + L.F_SUPER_FREEZE] > 0:
		s[b + L.F_SUPER_FREEZE] -= 1
		return
	if s[b + L.F_HITSTOP] > 0:
		s[b + L.F_HITSTOP] -= 1
		return
	if s[b + L.F_BUFFER_FRAMES] > 0:
		s[b + L.F_BUFFER_FRAMES] -= 1
		if s[b + L.F_BUFFER_FRAMES] == 0:
			s[b + L.F_BUFFER_MOVE] = -1
	if s[b + L.F_SPECIAL_FRAMES] > 0:
		s[b + L.F_SPECIAL_FRAMES] -= 1
		if s[b + L.F_SPECIAL_FRAMES] == 0:
			s[b + L.F_SPECIAL_BUFFER] = -1
	if s[b + L.F_RUSH] > 0:
		s[b + L.F_RUSH] -= 1
	_regen_drive(r, s, b, events, i)
	s[b + L.F_STATE_FRAME] += 1
	var state := s[b + L.F_STATE]
	var sf := s[b + L.F_STATE_FRAME]
	match state:
		L.S_IDLE, L.S_WALK_F, L.S_WALK_B, L.S_CROUCH:
			_face_target(s, i)
			facing = s[b + L.F_FACING]
			var h := _h(inp, facing)
			var v := _v(inp)
			var drive_ok := s[b + L.F_BURNOUT] == 0
			if s[b + L.F_SPECIAL_BUFFER] >= 0 and _start_special(moveset, r, s, b, i, events):
				pass
			elif dash_request != 0:
				_enter(s, b, L.S_DASH if dash_request > 0 else L.S_BACKDASH)
				_emit(events, L.EV_DASH, i, dash_request, 0)
			elif rush_request and drive_ok and s[b + L.F_DRIVE] >= int(r.rush.cost):
				_start_rush(r, s, b, i, int(r.rush.cost), events)
			elif (inp & L.IN_DRIVE) != 0 and h <= 0 and (inp & L.IN_HP) == 0 and drive_ok and s[b + L.F_DRIVE] > 0:
				_enter(s, b, L.S_PARRY)
				s[b + L.F_VX] = 0
			elif s[b + L.F_BUFFER_MOVE] >= 0 and _start_attack(moveset, s, b, 1 if v < 0 else 0, events, i):
				pass
			elif v > 0:
				_enter(s, b, L.S_PREJUMP)
				s[b + L.F_FLAGS] = (s[b + L.F_FLAGS] & ~3) | (h + 1)
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
				_launch_jump(r, s, b, (s[b + L.F_FLAGS] & 3) - 1, int(r.jump.vy))
		L.S_AIR:
			_gravity(r, s, b)
			if s[b + L.F_BUFFER_MOVE] >= 0:
				_start_attack(moveset, s, b, 2, events, i)
		L.S_ATTACK:
			var move := s[b + L.F_MOVE]
			var m: Dictionary = moveset.moves[move]
			var airborne := int(m.posture) == 2
			if airborne:
				_gravity(r, s, b)
			elif sf >= int(m.motion_from) and sf <= int(m.motion_to):
				s[b + L.F_VX] = facing * int(m.motion_vx)
			else:
				s[b + L.F_VX] = 0
			if bool(m.projectile) and sf == int(m.proj_spawn):
				_spawn_projectile(s, i, move, m, events)
			var chained := false
			if s[b + L.F_BUFFER_MOVE] >= 0 or s[b + L.F_SPECIAL_BUFFER] >= 0 or _v(inp) > 0 or rush_request:
				chained = _try_cancel(moveset, r, s, b, m, sf, inp, rush_request, events, i)
			if not chained and sf > int(m.total):
				s[b + L.F_MOVE] = -1
				s[b + L.F_ARMOR] = 0
				if airborne: _set_state(s, b, L.S_AIR)
				else: _enter(s, b, L.S_CROUCH if _v(inp) < 0 else L.S_IDLE)
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
		L.S_RUSH:
			var rush: Dictionary = r.rush
			s[b + L.F_VX] = facing * int(rush.vx) if sf <= int(rush.move_frames) else 0
			if sf >= 6 and s[b + L.F_SPECIAL_BUFFER] >= 0 and _start_special(moveset, r, s, b, i, events):
				pass
			elif sf >= 6 and s[b + L.F_BUFFER_MOVE] >= 0 and _start_attack(moveset, s, b, 1 if _v(inp) < 0 else 0, events, i):
				pass
			elif sf > int(rush.frames):
				_enter(s, b, L.S_IDLE)
		L.S_PARRY:
			s[b + L.F_VX] = 0
			s[b + L.F_DRIVE] = maxi(0, s[b + L.F_DRIVE] - int(r.parry_drain))
			if s[b + L.F_DRIVE] == 0:
				_burnout(s, b, events, i)
				_enter(s, b, L.S_IDLE)
			elif (inp & L.IN_DRIVE) == 0 and sf >= int(r.parry_min):
				_enter(s, b, L.S_IDLE)
		L.S_THROW:
			s[b + L.F_VX] = 0
			var tm: Dictionary = moveset.moves[s[b + L.F_MOVE]]
			if sf == int(tm.startup) and s[b + L.F_MOVE_CONNECT] == 0:
				_try_throw(moveset, r, s, i, tm, events)
			if sf > int(tm.total) and s[b + L.F_MOVE_CONNECT] != 1:
				s[b + L.F_MOVE] = -1
				_enter(s, b, L.S_IDLE)
		L.S_THROWN:
			s[b + L.F_VX] = 0
			s[b + L.F_STUN] -= 1
			var thrower := s[b + L.F_TARGET]
			var tb := L.base(thrower)
			if (pressed & (L.IN_LP | L.IN_LK)) != 0 and (inp & L.IN_LP) != 0 and (inp & L.IN_LK) != 0:
				# Throw tech: both fighters break apart, nobody takes damage.
				_enter(s, b, L.S_IDLE)
				_enter(s, tb, L.S_IDLE)
				s[tb + L.F_MOVE] = -1
				s[tb + L.F_MOVE_CONNECT] = 0
				var away := -s[tb + L.F_FACING]
				s[b + L.F_PUSH_VX] = -away * 600
				s[tb + L.F_PUSH_VX] = away * 600
				_emit(events, L.EV_TECH, i, thrower, 0)
			elif s[b + L.F_STUN] <= 0:
				_finish_throw(moveset, r, s, thrower, i, events)
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


static func _regen_drive(r: Dictionary, s: PackedInt32Array, b: int, events: PackedInt32Array, i: int) -> void:
	if s[b + L.F_STATE] in [L.S_PARRY, L.S_RUSH]:
		return
	var regen := int(r.drive_regen_burnout) if s[b + L.F_BURNOUT] != 0 else int(r.drive_regen)
	s[b + L.F_DRIVE] = mini(int(r.drive_max), s[b + L.F_DRIVE] + regen)
	if s[b + L.F_BURNOUT] != 0 and s[b + L.F_DRIVE] >= int(r.burnout_exit):
		s[b + L.F_BURNOUT] = 0


static func _burnout(s: PackedInt32Array, b: int, events: PackedInt32Array, i: int) -> void:
	if s[b + L.F_BURNOUT] == 0:
		s[b + L.F_BURNOUT] = 1
		s[b + L.F_DRIVE] = 0
		_emit(events, L.EV_BURNOUT, i, 0, 0)


static func _land(r: Dictionary, s: PackedInt32Array, b: int, i: int, events: PackedInt32Array) -> void:
	var state := s[b + L.F_STATE]
	var air_attack := state == L.S_ATTACK and (s[b + L.F_FLAGS] & 256) != 0
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
	s[b + L.F_FLAGS] = s[b + L.F_FLAGS] & ~L.FLAG_ASSISTED
	_begin_move(s, b, move, posture == 2, moveset)
	_emit(events, L.EV_ATTACK, i, move, 0)
	return true


## Starts the buffered special / super / drive move / throw if it is affordable.
static func _start_special(moveset, r: Dictionary, s: PackedInt32Array, b: int, i: int, events: PackedInt32Array) -> bool:
	var move := s[b + L.F_SPECIAL_BUFFER]
	if move < 0:
		return false
	var m: Dictionary = moveset.moves[move]
	var kind := int(m.type)
	if kind == T_SUPER and s[b + L.F_SUPER] < int(m.super_cost):
		return false
	if kind == T_DRIVE and (s[b + L.F_BURNOUT] != 0 or s[b + L.F_DRIVE] < int(m.drive_cost)):
		return false
	s[b + L.F_SPECIAL_BUFFER] = -1
	s[b + L.F_SPECIAL_FRAMES] = 0
	_face_target(s, i)
	if kind == T_SUPER:
		s[b + L.F_SUPER] -= int(m.super_cost)
		var freeze := int(m.super_freeze)
		for j in range(s[L.H_FIGHTERS]):
			if j != i: s[L.base(j) + L.F_SUPER_FREEZE] = maxi(s[L.base(j) + L.F_SUPER_FREEZE], freeze + 1)
		s[b + L.F_SUPER_FREEZE] = freeze
		_emit(events, L.EV_SUPER, i, move, freeze)
	elif kind == T_DRIVE:
		s[b + L.F_DRIVE] -= int(m.drive_cost)
		if s[b + L.F_DRIVE] <= 0: _burnout(s, b, events, i)
	_begin_move(s, b, move, false, moveset)
	if kind == T_THROW:
		_enter(s, b, L.S_THROW)
	_emit(events, L.EV_SPECIAL if kind != T_THROW else L.EV_ATTACK, i, move, 0)
	return true


static func _begin_move(s: PackedInt32Array, b: int, move: int, airborne: bool, moveset) -> void:
	_enter(s, b, L.S_ATTACK)
	s[b + L.F_MOVE] = move
	s[b + L.F_MOVE_CONNECT] = 0
	s[b + L.F_BUFFER_MOVE] = -1
	s[b + L.F_BUFFER_FRAMES] = 0
	s[b + L.F_ARMOR] = int(moveset.moves[move].armor)
	if airborne: s[b + L.F_FLAGS] = s[b + L.F_FLAGS] | 256
	else: s[b + L.F_FLAGS] = s[b + L.F_FLAGS] & ~256


static func _start_rush(r: Dictionary, s: PackedInt32Array, b: int, i: int, cost: int, events: PackedInt32Array) -> void:
	s[b + L.F_DRIVE] -= cost
	s[b + L.F_MOVE] = -1
	_enter(s, b, L.S_RUSH)
	s[b + L.F_RUSH] = int(r.rush.bonus_frames)
	_emit(events, L.EV_RUSH, i, 0, 0)
	if s[b + L.F_DRIVE] <= 0: _burnout(s, b, events, i)


static func _try_cancel(moveset, r: Dictionary, s: PackedInt32Array, b: int, m: Dictionary, sf: int, inp: int, rush_request: bool, events: PackedInt32Array, i: int) -> bool:
	var connect := s[b + L.F_MOVE_CONNECT]
	if connect == 0 or connect == 3 or sf < int(m.cancel_from) or sf > int(m.cancel_to):
		return false
	if bool(m.cancel_hit_only) and connect != 1:
		return false
	var into: Array = m.cancel_into
	# Special / super cancels.
	var special := s[b + L.F_SPECIAL_BUFFER]
	if special >= 0:
		var kind := int(moveset.moves[special].type)
		if (kind == T_SPECIAL and -3 in into) or (kind == T_SUPER and -4 in into):
			return _start_special(moveset, r, s, b, i, events)
	if rush_request and -5 in into and s[b + L.F_BURNOUT] == 0 and s[b + L.F_DRIVE] >= int(r.rush.cancel_cost):
		_start_rush(r, s, b, i, int(r.rush.cancel_cost), events)
		return true
	if _v(inp) > 0 and -2 in into:
		_launch_jump(r, s, b, _h(inp, s[b + L.F_FACING]), int(r.jump.vy) * 108 / 100)
		s[b + L.F_MOVE] = -1
		s[b + L.F_FLAGS] = s[b + L.F_FLAGS] & ~256
		return true
	if s[b + L.F_BUFFER_MOVE] < 0:
		return false
	# Easy auto-combo: LP again continues the route (assisted damage).
	if (s[b + L.F_FLAGS] & L.FLAG_EASY) != 0 and s[b + L.F_BUFFER_MOVE] == 0 and moveset.auto_next.has(s[b + L.F_MOVE]):
		var next: int = moveset.auto_next[s[b + L.F_MOVE]]
		s[b + L.F_FLAGS] = s[b + L.F_FLAGS] | L.FLAG_ASSISTED
		if int(moveset.moves[next].type) != T_NORMAL:
			_buffer_special(r, s, b, next)
			return _start_special(moveset, r, s, b, i, events)
		_begin_move(s, b, next, int(moveset.moves[next].posture) == 2, moveset)
		_emit(events, L.EV_ATTACK, i, next, 1)
		return true
	var posture := int(m.posture)
	if posture != 2:
		posture = 1 if _v(inp) < 0 else 0
	var button: String = L.BUTTON_NAMES[s[b + L.F_BUFFER_MOVE]]
	var candidate: int = moveset.move_for(posture, button)
	if candidate < 0 or not candidate in into:
		candidate = moveset.move_for(0, button) if posture == 1 else -1
		if candidate < 0 or not candidate in into:
			return false
	_begin_move(s, b, candidate, posture == 2, moveset)
	_emit(events, L.EV_ATTACK, i, candidate, 1)
	return true


static func _recover(s: PackedInt32Array, i: int) -> void:
	# The defender acts again: the combo against it is over.
	var b := L.base(i)
	s[b + L.F_HITS_TAKEN] = 0
	s[b + L.F_JUGGLE] = 0
	s[b + L.F_COUNTER] = 0
	s[b + L.F_WALL_USED] = 0
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
	# Like _enter, but keeps the frame counter when the state does not change.
	if s[b + L.F_STATE] != state:
		_enter(s, b, state)


static func _face_target(s: PackedInt32Array, i: int) -> void:
	var b := L.base(i)
	var t := L.base(s[b + L.F_TARGET])
	var dx := s[t + L.F_X] - s[b + L.F_X]
	if dx > 0: s[b + L.F_FACING] = 1
	elif dx < 0: s[b + L.F_FACING] = -1


# --- throws ------------------------------------------------------------------------

static func _try_throw(moveset, r: Dictionary, s: PackedInt32Array, i: int, m: Dictionary, events: PackedInt32Array) -> void:
	var b := L.base(i)
	var t := s[b + L.F_TARGET]
	var tb := L.base(t)
	var dist := absi(s[tb + L.F_X] - s[b + L.F_X])
	if dist > int(m.range) or s[tb + L.F_Y] != 0 or not s[tb + L.F_STATE] in THROWABLE:
		return
	if s[tb + L.F_STATE] == L.S_THROW:
		return
	s[b + L.F_MOVE_CONNECT] = 1
	s[tb + L.F_MOVE] = -1
	_enter(s, tb, L.S_THROWN)
	s[tb + L.F_STUN] = int(r.throw_tech_window)
	s[tb + L.F_TARGET] = i
	s[tb + L.F_FACING] = -s[b + L.F_FACING]
	s[tb + L.F_X] = s[b + L.F_X] + s[b + L.F_FACING] * 7000


static func _finish_throw(moveset, r: Dictionary, s: PackedInt32Array, thrower: int, victim: int, events: PackedInt32Array) -> void:
	var b := L.base(thrower)
	var tb := L.base(victim)
	var move := s[b + L.F_MOVE]
	var m: Dictionary = moveset.moves[move] if move >= 0 else moveset.moves[int(moveset.named.THROW)]
	var damage := int(m.damage)
	s[tb + L.F_HP] = maxi(0, s[tb + L.F_HP] - damage)
	s[tb + L.F_HITS_TAKEN] += 1
	s[b + L.F_COMBO] = s[tb + L.F_HITS_TAKEN]
	s[b + L.F_COMBO_DAMAGE] += damage
	_gain_super(r, s, b, damage * int(r.super_gain_hit_percent) / 100)
	_enter(s, tb, L.S_LAUNCHED)
	s[tb + L.F_VX] = s[b + L.F_FACING] * int(m.launch_vx)
	s[tb + L.F_VY] = int(m.launch_vy)
	s[tb + L.F_Y] = 1
	s[b + L.F_MOVE] = -1
	s[b + L.F_MOVE_CONNECT] = 0
	_enter(s, b, L.S_IDLE)
	s[b + L.F_HITSTOP] = int(m.hitstop)
	_emit(events, L.EV_THROW, thrower, move, damage)
	_check_ko(s, b, tb, victim, thrower, events)


# --- projectiles ---------------------------------------------------------------------

static func _spawn_projectile(s: PackedInt32Array, owner: int, move: int, m: Dictionary, events: PackedInt32Array) -> void:
	var b := L.base(owner)
	if s[b + L.F_PROJECTILE_OUT] != 0:
		return
	for slot in range(L.PROJECTILES):
		var p := L.projectile_base(s, slot)
		if s[p + L.P_ACTIVE] == 0:
			var facing := s[b + L.F_FACING]
			s[p + L.P_ACTIVE] = 1
			s[p + L.P_OWNER] = owner
			s[p + L.P_X] = s[b + L.F_X] + facing * 4000
			s[p + L.P_Y] = s[b + L.F_Y]
			s[p + L.P_VX] = facing * int(m.proj_vx)
			s[p + L.P_LIFE] = int(m.proj_life)
			s[p + L.P_MOVE] = move
			s[b + L.F_PROJECTILE_OUT] = 1
			_emit(events, L.EV_PROJECTILE, owner, slot, 0)
			return


static func _step_projectiles(moveset, r: Dictionary, s: PackedInt32Array, events: PackedInt32Array) -> void:
	var arena := int(r.arena_half_width)
	for slot in range(L.PROJECTILES):
		var p := L.projectile_base(s, slot)
		if s[p + L.P_ACTIVE] == 0:
			continue
		var owner := s[p + L.P_OWNER]
		var ob := L.base(owner)
		if s[ob + L.F_SUPER_FREEZE] > 0:
			continue
		s[p + L.P_X] += s[p + L.P_VX]
		s[p + L.P_LIFE] -= 1
		if s[p + L.P_LIFE] <= 0 or absi(s[p + L.P_X]) > arena + 6000:
			_kill_projectile(s, slot)
			continue
		var m: Dictionary = moveset.moves[s[p + L.P_MOVE]]
		var box: PackedInt32Array = m.proj_box
		var x0 := s[p + L.P_X] - box[2] / 2
		var y0 := s[p + L.P_Y] + box[1]
		# Projectile clash: two opposing projectiles cancel out.
		for other in range(slot + 1, L.PROJECTILES):
			var q := L.projectile_base(s, other)
			if s[q + L.P_ACTIVE] != 0 and s[L.base(s[q + L.P_OWNER]) + L.F_TEAM] != s[ob + L.F_TEAM] and absi(s[q + L.P_X] - s[p + L.P_X]) < box[2]:
				_kill_projectile(s, slot)
				_kill_projectile(s, other)
				break
		if s[p + L.P_ACTIVE] == 0:
			continue
		for d in range(s[L.H_FIGHTERS]):
			var bd := L.base(d)
			if s[bd + L.F_TEAM] == s[ob + L.F_TEAM] or not _hittable(moveset, s, bd):
				continue
			var hurt := _hurtbox(moveset, r, s, bd)
			if x0 < hurt[2] and x0 + box[2] > hurt[0] and y0 < hurt[3] and y0 + box[3] > hurt[1]:
				_apply_hit(moveset, r, s, owner, d, s[p + L.P_MOVE], true, signi(s[p + L.P_VX]), events)
				_kill_projectile(s, slot)
				break


static func _kill_projectile(s: PackedInt32Array, slot: int) -> void:
	var p := L.projectile_base(s, slot)
	if s[p + L.P_ACTIVE] != 0:
		s[L.base(s[p + L.P_OWNER]) + L.F_PROJECTILE_OUT] = 0
	s[p + L.P_ACTIVE] = 0


# --- pair resolution -------------------------------------------------------------------

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
			if s[bi + L.F_STATE] in [L.S_KNOCKDOWN, L.S_KO, L.S_THROWN] or s[bj + L.F_STATE] in [L.S_KNOCKDOWN, L.S_KO, L.S_THROWN]:
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


static func _hittable(moveset, s: PackedInt32Array, bd: int) -> bool:
	var dstate := s[bd + L.F_STATE]
	if dstate in [L.S_KNOCKDOWN, L.S_GETUP, L.S_KO, L.S_THROWN] or s[bd + L.F_SUPER_FREEZE] > 0:
		return false
	if dstate == L.S_ATTACK and s[bd + L.F_MOVE] >= 0:
		var dm: Dictionary = moveset.moves[s[bd + L.F_MOVE]]
		var dsf := s[bd + L.F_STATE_FRAME]
		if dsf >= int(dm.invuln_from) and dsf <= int(dm.invuln_to):
			return false
	return true


static func _resolve_hits(moveset, r: Dictionary, s: PackedInt32Array, count: int, events: PackedInt32Array) -> void:
	# Collect every contact from the same pre-hit state first, then apply them,
	# so two simultaneous active hitboxes trade instead of depending on order.
	var contacts: Array[int] = []
	for a in range(count):
		var ba := L.base(a)
		if s[ba + L.F_STATE] != L.S_ATTACK or s[ba + L.F_MOVE_CONNECT] != 0 or s[ba + L.F_HITSTOP] > 0 or s[ba + L.F_SUPER_FREEZE] > 0:
			continue
		var m: Dictionary = moveset.moves[s[ba + L.F_MOVE]]
		if bool(m.projectile) or int(m.type) == T_THROW:
			continue
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
			if not _hittable(moveset, s, bd):
				continue
			var hurt := _hurtbox(moveset, r, s, bd)
			if hx0 < hurt[2] and hx0 + hb[2] > hurt[0] and hy0 < hurt[3] and hy0 + hb[3] > hurt[1]:
				contacts.append(a)
				contacts.append(d)
				break
	for k in range(0, contacts.size(), 2):
		var a := contacts[k]
		_apply_hit(moveset, r, s, a, contacts[k + 1], s[L.base(a) + L.F_MOVE], false, s[L.base(a) + L.F_FACING], events)


static func _hurtbox(moveset, r: Dictionary, s: PackedInt32Array, bd: int) -> PackedInt32Array:
	# Returns [x0, y0, x1, y1] in world units.
	var state := s[bd + L.F_STATE]
	var x := s[bd + L.F_X]
	var y := s[bd + L.F_Y]
	var box: Array = r.stand.hurt
	var height := int(box[3])
	var bottom := y + int(box[1])
	if state == L.S_CROUCH or (state == L.S_ATTACK and s[bd + L.F_MOVE] >= 0 and int(moveset.moves[s[bd + L.F_MOVE]].posture) == 1) or (state == L.S_BLOCKSTUN and (s[bd + L.F_FLAGS] & 512) != 0):
		height = int(r.crouch.hurt_height)
	elif y > 0 or state in [L.S_AIR, L.S_LAUNCHED]:
		box = r.air_hurt
		height = int(box[3])
		bottom = y + int(box[1])
	return PackedInt32Array([x + int(box[0]), bottom, x + int(box[0]) + int(box[2]), bottom + height])


static func _gain_super(r: Dictionary, s: PackedInt32Array, b: int, amount: int) -> void:
	s[b + L.F_SUPER] = clampi(s[b + L.F_SUPER] + amount, 0, int(r.super_max))


static func _apply_hit(moveset, r: Dictionary, s: PackedInt32Array, a: int, d: int, move: int, projectile: bool, facing: int, events: PackedInt32Array) -> void:
	var ba := L.base(a)
	var bd := L.base(d)
	if move < 0:
		return
	var m: Dictionary = moveset.moves[move]
	var kind := int(m.type)
	var dstate := s[bd + L.F_STATE]
	var d_input := s[bd + L.F_PREV_INPUT]
	var d_facing := -facing
	var hitstop := int(m.hitstop)
	# Drive Parry absorbs any strike or projectile.
	if dstate == L.S_PARRY:
		var perfect := s[bd + L.F_STATE_FRAME] <= int(r.parry_perfect_frames)
		if not projectile:
			s[ba + L.F_MOVE_CONNECT] = 3
			s[ba + L.F_HITSTOP] = int(r.parry_perfect_stop) if perfect else int(r.parry_attacker_stop)
		s[bd + L.F_HITSTOP] = 4
		s[bd + L.F_DRIVE] = mini(int(r.drive_max), s[bd + L.F_DRIVE] + int(r.parry_refund))
		if perfect: _enter(s, bd, L.S_IDLE)
		_emit(events, L.EV_PARRY, d, 1 if perfect else 0, a)
		return
	# Armor (Drive Impact) absorbs hits during startup and active frames.
	if dstate == L.S_ATTACK and s[bd + L.F_ARMOR] > 0 and s[bd + L.F_MOVE] >= 0:
		var dm: Dictionary = moveset.moves[s[bd + L.F_MOVE]]
		if s[bd + L.F_STATE_FRAME] < int(dm.startup) + int(dm.active):
			s[bd + L.F_ARMOR] -= 1
			s[bd + L.F_HP] = maxi(1, s[bd + L.F_HP] - int(m.damage) / 2)
			if not projectile:
				s[ba + L.F_MOVE_CONNECT] = 2
				s[ba + L.F_HITSTOP] = hitstop
			s[bd + L.F_HITSTOP] = hitstop
			_emit(events, L.EV_ARMOR, d, move, 0)
			return
	var holding_back := _h(d_input, d_facing) < 0
	var crouching := _v(d_input) < 0
	var can_block := dstate in [L.S_IDLE, L.S_WALK_F, L.S_WALK_B, L.S_CROUCH, L.S_BLOCKSTUN] and s[bd + L.F_Y] == 0
	var level := int(m.level)
	var blocked := can_block and holding_back and not (level == 2 and not crouching) and not (level == 3 and crouching)
	var rush_bonus := int(r.rush.bonus_stun) if s[ba + L.F_RUSH] > 0 and not projectile else 0
	if blocked:
		var chip := int(m.damage) * int(r.chip_percent) / 100
		s[bd + L.F_HP] = maxi(1, s[bd + L.F_HP] - chip)
		_enter(s, bd, L.S_BLOCKSTUN)
		s[bd + L.F_STUN] = int(m.blockstun) + rush_bonus + (int(r.burnout_blockstun) if s[bd + L.F_BURNOUT] != 0 else 0)
		s[bd + L.F_FACING] = d_facing
		if crouching: s[bd + L.F_FLAGS] = s[bd + L.F_FLAGS] | 512
		else: s[bd + L.F_FLAGS] = s[bd + L.F_FLAGS] & ~512
		if not projectile:
			s[ba + L.F_MOVE_CONNECT] = 2
			s[ba + L.F_HITSTOP] = maxi(s[ba + L.F_HITSTOP], hitstop - 2)
		_push(r, s, ba, bd, facing, int(m.pushback), projectile)
		s[bd + L.F_HITSTOP] = maxi(s[bd + L.F_HITSTOP], hitstop - 2)
		_gain_super(r, s, ba, int(r.super_gain_block))
		if s[bd + L.F_BURNOUT] == 0:
			s[bd + L.F_DRIVE] = maxi(0, s[bd + L.F_DRIVE] - int(r.drive_block_loss))
			if s[bd + L.F_DRIVE] == 0: _burnout(s, bd, events, d)
		_emit(events, L.EV_BLOCK, a, move, chip)
		return
	var counter := dstate == L.S_ATTACK and s[bd + L.F_MOVE] >= 0 and s[bd + L.F_STATE_FRAME] < int(moveset.moves[s[bd + L.F_MOVE]].startup)
	var scaling: Array = r.scaling
	var taken := s[bd + L.F_HITS_TAKEN]
	var scale := maxi(int(r.scaling_min), int(scaling[mini(taken, scaling.size() - 1)]))
	var damage := int(m.damage) * scale / 100
	if int(m.min_damage_percent) > 0:
		damage = maxi(damage, int(m.damage) * int(m.min_damage_percent) / 100)
	if counter:
		damage = damage * int(r.counter_hit.damage_percent) / 100
		hitstop += int(r.counter_hit.hitstop_bonus)
	if (s[ba + L.F_FLAGS] & L.FLAG_ASSISTED) != 0 and not projectile:
		damage = damage * int(r.assist_damage_percent) / 100
	damage = maxi(1, damage)
	s[bd + L.F_HP] = maxi(0, s[bd + L.F_HP] - damage)
	s[bd + L.F_HITS_TAKEN] = taken + 1
	s[bd + L.F_COUNTER] = 1 if counter else 0
	s[ba + L.F_COMBO] = taken + 1
	s[ba + L.F_COMBO_DAMAGE] = (s[ba + L.F_COMBO_DAMAGE] if taken > 0 else 0) + damage
	if not projectile:
		s[ba + L.F_MOVE_CONNECT] = 1
	if kind != T_SUPER:
		_gain_super(r, s, ba, damage * int(r.super_gain_hit_percent) / 100)
	_gain_super(r, s, bd, damage * int(r.super_gain_taken_percent) / 100)
	s[ba + L.F_DRIVE] = mini(int(r.drive_max), s[ba + L.F_DRIVE] + int(r.drive_on_hit))
	s[bd + L.F_MOVE] = -1
	s[bd + L.F_ARMOR] = 0
	s[bd + L.F_FACING] = d_facing
	s[bd + L.F_FLAGS] = s[bd + L.F_FLAGS] & ~256
	var airborne := s[bd + L.F_Y] > 0 or dstate in [L.S_AIR, L.S_LAUNCHED]
	var arena := int(r.arena_half_width)
	var near_wall := arena - absi(s[bd + L.F_X]) < int(r.wall_distance) and signi(s[bd + L.F_X]) == facing
	if not airborne and bool(m.wall_splat) and near_wall and s[bd + L.F_WALL_USED] == 0:
		# Wall splat: the defender bounces off the wall into a juggle.
		s[bd + L.F_WALL_USED] = 1
		_enter(s, bd, L.S_LAUNCHED)
		s[bd + L.F_X] = signi(s[bd + L.F_X]) * arena
		s[bd + L.F_VX] = -facing * 120
		s[bd + L.F_VY] = 900
		s[bd + L.F_PUSH_VX] = 0
		s[bd + L.F_Y] = maxi(s[bd + L.F_Y], 1)
		_emit(events, L.EV_WALL, d, move, 0)
	elif airborne or int(m.launch_vy) != 0:
		var vx := int(m.air_launch_vx) if airborne else int(m.launch_vx)
		var vy := int(m.air_launch_vy) if airborne else int(m.launch_vy)
		if kind == T_SUPER or kind == T_SPECIAL:
			vx = maxi(vx, int(m.launch_vx))
			vy = maxi(vy, int(m.launch_vy))
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
		s[bd + L.F_STUN] = int(m.hitstun) + rush_bonus + (int(r.counter_hit.hitstun_bonus) if counter else 0)
		_push(r, s, ba, bd, facing, int(m.pushback), projectile)
	if not projectile:
		s[ba + L.F_HITSTOP] = maxi(s[ba + L.F_HITSTOP], hitstop)
	s[bd + L.F_HITSTOP] = maxi(s[bd + L.F_HITSTOP], hitstop)
	_emit(events, L.EV_HIT, a, move, damage)
	if counter:
		_emit(events, L.EV_COUNTER, a, move, 0)
	_check_ko(s, ba, bd, d, a, events)


static func _check_ko(s: PackedInt32Array, ba: int, bd: int, d: int, a: int, events: PackedInt32Array) -> void:
	if s[bd + L.F_HP] > 0 or s[bd + L.F_STATE] == L.S_KO:
		return
	_enter(s, bd, L.S_KO)
	s[bd + L.F_VX] = s[ba + L.F_FACING] * 300
	s[bd + L.F_VY] = maxi(s[bd + L.F_VY], 700)
	s[bd + L.F_Y] = maxi(s[bd + L.F_Y], 1)
	s[L.H_WINNER] = s[ba + L.F_TEAM]
	_emit(events, L.EV_KO, d, a, 0)


static func _push(r: Dictionary, s: PackedInt32Array, ba: int, bd: int, facing: int, amount: int, projectile: bool) -> void:
	# Push the defender away; if it is pinned at the wall, the attacker recoils.
	var arena := int(r.arena_half_width)
	if absi(s[bd + L.F_X]) >= arena - 200 and signi(s[bd + L.F_X]) == facing and not projectile:
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
