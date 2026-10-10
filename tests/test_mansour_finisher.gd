extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog := FinisherCatalog.new()
	assert(catalog.load_default(), str(catalog.errors))
	var definition: Dictionary = catalog.definition_for("mansour_abbas")
	assert(definition.implemented, "Mansour delivered finisher must be enabled")
	var hits: Array = definition.events.filter(func(event): return event.type == "hit")
	assert(hits.size() == 4)
	for index in range(3): assert(not hits[index].get("final", false))
	assert(hits[3].get("final", false))
	var rain: Array = definition.events.filter(func(event): return event.type == "spawn_prop" and str(event.get("id", "")).begins_with("cash_rain"))
	assert(rain.size() == 3)
	for direction in [1.0, -1.0]:
		var arena := Node3D.new(); root.add_child(arena)
		var camera := Camera3D.new(); camera.position = Vector3(0, 3, 8); arena.add_child(camera)
		var attacker := GameFighter.new(); attacker.setup("mansour_abbas", 0, false); arena.add_child(attacker)
		var defender := GameFighter.new(); defender.setup("bennet", 1, false); arena.add_child(defender)
		attacker.set_physics_process(false); defender.set_physics_process(false)
		attacker.position.x = -0.6 * direction; defender.position.x = 0.6 * direction
		attacker.meter = 100; defender.health = 1
		var director := FinisherDirector.new(); arena.add_child(director); director.configure(arena, arena, camera); director.catalog = catalog
		var counts := {"final": 0, "result": 0}; director.final_hit.connect(func(_who): counts.final += 1); director.result_ready.connect(func(_who): counts.result += 1)
		assert(director.begin(attacker, defender, definition))
		var elapsed := 0.0
		for index in range(3):
			var target: float = float(hits[index].at) + 0.001; director.advance(target - elapsed); elapsed = target
			assert(defender.health == 1 and counts.final == 0, "Money rain never KOs before the bundle")
			assert(director.temporary_actor_count() <= 12)
		director.set_paused(true); var paused_at := director.timeline.elapsed(); director.advance(2); assert(director.timeline.elapsed() == paused_at); director.set_paused(false)
		var final_time: float = float(hits[3].at) + 0.001; director.advance(final_time - elapsed); elapsed = final_time
		assert(defender.health == 0 and counts.final == 1)
		director.advance(float(definition.duration) - elapsed + 0.01)
		director.advance(float(catalog.celebration_for(definition.celebration_id).duration) + 0.1)
		assert(counts.result == 1 and not director.active and director.temporary_actor_count() == 0)
		arena.free()
	print("PASS: Mansour cash rain, low-health staggers, both sides, pause, one bundle KO and cleanup")
	quit(0)
