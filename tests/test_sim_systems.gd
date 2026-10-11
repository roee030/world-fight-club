extends SceneTree

## Fighting-game systems on the deterministic sim: Pro motion specials and Easy
## one-button specials, projectiles, invincible reversal, Super Art with
## super-freeze and damage floor, meter gain, Drive Parry / Rush / Impact armor,
## burnout, throws and throw tech, wall splat, normal -> special cancel.

const Sim = preload("res://sim/sim.gd")
const L = preload("res://sim/layout.gd")
const Moveset = preload("res://sim/moveset.gd")

var ms
const R := L.IN_RIGHT
const LT := L.IN_LEFT
const D := L.IN_DOWN


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	ms = Moveset.compile(["res://data/movesets/universal.json"])
	for check in [_pro_special_projectile, _easy_specials, _reversal_invuln, _super, _parry, _rush, _impact_armor, _burnout, _throw_and_tech, _wall_splat, _special_cancel, _easy_auto_combo, _round_flow, _archetypes, _command_grab, _multi_hit_and_punish]:
		var error: String = check.call()
		if error != "":
			return _fail(error)
	print("PASS: sim systems (specials, projectile, reversal, super, drive, throws, wall splat, cancels)")
	quit()


func _match(x0: int, x1: int, super0: int = 0, super1: int = 0) -> PackedInt32Array:
	return Sim.new_match(ms, [{"x": x0, "super": super0}, {"x": x1, "super": super1}], 3)


func _f(s: PackedInt32Array, i: int, field: int) -> int:
	return s[L.base(i) + field]


## Runs `frames` frames; p0/p1 map frame number (1-based) -> input (held inputs
## can be given as {"from": a, "to": b, "input": x} entries in the arrays).
func _play(s: PackedInt32Array, frames: int, p0: Dictionary, p1: Dictionary = {}, hold0: int = 0, hold1: int = 0) -> Array[int]:
	var kinds: Array[int] = []
	for f in range(1, frames + 1):
		var events := Sim.step(ms, s, PackedInt32Array([int(p0.get(f, hold0)), int(p1.get(f, hold1))]))
		for e in range(0, events.size(), L.EVENT_SIZE):
			kinds.append(events[e])
			kinds.append(events[e + 1])
			kinds.append(events[e + 2])
	return kinds


func _has(kinds: Array[int], kind: int, fighter: int = -1, a: int = -99999) -> bool:
	for k in range(0, kinds.size(), 3):
		if kinds[k] == kind and (fighter < 0 or kinds[k + 1] == fighter) and (a == -99999 or kinds[k + 2] == a):
			return true
	return false


func _move(name: String) -> int:
	return int(ms.index[name])


func _pro_special_projectile() -> String:
	var s := _match(-16000, 16000)
	# Quarter-circle forward + punch: 2, 3, 6+LP (player 0 faces +x, so forward = right).
	var kinds := _play(s, 70, {1: D, 2: D | R, 3: R | L.IN_LP})
	if not _has(kinds, L.EV_SPECIAL, 0, _move("236P")): return "236+P must start the Energy Wave"
	if not _has(kinds, L.EV_PROJECTILE, 0): return "the Energy Wave must spawn a projectile"
	if not _has(kinds, L.EV_HIT, 0, _move("236P")): return "the projectile must travel and hit a distant rival"
	if _f(s, 1, L.F_HP) >= 10000: return "projectile hit dealt no damage"
	return ""


func _easy_specials() -> String:
	var cases := [["N", L.IN_SP, "236P"], ["D", L.IN_SP | D, "623P"], ["F", L.IN_SP | R, "214K"], ["B", L.IN_SP | LT, "236K"]]
	for c in cases:
		var s := _match(-25000, 25000)
		var kinds := _play(s, 5, {1: int(c[1])})
		if not _has(kinds, L.EV_SPECIAL, 0, _move(c[2])):
			return "Easy SP+%s must start %s" % [c[0], c[2]]
	return ""


func _reversal_invuln() -> String:
	# Player 0 throws a heavy punch; player 1 answers with the invincible Rising Fist.
	var s := _match(-5200, 5200)
	var kinds := _play(s, 60, {1: L.IN_HP}, {6: L.IN_SP | D})
	if _f(s, 1, L.F_HP) < 10000: return "the reversal must be invincible through the heavy punch"
	if not _has(kinds, L.EV_HIT, 1, _move("623P")): return "the reversal must hit the attacker"
	return ""


