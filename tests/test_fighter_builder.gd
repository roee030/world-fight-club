extends SceneTree

## Personal fighter builds: a fixed 300-point budget (50..150 each), stats that
## reach the sim (damage %, walk, HP), saving to user:// and being listed with
## the data fighters.

const Builder = preload("res://meta/fighter_builder.gd")
const Loader = preload("res://content/character_loader.gd")
const Sim = preload("res://sim/sim.gd")
const L = preload("res://sim/layout.gd")
const Moveset = preload("res://sim/moveset.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	if Builder.is_valid_split(150, 150, 0) or Builder.is_valid_split(120, 100, 100) or not Builder.is_valid_split(150, 50, 100):
		return _fail("the budget must be exactly 300 with every stat in 50..150")
	var standard: Dictionary = Builder.stats_for(100, 100, 100)
	if standard.power != 100 or standard.hp != 10000:
		return _fail("100/100/100 must be the standard fighter (got %s)" % standard)
	var def: Dictionary = Builder.build_def("Test Hero", 2, Builder.BASE_MODELS[0][1], Color(1, 0.5, 0.5), 150, 50, 100)
	if def.is_empty() or def.moveset != "grappler" or def.id != "custom_test_hero":
		return _fail("build_def must produce a grappler definition")
	# A max-power fighter hits harder than a min-power one with the same jab.
	var ms = Moveset.compile(["res://data/movesets/universal.json"])
	var damages := []
	for power in [110, 90]:
		var s := Sim.new_match(ms, [{"x": -5200, "power": power}, {"x": 5200}], 3)
		for f in range(1, 20): Sim.step(ms, s, PackedInt32Array([L.IN_LP if f == 1 else 0, 0]))
		damages.append(10000 - s[L.base(1) + L.F_HP])
	if damages[0] <= damages[1]:
		return _fail("power must scale damage (%s)" % [damages])
	var dir := "user://test_fighters"
	if Builder.save_def(def, dir) != OK or not FileAccess.file_exists(dir + "/custom_test_hero.json"):
		return _fail("the fighter must save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "/custom_test_hero.json"))
	print("PASS: personal fighter builder (budget, stats in the sim, save)")
	quit()
