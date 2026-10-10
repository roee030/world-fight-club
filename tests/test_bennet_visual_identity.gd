extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var visual: Dictionary = (load("res://scripts/rigged_fighter_visual.gd").new()).build("bennet")
	if not str(visual.get("error", "")).is_empty():
		_fail(visual.error)
		return
	for required in ["KravMaga_Shirt", "KravMaga_Pants", "KravMaga_Gloves", "KravMaga_Boots"]:
		if visual.root.find_child(required, true, false) == null:
			_fail("Bennet is missing 3D part: %s" % required)
			return
	if visual.root.find_child("Tefillin_Left", true, false) != null:
		_fail("Tefillin must not be present")
		return
	for forbidden in ["Eyes", "Eyebrows", "FrontTooth_L", "FrontTooth_R"]:
		if visual.root.find_child(forbidden, true, false) != null:
			_fail("Unstable facial mesh still exists: %s" % forbidden)
			return
	if not visual.root.find_children("*", "Sprite3D", true, false).is_empty():
		_fail("Bennet contains a billboard")
		return
	var palette: Dictionary = visual.definition.palette
	if palette.primary != Color("183b59") or palette.secondary != Color("25cbd3"):
		_fail("Bennet navy/cyan palette changed")
		return
	if visual.definition.outfit != "krav_maga_combat_uniform":
		_fail("Bennet is not using the Krav Maga uniform")
		return
	var height := float(visual.root.get_meta("visual_height_m", 0.0))
	if height < 1.7 or height > 2.1:
		_fail("Bennet height is outside combat bounds: %s" % height)
		return
	visual.root.free()
	quit(0)
