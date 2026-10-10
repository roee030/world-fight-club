extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/character_debug.tscn") as PackedScene
	var lab = scene.instantiate()
	get_root().add_child(lab)
	await process_frame
	var controls := lab.get_node_or_null("DebugUI/PoseControls") as HBoxContainer
	if controls == null or controls.get_child_count() < 11:
		return _fail("Sprite Lab does not expose all combat pose controls")
	for state in ["jab", "cross", "kick", "block", "hit", "knockdown", "getup", "jump_air"]:
		lab._set_state_by_name(state)
		if lab.STATES[lab.state_index] != state:
			return _fail("Sprite Lab cannot select pose: %s" % state)
	lab.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
