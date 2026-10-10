extends SceneTree

func _init() -> void:
	var rules = load("res://scripts/finishers/finisher_rules.gd")
	var state = load("res://scripts/finishers/match_state.gd")
	if rules == null or state == null:
		quit(1)
		return
	var context := {"implemented": true, "match_point": false, "health_ratio": 1.0, "meter": 100.0, "state": state.Value.FIGHTING, "grounded": false, "actionable": true, "attacker_actionable": true, "distance": 99.0, "facing_correct": false, "paused": false}
	var definition := {"implemented": true, "trigger_health_ratio": 0.15, "meter_cost": 100.0, "activation_range": 1.75}
	assert(rules.is_eligible(context, definition), "full meter must activate regardless of round, health, distance, grounding or facing")
	for pair in [["meter", 99.9], ["paused", true], ["state", state.Value.RESULT], ["attacker_actionable", false]]:
		var invalid := context.duplicate()
		invalid[pair[0]] = pair[1]
		assert(not rules.is_eligible(invalid, definition))
	definition.implemented = false
	assert(not rules.is_eligible(context, definition))
	assert(rules.match_point_for(0, 1, 0))
	assert(rules.match_point_for(1, 0, 1))
	assert(not rules.match_point_for(0, 0, 1))
	assert(state.can_transition(state.Value.FIGHTING, state.Value.FINISHER_PROMPT))
	assert(not state.can_transition(state.Value.ROUND_INTRO, state.Value.CELEBRATION))
	print("PASS: one-press full-meter finisher activation boundaries")
	quit(0)
