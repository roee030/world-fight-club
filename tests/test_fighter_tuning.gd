extends SceneTree

## data/fighter_tuning.json keeps the exact numbers that used to be if-chains in
## fighter.gd, and every roster id resolves (unknown ids fall back to defaults).

const FighterTuning = preload("res://scripts/fighter_tuning.gd")
const ROSTER := ["bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid", "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich", "gadi_eisenkot", "trump", "joint_list"]
const HP := {"avigdor": 112.0, "bibi": 104.0, "yair_golan": 102.0, "mansour_abbas": 116.0, "benny_gantz": 108.0, "gadi_eisenkot": 114.0, "itamar_ben_gvir": 98.0, "yair_lapid": 96.0}
const SPEED := {"avigdor": 2.9, "bibi": 3.0, "yair_golan": 3.35, "benny_gantz": 2.95, "mansour_abbas": 2.8, "gadi_eisenkot": 2.8, "yair_lapid": 3.45, "itamar_ben_gvir": 3.45, "bezalel_smotrich": 3.45}
const DAMAGE := {"avigdor": 1.16, "yair_golan": 0.96, "mansour_abbas": 1.10, "gadi_eisenkot": 1.10, "yair_lapid": 0.93, "bezalel_smotrich": 0.93}


func _init() -> void:
	_run()


func _run() -> void:
	for id in ROSTER:
		var hp := FighterTuning.value(id, "hp")
		if not is_equal_approx(hp, float(HP.get(id, 100.0))):
			return _fail("hp of %s is %s" % [id, hp])
		var speed := FighterTuning.value(id, "walk_speed")
		if not is_equal_approx(speed, float(SPEED.get(id, 3.25))):
			return _fail("walk_speed of %s is %s" % [id, speed])
		var damage := FighterTuning.value(id, "damage_mult")
		if not is_equal_approx(damage, float(DAMAGE.get(id, 1.0))):
			return _fail("damage_mult of %s is %s" % [id, damage])
		var light := FighterTuning.value(id, "light_mult")
		if not is_equal_approx(light, 0.93 if id == "bibi" else 1.0):
			return _fail("light_mult of %s is %s" % [id, light])
	if not is_equal_approx(FighterTuning.value("future_fighter", "hp"), 100.0):
		return _fail("unknown fighters must use defaults")
	print("PASS: fighter tuning data matches the previous hard-coded values")
	quit()


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)