func _super() -> String:
	var s := _match(-6000, 6000, 10000)
	var kinds := _play(s, 4, {1: D, 2: D | R, 3: R})
	kinds.append_array(_play(s, 120, {1: D, 2: D | R, 3: R | L.IN_LP}))
	if not _has(kinds, L.EV_SUPER, 0, _move("SUPER")): return "236236+P with a full bar must start the Super Art"
	if _f(s, 0, L.F_SUPER) != 0: return "the Super Art must spend its bar"
	var dealt := 10000 - _f(s, 1, L.F_HP)
	if dealt < 2600 / 2: return "the Super Art must deal at least its damage floor (dealt %d)" % dealt
	# Without meter the same motion does not super.
	var s2 := _match(-6000, 6000, 0)
	var kinds2 := _play(s2, 4, {1: D, 2: D | R, 3: R})
	kinds2.append_array(_play(s2, 20, {1: D, 2: D | R, 3: R | L.IN_LP}))
	if _has(kinds2, L.EV_SUPER): return "no Super Art without meter"
	# Meter: landing hits builds Super gauge.
	var s3 := _match(-5200, 5200)
	_play(s3, 40, {1: L.IN_HP})
	if _f(s3, 0, L.F_SUPER) <= 0: return "hitting must build Super gauge"
	return ""


func _parry() -> String:
	var s := _match(-5200, 5200)
	var kinds := _play(s, 30, {3: L.IN_HP}, {}, 0, L.IN_DRIVE)
	if not _has(kinds, L.EV_PARRY, 1): return "holding Drive must parry the heavy punch"
	if _f(s, 1, L.F_HP) != 10000: return "a parried strike deals no damage"
	return ""


func _rush() -> String:
	var s := _match(-30000, 30000)
	var kinds := _play(s, 30, {1: R | L.IN_DRIVE}, {}, R)
	if not _has(kinds, L.EV_RUSH, 0): return "Drive + forward must start a Drive Rush"
	var travelled := _f(s, 0, L.F_X) + 30000
	if travelled < 18000: return "Drive Rush must cover ground quickly (%d)" % travelled
	if _f(s, 0, L.F_DRIVE) >= int(ms.rules.drive_max): return "Drive Rush must cost Drive"
	return ""


func _impact_armor() -> String:
	var s := _match(-5600, 5600)
	# Player 1 starts a Drive Impact (Drive + HP); player 0 jabs into its startup.
	var kinds := _play(s, 80, {8: L.IN_LP}, {1: L.IN_DRIVE | L.IN_HP})
	if not _has(kinds, L.EV_ARMOR, 1): return "Drive Impact armor must absorb the jab"
	if not _has(kinds, L.EV_HIT, 1, _move("IMPACT")): return "Drive Impact must land after absorbing"
	return ""


func _burnout() -> String:
	var s := _match(-5600, 5600)
	s[L.base(1) + L.F_DRIVE] = 500
	var kinds := _play(s, 30, {1: L.IN_HP}, {}, 0, R)
	if not _has(kinds, L.EV_BURNOUT, 1): return "blocking with an empty Drive gauge must cause burnout"
	if _f(s, 1, L.F_BURNOUT) != 1: return "burnout flag must be set"
	var kinds2 := _play(s, 10, {}, {1: R | L.IN_DRIVE})
	if _has(kinds2, L.EV_RUSH, 1): return "no Drive Rush during burnout"
	return ""


func _throw_and_tech() -> String:
	var s := _match(-4000, 4000)
	var kinds := _play(s, 60, {1: L.IN_LP | L.IN_LK})
	if not _has(kinds, L.EV_THROW, 0): return "LP+LK up close must throw"
	if 10000 - _f(s, 1, L.F_HP) != 1200: return "throw damage must be 1200"
	var s2 := _match(-4000, 4000)
	var kinds2 := _play(s2, 60, {1: L.IN_LP | L.IN_LK}, {9: L.IN_LP | L.IN_LK})
	if not _has(kinds2, L.EV_TECH, 1): return "pressing LP+LK while being thrown must tech"
	if _f(s2, 1, L.F_HP) != 10000: return "a teched throw deals no damage"
	return ""


