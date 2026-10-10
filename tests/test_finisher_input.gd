extends SceneTree

class InputHost extends "res://scripts/main.gd":
	var test_eligible := true
	func _finisher_eligible() -> bool:
		return test_eligible

func _init() -> void:
	var script = load("res://scripts/finishers/special_hold.gd")
	if script == null:
		quit(1)
		return
	var hold = script.new()
	assert(hold.update(0.0, true, false, false) == "special")
	assert(hold.update(0.0, true, false, true) == "finisher")
	assert(hold.update(0.0, false, true, true) == "none")
	assert(not hold.active)
	var host := InputHost.new()
	host.match_state = host.MatchState.Value.FIGHTING
	assert(host._update_special_hold(0.0, true, false) == "finisher")
	assert(host.match_state == host.MatchState.Value.FIGHTING)
	assert(host._update_special_hold(0.0, false, true) == "none")
	host.test_eligible = false
	assert(host._update_special_hold(0.0, true, false) == "special")
	host.free()
	print("PASS: full-meter Special activates the finisher on one press")
	quit(0)
