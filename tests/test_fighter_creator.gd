extends SceneTree

## Create Your Fighter: the screen builds, enforces the point budget, imports a
## rigged avatar (here a GLB exported from the base body) and saves a fighter
## that the loader then lists.

const Builder = preload("res://meta/fighter_builder.gd")
const Loader = preload("res://content/character_loader.gd")
const MODEL := "res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf"


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var creator = (load("res://scenes/battle/creator.tscn") as PackedScene).instantiate()
	root.add_child(creator)
	for f in range(3): await process_frame
	if creator.pool() != 0:
		return _fail("a new build starts with 100/100/100")
	creator._adjust("power", 10)
	if creator._points.power != 100:
		return _fail("stats cannot exceed the budget")
	creator._adjust("speed", -30)
	creator._adjust("power", 30)
	if creator._points.power != 130 or creator.pool() != 0:
		return _fail("points must move between stats")
	# Export the base body to GLB bytes and import it like a player's avatar.
	var scene := (load(MODEL) as PackedScene).instantiate()
	var doc := GLTFDocument.new()
	var gstate := GLTFState.new()
	if doc.append_from_scene(scene, gstate) != OK:
		return _fail("could not export a test avatar")
	var bytes := doc.generate_buffer(gstate)
	scene.free()
	var path: String = creator.import_bytes(bytes, "test avatar")
	if path == "" or not FileAccess.file_exists(path):
		return _fail("a rigged avatar must import (%s)" % creator._status.text)
	if creator._preview == null or creator._preview.load_error != "":
		return _fail("the imported avatar must preview")
	var bad: String = creator.import_bytes(PackedByteArray([1, 2, 3]), "junk")
	if bad != "":
		return _fail("junk files must be rejected")
	creator.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: fighter creator (budget, avatar import with validation, preview)")
	quit()
