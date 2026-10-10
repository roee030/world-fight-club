extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	if main.PLAYABLE_IDS.size() != 13: return _fail("roster does not contain all 13 fighters")
	for id in main.PLAYABLE_IDS:
		main._select_fighter(id)
		if main.select_portrait.texture == null: return _fail("missing selection art for %s" % id)
	main._open_select("quick")
	if not main.select_root.visible or main.menu_root.visible: return _fail("selection screen state is invalid")
	main.free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