func _wall_splat() -> String:
	var arena := int(ms.rules.arena_half_width)
	var s := _match(arena - 16000, arena - 3000)
	var kinds := _play(s, 60, {1: L.IN_SP | R})
	if not _has(kinds, L.EV_HIT, 0, _move("214K")): return "the Rush Kick must connect near the wall"
	if not _has(kinds, L.EV_WALL, 1): return "a wall-splat move near the wall must splat"
	return ""


func _special_cancel() -> String:
	# 2LP, then quarter-circle + punch during the cancel window: Energy Wave cancel.
	var s := _match(-5200, 5200)
	var kinds := _play(s, 60, {1: D | L.IN_LP, 2: D, 3: D, 4: D, 5: D, 6: D, 7: D, 8: D | R, 9: R | L.IN_HP})
	if not _has(kinds, L.EV_HIT, 0, _move("2LP")): return "2LP must hit"
	if not _has(kinds, L.EV_SPECIAL, 0, _move("236P")): return "2LP must cancel into the Energy Wave on hit"
	return ""


func _easy_auto_combo() -> String:
	# Easy controls: mashing LP walks the auto route 5LP > 5LK > 5HP > Rush Kick.
	var s := Sim.new_match(ms, [{"x": -5200, "easy": true}, {"x": 5200}], 3)
	var presses := {}
	for f in range(1, 90, 3): presses[f] = L.IN_LP
	var kinds := _play(s, 90, presses)
	var hits := 0
	for k in range(0, kinds.size(), 3):
		if kinds[k] == L.EV_HIT and kinds[k + 1] == 0: hits += 1
	if hits < 4: return "Easy LP mash must auto-combo at least 4 hits (got %d)" % hits
	if not _has(kinds, L.EV_SPECIAL, 0, _move("214K")): return "the Easy auto-combo must end in the Rush Kick"
	# Assisted damage: the auto-combo's follow-ups deal 80% (5LP 300 + 5LK 400 * 80%).
	var easy := Sim.new_match(ms, [{"x": -5200, "easy": true}, {"x": 5200}], 3)
	_play(easy, 40, {1: L.IN_LP, 8: L.IN_LP})
	var easy_dealt := 10000 - _f(easy, 1, L.F_HP)
	var pro := Sim.new_match(ms, [{"x": -5200}, {"x": 5200}], 3)
	_play(pro, 40, {1: L.IN_LP, 8: L.IN_LK})
	var pro_dealt := 10000 - _f(pro, 1, L.F_HP)
	if pro_dealt != 700 or easy_dealt != 300 + 400 * 80 / 100:
		return "assisted damage: pro %d (expected 700), easy %d (expected 620)" % [pro_dealt, easy_dealt]
	return ""


func _round_flow() -> String:
	# Best of three with intros: inputs are ignored during the intro, a KO wins
	# the round, fighters respawn for the next one, two wins end the match.
	var s := Sim.new_match(ms, [{"x": -5200, "hp": 600}, {"x": 5200, "hp": 600}], 3, {"intro": true, "rounds_to_win": 2})
	var kinds := _play(s, 30, {5: L.IN_HP})
	if _f(s, 1, L.F_HP) != 600: return "inputs during the intro must be ignored"
	kinds = _play(s, 70, {})
	if not _has(kinds, L.EV_FIGHT): return "the intro must end with FIGHT"
	var wins_needed := 2
	var guard := 0
	while s[L.H_MATCH_OVER] == 0 and guard < 3000:
		guard += 1
		var press := L.IN_HP if guard % 40 == 1 else 0
		var events := Sim.step(ms, s, PackedInt32Array([press, 0]))
		for e in range(0, events.size(), L.EVENT_SIZE):
			kinds.append(events[e]); kinds.append(events[e + 1]); kinds.append(events[e + 2])
	if s[L.H_MATCH_OVER] != 1: return "the match must end"
	if s[L.H_WINS + 0] != wins_needed or s[L.H_WINS + 1] != 0: return "player 0 must win 2-0 (got %d-%d)" % [s[L.H_WINS], s[L.H_WINS + 1]]
	if not _has(kinds, L.EV_ROUND_START, -1, 2): return "round 2 must start after round 1"
	return ""


