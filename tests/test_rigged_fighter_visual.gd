extends SceneTree

const BUILDER_PATH := "res://scripts/rigged_fighter_visual.gd"

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	if not ResourceLoader.exists(BUILDER_PATH):
		_fail("RiggedFighterVisual builder is missing")
		return
	var builder = load(BUILDER_PATH).new()
	var built: Array[Dictionary] = []
	for fighter_id in ["bennet", "avigdor", "bibi", "yair_golan"]:
		var visual: Dictionary = builder.build(fighter_id)
		if not str(visual.get("error", "")).is_empty():
			_fail("Fighter %s failed to build: %s" % [fighter_id, visual.error])
			return
		if not visual.get("skeleton") is Skeleton3D:
			_fail("Fighter %s has no skeleton" % fighter_id)
			return
		if not visual.get("meshes", []) is Array or visual.meshes.is_empty():
			_fail("Fighter %s has no skinned meshes" % fighter_id)
			return
		if not visual.root.find_children("*", "Sprite3D", true, false).is_empty():
			_fail("Fighter %s contains a forbidden Sprite3D portrait" % fighter_id)
			return
		built.append(visual)
	var first_material: Material = built[0].meshes[0].get_active_material(0)
	var second_material: Material = built[1].meshes[0].get_active_material(0)
	if first_material == null or first_material == second_material:
		_fail("Fighter instances share mutable body materials")
		return
	var invalid: Dictionary = builder.build("missing_fighter")
	if not str(invalid.get("error", "")).contains("missing_fighter"):
		_fail("Missing fighter error does not name the character id")
		return
	for visual in built: visual.root.free()
	quit(0)
