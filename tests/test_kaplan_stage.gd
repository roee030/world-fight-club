extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame

	var kaplan: Dictionary = main._stage_data("kaplan_junction")
	if kaplan.is_empty():
		return _fail("Kaplan Junction is not registered as a playable stage")
	if str(kaplan.get("image", "")) != "res://assets/stages/kaplan-junction-arena.jpg":
		return _fail("Kaplan Junction does not use the supplied arena image")
	if not ResourceLoader.exists(str(kaplan.image)):
		return _fail("Kaplan Junction arena image is missing")

	main._confirm_selection()
	if main.stage_buttons.size() != 6:
		return _fail("arena select must show all six playable stages")
	main._select_stage("kaplan_junction")
	main._setup_bout("bennet", "avigdor", 1, "KAPLAN QA")
	await process_frame
	var backdrop := main._fight_camera.get_node_or_null("FullFrameStageBackdrop") as MeshInstance3D
	if backdrop == null or backdrop.material_override == null:
		return _fail("Kaplan Junction did not build a playable fight backdrop")
	var texture := (backdrop.material_override as StandardMaterial3D).albedo_texture
	if texture == null or texture.resource_path != str(kaplan.image):
		return _fail("the fight backdrop did not load the selected Kaplan image")

	main.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
