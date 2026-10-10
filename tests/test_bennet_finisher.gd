extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	assert(main._finisher_catalog.errors.is_empty())
	assert(main._finisher_catalog.definition_for("bennet").implemented)
	main._setup_bout("bennet", "avigdor", 1, "BENNET DELIVERY QA")
	main.enemy.is_cpu = false
	for frame in range(95): await physics_frame
	while not main.round_ready: await physics_frame  # the announcer sets the intro length
	main.set_process(false)
	main.set_physics_process(false)
	main.player.set_physics_process(false)
	main.enemy.set_physics_process(false)
	main.player.position = Vector3(-0.6, 0, 0)
	main.enemy.position = Vector3(0.6, 0, 0)
	main.player.meter = 100
	main.enemy.health = 10
	main.player_rounds = 1
	main.match_state = main.MatchState.Value.FIGHTING
	main.round_ready = true
	var counts := {"final": 0, "celebration": 0, "result": 0}
	var director = main._finisher_director
	director.final_hit.connect(func(_index): counts.final += 1)
	director.celebration_started.connect(func(_id): counts.celebration += 1)
	director.result_ready.connect(func(_index): counts.result += 1)
	main.buttons.special.emit_signal("button_down")
	main._physics_process(0)
	main._physics_process(0.55)
	assert(director.active and main.player.meter == 0)
	var clock: float = main.round_clock
	main._process(1.3)
	assert(main.enemy.health == 10 and counts.final == 0)
	assert(main.round_clock == clock)
	assert(director.temporary_actor_count() > 0, "Laptop is visible before impact")
	main._toggle_pause()
	var elapsed: float = director.timeline.elapsed()
	main._process(2)
	assert(director.timeline.elapsed() == elapsed and main.enemy.health == 10)
	main._toggle_pause()
	main._process(0.3)
	assert(main.enemy.health == 0 and counts.final == 1)
	assert(main.player_rounds == 2)
	main._process(0.7)
	assert(counts.celebration == 1 and not main.result_root.visible)
	assert(main.player.position.y == 0 and main.enemy.position.y == 0)
	main._process(5)
	assert(counts.result == 1 and main.result_root.visible)
	assert(not director.active and director.temporary_actor_count() == 0)
	assert(not main.player.cinematic_locked and not main.enemy.cinematic_locked)
	main._process(2)
	assert(counts.final == 1 and counts.result == 1, "No duplicate damage or result")
	main.enemy.health = 10
	main.enemy.round_over = false
	main.player.meter = 100
	director.force_opening_miss = true
	assert(director.begin(main.player, main.enemy, main._finisher_catalog.definition_for("bennet")))
	director.advance(1.6)
	assert(not director.active and main.enemy.health == 10)
	assert(director.temporary_actor_count() == 0 and main.player.meter == 0)
	assert(counts.final == 1 and counts.result == 1)
	director.force_opening_miss = false
	main.player.position = Vector3(0.6, 0, 0)
	main.enemy.position = Vector3(-0.6, 0, 0)
	main.player.meter = 100
	assert(director.begin(main.player, main.enemy, main._finisher_catalog.definition_for("bennet")))
	director.advance(1.0)
	var laptop = director._actors["laptop"]
	assert(laptop.position.x < main.player.position.x, "Right-side laptop spawns toward opponent")
	assert(laptop.sprite.flip_h, "Right-side laptop artwork faces opponent")
	director.set_paused(true)
	var laptop_position: Vector3 = laptop.position
	director.advance(1)
	assert(laptop.position == laptop_position)
	director.cancel()
	assert(director.temporary_actor_count() == 0 and not main.player.cinematic_locked)
	main.free()
	print("PASS: delivered Bennet one-press MAX, laptop timing, pause, one KO, celebration, cleanup and miss")
	quit(0)