func _archetypes() -> String:
	# A rushdown fighter overrides moves: faster jab, Lightning Dash instead of a projectile.
	var both = Moveset.compile(["res://data/movesets/universal.json", "res://data/movesets/rushdown.json"])
	var s := Sim.new_match(both, [{"x": -16000, "archetype": "rushdown"}, {"x": 16000}], 3)
	var kinds: Array[int] = []
	for f in range(1, 40):
		var events := Sim.step(both, s, PackedInt32Array([L.IN_SP if f == 1 else 0, L.IN_SP if f == 1 else 0]))
		for e in range(0, events.size(), L.EVENT_SIZE):
			kinds.append(events[e]); kinds.append(events[e + 1]); kinds.append(events[e + 2])
	var rush_dash := int(both._names[both.arch_index("rushdown")]["236P"])
	if not _has(kinds, L.EV_SPECIAL, 0, rush_dash): return "the rushdown fighter's Easy special must be the Lightning Dash"
	if _has(kinds, L.EV_PROJECTILE, 0): return "the rushdown fighter has no projectile"
	if not _has(kinds, L.EV_PROJECTILE, 1): return "the universal fighter keeps the Energy Wave projectile"
	var jab := int(both._names[both.arch_index("rushdown")]["5LP"])
	if int(both.moves[jab].startup) != 4: return "the rushdown jab must be faster (startup 4)"
	return ""


func _command_grab() -> String:
	# The grappler's command grab beats blocking and cannot be teched.
	var all = Moveset.compile(["res://data/movesets/universal.json", "res://data/movesets/rushdown.json", "res://data/movesets/grappler.json"])
	var s := Sim.new_match(all, [{"x": -5200, "archetype": "grappler"}, {"x": 5200}], 3)
	var kinds: Array[int] = []
	for f in range(1, 60):
		# Player 1 holds back (blocking) and mashes tech; player 0 does SP + forward (Iron Hug).
		# (mashing starts once grabbed; earlier it would be a throw attempt of its own)
		var p1 := L.IN_RIGHT | ((L.IN_LP | L.IN_LK) if f >= 8 and f % 2 == 0 else 0)
		var events := Sim.step(all, s, PackedInt32Array([(L.IN_SP | L.IN_RIGHT) if f == 1 else 0, p1]))
		for e in range(0, events.size(), L.EVENT_SIZE):
			kinds.append(events[e]); kinds.append(events[e + 1]); kinds.append(events[e + 2])
	if _has(kinds, L.EV_TECH): return "a command grab must not be teched"
	if not _has(kinds, L.EV_THROW, 0): return "the Iron Hug must grab a blocking rival"
	if 10000 - _f(s, 1, L.F_HP) != 1700: return "Iron Hug damage must be 1700 (got %d)" % (10000 - _f(s, 1, L.F_HP))
	return ""


func _multi_hit_and_punish() -> String:
	# The Super Art lands 5 separate hits.
	var s := _match(-6000, 6000, 10000)
	var kinds := _play(s, 4, {1: D, 2: D | R, 3: R})
	kinds.append_array(_play(s, 120, {1: D, 2: D | R, 3: R | L.IN_LP}))
	var super_hits := 0
	for k in range(0, kinds.size(), 3):
		if kinds[k] == L.EV_HIT and kinds[k + 1] == 0 and kinds[k + 2] == _move("SUPER"): super_hits += 1
	if super_hits != 5: return "the Super Art must land 5 hits (landed %d)" % super_hits
	# Punish counter: player 1 whiffs a heavy kick; once it is in recovery,
	# player 0 steps next to it and jabs (hits on the jab's 5th frame).
	var q := _match(-20000, 6000)
	_play(q, 1, {}, {1: L.IN_HK})
	var guard := 0
	while _f(q, 1, L.F_STATE_FRAME) < 18 and guard < 60:
		guard += 1
		Sim.step(ms, q, PackedInt32Array([0, 0]))
	q[L.base(0) + L.F_X] = _f(q, 1, L.F_X) - 9500
	var kinds3 := _play(q, 12, {1: L.IN_LP})
	var punished := false
	for k in range(0, kinds3.size(), 3):
		if kinds3[k] == L.EV_COUNTER and kinds3[k + 1] == 0: punished = true
	if not punished: return "a jab into the heavy kick's recovery must be a punish counter"
	return ""
