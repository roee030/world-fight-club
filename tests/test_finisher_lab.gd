extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var lab = load("res://scripts/character_debug.gd").new()
	root.add_child(lab)
	await process_frame
	if not lab.has_method("preview_finisher"):
		push_error("Finisher Lab preview API is missing")
		quit(1)
		return
	lab.preview_finisher("bibi", "hit")
	var preview = lab.finisher_lab
	# Test the planned guard with an explicit fixture, independent of delivery progress.
	preview.catalog._definitions.bibi.implemented = false
	lab.preview_finisher("bibi", "hit")
	if not preview.catalog.errors.is_empty():
		push_error("Finisher catalog invalid: " + "; ".join(preview.catalog.errors))
		quit(1)
		return
	assert(preview.catalog.definition_for("bennet").finisher_id == "startup_exit")
	assert(not preview.director.active and preview.status.text.contains("PLANNED"))
	assert(preview.attacker_selector.item_count == 13 and preview.defender_selector.item_count == 13)
	assert(preview.scenario_selector.item_count == 4)
	assert(preview.roster_finish_buttons.size() == 13, "Fight Lab needs one Finish Attack button per fighter")
	assert(preview.has_node("LabUI/Controls/PlaybackControls/LiveFightTest"), "Fight Lab needs a playable versus test")
	assert(preview.has_node("LabUI/Controls/PlaybackControls/CelebrationPreview"), "Fight Lab needs a dedicated winner celebration preview")
	assert(preview.live_attack_buttons.size() == 4, "playable lab needs jab, cross, special and finisher controls")
	for fighter_id in preview.IDS:
		assert(preview.roster_finish_buttons.has(fighter_id))
		assert(preview.roster_finish_buttons[fighter_id].text.contains("FINISH"))
	for speed in [0.25, 0.5, 1.0]:
		lab.set_finisher_speed(speed)
		assert(preview.speed == speed)
	preview.set_paused(true)
	preview.step_frame()
	assert(preview.paused)
	lab.seek_finisher(0.5)
	assert(not preview.director.active)
	preview.set_mobile(true)
	preview.set_reduced_motion(true)
	assert(preview.director.effect_density == "mobile" and preview.director.reduced_motion)
	assert(preview.has_node("LabUI/Controls/Settings/SafeFrame") and preview.has_node("LabUI/Controls/Settings/Bounds"))
	assert(preview.event_label.text.contains("EVENT"))
	preview.start_live_test("bennet")
	assert(preview.live_mode and preview.attacker.health > 0 and preview.defender.health == 15)
	assert(preview.attacker.is_physics_processing(), "live test attacker must use production combat physics")
	assert(preview.defender.is_physics_processing(), "live test rival must use production combat physics")
	assert(preview.trigger_live_finisher(), "eligible live test must launch the real finisher against the rival")
	assert(preview.director.active)
	preview.director.cancel()
	assert(preview.preview_celebration("bennet"), "winner celebration preview did not launch")
	assert(preview.director.active and preview.status.text.contains("CELEBRATION"))
	preview._process(1.0)
	assert(is_equal_approx(preview.director.timeline.elapsed(), 0.4), "Fight Lab celebration preview must use the match's readable 40% speed")
	preview.director.cancel()
	# Exercise the real director with a minimal authored test catalog; production
	# entries remain subject to the implemented guard above.
	var definition: Dictionary = preview.catalog.definition_for("bennet")
	definition.implemented = true
	definition.duration = 1.0
	definition.events = [{"at": 0.0, "type": "portrait_lightbox"}, {"at": 0.25, "type": "hit", "id": "lab-final", "damage": 999, "final": true}, {"at": 0.5, "type": "celebration_start"}]
	preview.catalog._definitions.bennet = definition
	var celebration_id: String = definition.celebration_id
	preview.catalog._celebrations[celebration_id] = {"implemented": true, "duration": 2.0, "events": [{"at": 1.8, "type": "result_marker"}]}
	lab.preview_finisher("bennet", "pause-resume")
	assert(preview.director.active and preview.paused)
	preview._process(1.0)
	assert(preview.elapsed == 0 and preview.defender.health == 15)
	preview.step_frame()
	assert(is_equal_approx(preview.elapsed, 1.0 / 60.0))
	lab.seek_finisher(0.3)
	assert(preview.defender.health == 0 and preview.director.consumed_hit_ids().size() == 1)
	var key: String = preview.director.current_event_key()
	lab.seek_finisher(0.3)
	assert(preview.director.current_event_key() == key and preview.director.consumed_hit_ids().size() == 1)
	lab.seek_finisher(0.1)
	assert(preview.defender.health == 15 and preview.director.consumed_hit_ids().is_empty())
	lab.preview_finisher("bennet", "miss")
	preview.set_paused(false)
	preview._process(0.3)
	assert(not preview.director.active and preview.defender.health == 15)
	assert(not preview.attacker.cinematic_locked and preview.attacker.meter == 0)
	assert(preview.director.diagnostic == "Opening missed")
	preview.catalog.errors.append("Missing test asset")
	lab.preview_finisher("bennet", "hit")
	assert(not preview.director.active and preview.status.text.contains("Missing test asset"))
	assert(lab.get_node("DebugUI/PoseControls").get_child_count() == 11)
	preview.close()
	assert(lab.get_node("DebugUI").visible)
	lab.free()
	print("PASS: Finisher Lab shared catalog, controls, planned guard and original Sprite Lab")
	quit(0)

