extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fighter = load("res://scripts/fighter.gd").new()
	if not fighter.has_method("enter_cinematic_lock"):
		push_error("cinematic fighter API missing")
		fighter.free()
		quit(1)
		return
	fighter.setup("bennet", 0, false)
	get_root().add_child(fighter)
	await process_frame
	fighter.enter_cinematic_lock(Vector3(-1.0, 0.0, 0.0), 1.0)
	var anchor: Vector3 = fighter.position
	fighter.set_controls(1.0, true, true, false, "heavy")
	for frame in range(3): await physics_frame
	assert(fighter.position == anchor)
	var defeats := [0]
	fighter.defeated.connect(func(_who): defeats[0] += 1)
	assert(fighter.apply_authored_hit("first", 7.0, 1.0, "hit"))
	assert(fighter.health == 93.0)
	assert(fighter.facing == -1.0 and fighter._visual.sprite.flip_h, "defender faces incoming strike")
	assert(not fighter.apply_authored_hit("first", 7.0, 1.0, "hit"))
	assert(fighter.apply_authored_hit("final", 999.0, 1.0, "finish_fall"))
	assert(defeats[0] == 1)
	assert(not fighter.apply_authored_hit("another", 999.0, 1.0, "finish_fall"))
	assert(defeats[0] == 1)
	fighter.exit_cinematic_lock()
	assert(fighter.round_over)
	fighter.reset_round(-1.0)
	assert(not fighter.cinematic_locked)
	assert(fighter.health == 100.0)
	fighter.free()
	print("PASS: cinematic locks, authored hit deduplication, final pose")
	quit(0)
