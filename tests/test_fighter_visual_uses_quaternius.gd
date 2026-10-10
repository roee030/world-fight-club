extends SceneTree

# Retained filename so existing test runners keep discovering the migrated test.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var visual := FighterVisual.build("bennet")
	get_root().add_child(visual.root)
	await process_frame
	var failed := false
	if visual.get("pipeline", "") != "2d_sprite":
		push_error("Fighter visual did not migrate to the sprite pipeline")
		failed = true
	for state in ["walk_forward", "jab", "cross", "hook", "hit", "knockdown", "getup"]:
		visual.motion.play_state(state, true, 0.30)
		if visual.sprite.animation != state:
			push_error("Combat state %s did not reach the sprite animator" % state)
			failed = true
	if visual.root.find_child("Skeleton3D", true, false) != null:
		push_error("Sprite fighter unexpectedly contains the retired custom skeleton")
		failed = true
	visual.root.free()
	quit(1 if failed else 0)
