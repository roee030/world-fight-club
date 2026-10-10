extends SceneTree

## Feel metrics for ground movement and jumping, measured in physics frames.
## Targets come from docs/superpowers/plans/2026-10-09-fighter-engine-flow-plan.md.

const FightSim = preload("res://tests/helpers/fight_sim.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var sim = FightSim.new()
	await sim.start(self, root, "bennet", "avigdor", -4.0, 4.0)
	var player = sim.player
	# 1. Walk reaches 90% of top speed in <= 5 frames, stops in <= 4.
	var top := 3.25  # bennet walk_speed
	var frames_to_speed := -1
	for f in range(30):
		sim.step(1.0)
		if frames_to_speed < 0 and absf(player.velocity.x) >= 0.9 * top:
			frames_to_speed = f + 1
	if frames_to_speed < 0 or frames_to_speed > 5:
		return _fail("walk needs %d frames to reach 90%% speed (max 5)" % frames_to_speed)
	var stop_frames := -1
	for f in range(30):
		sim.step(0.0)
		if absf(player.velocity.x) < 0.05:
			stop_frames = f + 1
			break
	if stop_frames < 0 or stop_frames > 4:
		return _fail("walk needs %d frames to stop (max 4)" % stop_frames)
	# 2. Back-walk is slower than forward-walk.
	sim.teleport(-1.5, 1.5)
	sim.steps(20, 1.0)
	var forward_speed := absf(player.velocity.x)
	sim.teleport(-1.5, 1.5)
	sim.steps(20, 0.0)
	sim.steps(20, -1.0)
	var back_speed := absf(player.velocity.x)
	if back_speed > forward_speed * 0.85:
		return _fail("back-walk %.2f must be <= 0.85x forward %.2f" % [back_speed, forward_speed])
	# 3. Holding jump jumps once (edge-triggered): a held key does not bunny-hop.
	sim.teleport(-3.0, 3.0)
	sim.steps(30)
	var takeoffs := 0
	var was_air := false
	for f in range(150):
		sim.step(0.0, true)
		var air: bool = not player.is_on_floor()
		if air and not was_air: takeoffs += 1
		was_air = air
	if takeoffs != 1:
		return _fail("holding jump produced %d jumps (want 1)" % takeoffs)
	sim.steps(40)
	# 4. Facing never flips while airborne, even when the rival ends up behind.
	sim.teleport(-1.5, 1.5)
	sim.steps(20)
	var facing_before: float = player.facing
	sim.step(0.0, true)
	for f in range(8): sim.step(1.0)
	sim.enemy.position.x = -3.0
	var flipped := false
	for f in range(20):
		sim.step(0.0)
		if not player.is_on_floor() and player.facing != facing_before: flipped = true
	if flipped:
		return _fail("facing flipped in the air")
	# 5. Jump arc: snappy fall (heavier gravity on the way down), total air time <= 0.62 s.
	sim.steps(60)
	sim.teleport(-3.0, 3.0)
	sim.steps(20)
	sim.step(0.0, true)
	var air_frames := 1
	var apex_frame := 0
	var apex := 0.0
	for f in range(120):
		sim.step()
		if player.is_on_floor(): break
		air_frames += 1
		if player.global_position.y > apex:
			apex = player.global_position.y
			apex_frame = air_frames
	if air_frames * FightSim.DT > 0.62:
		return _fail("jump air time %.2fs is floaty (max 0.62)" % (air_frames * FightSim.DT))
	if apex_frame * 2 <= air_frames:
		return _fail("jump must fall faster than it rises (apex at %d of %d frames)" % [apex_frame, air_frames])
	# 6. Buffered inputs are not eaten by hit-stop.
	sim.teleport(-3.0, 3.0)
	sim.steps(20)
	player.buffered_attack = "light"
	player.buffer_time = 0.34
	player.hit_stop = 0.2
	var before: float = player.buffer_time
	sim.steps(6)
	if player.buffer_time < before - 0.001:
		return _fail("buffer ticked down during hit-stop (%.3f -> %.3f)" % [before, player.buffer_time])
	sim.cleanup()
	print("PASS: movement and jump feel metrics")
	quit()
