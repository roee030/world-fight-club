extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog := FinisherCatalog.new()
	var loaded := catalog.load_default()
	assert(loaded, str(catalog.errors))
	var definition: Dictionary = catalog.definition_for("yair_lapid")
	assert(definition.implemented, "Lapid delivered finisher must be enabled")
	var hits: Array = definition.events.filter(func(event): return event.type == "hit")
	assert(hits.size() == 6 and hits[5].get("final", false))
	var combo_captions: Array = definition.events.filter(func(event): return event.type == "caption" and "HIT COMBO" in str(event.get("text", "")))
	assert(combo_captions.size() == 5)
	for index in range(5):
		assert(combo_captions[index].text == "%d HIT COMBO" % (index + 1))
		assert(not hits[index].get("final", false))
	for direction in [1.0, -1.0]:
		for starting_health in [1.0, 10.0]:
			var arena := Node3D.new()
			root.add_child(arena)
			var camera := Camera3D.new()
			arena.add_child(camera)
			camera.position = Vector3(0, 3, 8)
			var original_camera := camera.transform
			var attacker := GameFighter.new()
			var defender := GameFighter.new()
			attacker.setup("yair_lapid", 0, false)
			defender.setup("avigdor", 1, false)
			arena.add_child(attacker)
			arena.add_child(defender)
			attacker.set_physics_process(false)
			defender.set_physics_process(false)
			attacker.position.x = -0.6 * direction
			defender.position.x = 0.6 * direction
			attacker.meter = 100
			defender.health = starting_health
			var director := FinisherDirector.new()
			arena.add_child(director)
			director.configure(arena, arena, camera)
			director.catalog = catalog
			director.set_effect_density("mobile")
			var counts := {"final": 0, "celebration": 0, "result": 0}
			director.final_hit.connect(func(_index): counts.final += 1)
			director.celebration_started.connect(func(_id): counts.celebration += 1)
			director.result_ready.connect(func(_index): counts.result += 1)
			assert(director.begin(attacker, defender, definition))
			var elapsed := 0.0
			var original_frames = attacker._visual.sprite.sprite_frames
			for index in range(6):
				var target: float = float(hits[index].at) + 0.001
				director.advance(target - elapsed)
				elapsed = target
				assert(director.temporary_actor_count() <= 12)
				var clips: Array = definition.events.filter(func(event): return event.type == "fighter_clip" and float(event.at) <= elapsed)
				assert(not clips.is_empty())
				var clip: Dictionary = clips.back()
				var sprite = attacker._visual.sprite
				var expected_foot: float = (float(clip.foot_baseline) - float(clip.region[3]) * 0.5) * sprite.pixel_size + float(attacker._visual.geometry.ground_offset_m)
				assert(is_equal_approx(sprite.position.y, expected_foot), "Authored boxing pose respects source foot baseline")
				for actor in director._actors.values():
					if actor.grounded:
						assert(is_equal_approx(actor.position.y, actor.floor_y))
						assert(actor.shadow != null and is_equal_approx(actor.shadow.position.y, 0.015))
				if index < 5:
					assert(defender.health >= 1 and counts.final == 0, "Boxing stagger never KOs low health defender")
				else:
					assert(defender.health == 0 and counts.final == 1)
				if index == 2:
					director.set_paused(true)
					director.advance(5)
					assert(is_equal_approx(director.timeline.elapsed(), elapsed))
					assert(defender.health >= 1 and counts.final == 0)
					director.set_paused(false)
			var remaining: float = float(definition.duration) + float(catalog.celebration_for(definition.celebration_id).duration) + 0.1 - elapsed
			director.advance(remaining)
			# Celebration is a separate timeline; remaining time never skips its result.
			assert(counts.celebration == 1)
			director.advance(float(catalog.celebration_for(definition.celebration_id).duration) + 0.1)
			assert(counts.final == 1 and counts.result == 1)
			assert(not director.active and director.temporary_actor_count() == 0)
			assert(not attacker.cinematic_locked and not defender.cinematic_locked)
			assert(camera.transform == original_camera)
			assert(attacker._visual.sprite.sprite_frames == original_frames)
			defender.health = starting_health
			defender.round_over = false
			attacker.meter = 100
			director.force_opening_miss = true
			assert(director.begin(attacker, defender, definition))
			director.advance(float(hits[0].at) + 0.01)
			assert(not director.active and defender.health == starting_health)
			assert(counts.final == 1 and counts.result == 1 and director.temporary_actor_count() == 0)
			arena.free()
	print("PASS: Lapid both sides, health 1/10, five safe crosses, pause, one final KO, grounded guests, celebration and cleanup")
	quit(0)

