extends SceneTree

const EXPECTED_IDS := ["gadi_eisenkot", "yair_golan", "itamar_ben_gvir", "aryeh_deri", "bezalel_smotrich", "joint_list", "trump"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog := FinisherCatalog.new()
	assert(catalog.load_default(), str(catalog.errors))
	for fighter_id in EXPECTED_IDS:
		var definition: Dictionary = catalog.definition_for(fighter_id)
		assert(definition.implemented, fighter_id + " delivered finisher must be enabled")
		var hits: Array = definition.events.filter(func(event): return event.type == "hit")
		assert(not hits.is_empty() and hits.back().get("final", false))
		assert(hits.filter(func(event): return event.get("final", false)).size() == 1)
		var arena := Node3D.new(); root.add_child(arena)
		var camera := Camera3D.new(); camera.position = Vector3(0, 3, 8); arena.add_child(camera)
		var attacker := GameFighter.new(); attacker.setup(fighter_id, 0, false); arena.add_child(attacker)
		var defender := GameFighter.new(); defender.setup("bennet", 1, false); arena.add_child(defender)
		attacker.set_physics_process(false); defender.set_physics_process(false); attacker.meter = 100; defender.health = 1
		var director := FinisherDirector.new(); arena.add_child(director); director.configure(arena, arena, camera); director.catalog = catalog; director.set_effect_density("mobile")
		var counts := {"final": 0, "result": 0}; director.final_hit.connect(func(_who): counts.final += 1); director.result_ready.connect(func(_who): counts.result += 1)
		assert(director.begin(attacker, defender, definition))
		var final_time: float = float(hits.back().at) + 0.001; director.advance(final_time)
		assert(defender.health == 0 and counts.final == 1)
		assert(director.temporary_actor_count() <= 12)
		director.advance(float(definition.duration) - final_time + 0.01)
		director.advance(float(catalog.celebration_for(definition.celebration_id).duration) + 0.1)
		assert(counts.result == 1 and not director.active and director.temporary_actor_count() == 0)
		arena.free()
	print("PASS: remaining delivered finishers have one final hit, mobile bounds, result and cleanup")
	quit(0)
