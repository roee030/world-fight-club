extends SceneTree

## Bibi has complete existing fighter art, but no approved rigged GLB. He must
## remain selectable and fight in the deterministic 3D scene through the
## sprite bridge rather than silently falling back to a generic mannequin.

const Battle = preload("res://present/battle_view.gd")
const Loader = preload("res://content/character_loader.gd")
const L = preload("res://sim/layout.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var defs: Array = Loader.fighter_definitions()
	var bibi: Dictionary = {}
	for def in defs:
		if str(def.get("id", "")) == "bibi":
			bibi = def
	if bibi.is_empty():
		return _fail("Bibi is missing from new-engine fighter definitions")
	if str(bibi.get("sprite_frames", "")).is_empty():
		return _fail("Bibi must declare an approved sprite bridge")
	Battle.pending_selection = {"p1": bibi, "p2": bibi, "stage": "res://assets/stages/kaplan-junction-arena.jpg"}
	var battle = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	battle.use_private_fighter = false
	battle.cpu_controls_player = true
	root.add_child(battle)
	for frame in range(240): await physics_frame
	if not battle.views[0].has_method("setup_frames") or not battle.views[1].has_method("setup_frames"):
		return _fail("Bibi was not rendered through the sprite bridge")
	if battle.state[L.base(0) + L.F_HP] == 10400 and battle.state[L.base(1) + L.F_HP] == 10400:
		return _fail("Bibi bridge battle produced no combat")
	battle.free()
	print("PASS: Bibi fights in the new-engine sprite bridge")
	quit()
