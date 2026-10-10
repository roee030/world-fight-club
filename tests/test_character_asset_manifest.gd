extends SceneTree

const MANIFEST_PATH := "res://assets/characters/rigged/asset-manifest.json"

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("Rigged character asset manifest is missing")
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var manifest = JSON.parse_string(file.get_as_text())
	if not manifest is Dictionary:
		_fail("Rigged character asset manifest is not valid JSON")
		return
	for family in ["universal_base_characters"]:
		if not manifest.get("families", {}).has(family):
			_fail("Manifest is missing asset family: %s" % family)
			return
		var entry: Dictionary = manifest.families[family]
		if entry.get("license", "") != "CC0-1.0":
			_fail("Asset family %s is missing its CC0-1.0 license" % family)
			return
		if not FileAccess.file_exists(str(entry.get("license_path", ""))):
			_fail("Asset family %s license file does not exist" % family)
			return
	var fighters: Dictionary = manifest.get("fighters", {})
	for fighter_id in ["bennet", "avigdor", "bibi", "yair_golan"]:
		if not fighters.has(fighter_id):
			_fail("Manifest is missing fighter source: %s" % fighter_id)
			return
		var fighter: Dictionary = fighters[fighter_id]
		if not ResourceLoader.exists(str(fighter.get("scene", ""))):
			_fail("Fighter %s source scene does not exist" % fighter_id)
			return
		if str(fighter.get("skeleton_path", "")).is_empty():
			_fail("Fighter %s has no skeleton path" % fighter_id)
			return
		if not fighter.get("mesh_paths", []) is Array or fighter.mesh_paths.is_empty():
			_fail("Fighter %s has no skinned mesh paths" % fighter_id)
			return
	quit(0)
