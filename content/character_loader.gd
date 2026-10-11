extends RefCounted

## Loads a fighter's model for the 3D battle from data/fighters/<id>.json (or a
## runtime avatar GLB under user://). Canonical-skeleton models are animated
## directly; any other humanoid naming (Mixamo, Avaturn, MetaPerson...) is
## driven through a hidden canonical puppet + pose_retarget.gd.
## Returns {"root": Node3D, "skeleton": Skeleton3D (the animated one),
##          "model": Node3D (visible), "retargeted": bool, "error": String}.

const Bones = preload("res://content/bone_conventions.gd")
const Retarget = preload("res://content/pose_retarget.gd")
const PUPPET := "res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf"
const FIGHTERS_DIR := "res://data/fighters"


static func fighter_definitions() -> Array:
	var out: Array = []
	for dir_path in [FIGHTERS_DIR, "user://fighters"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.ends_with(".json"):
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir_path + "/" + file))
				# A published sprite bridge is permitted while the complete per-character
				# GLB is being produced. It remains a full fighter asset, never a face
				# pasted onto the shared mannequin.
				if parsed is Dictionary and (parsed.has("model") or parsed.has("sprite_frames")):
					out.append(parsed)
	out.sort_custom(func(a, b): return str(a.get("order", a.id)) < str(b.get("order", b.id)))
	return out


static func load_scene(path: String) -> Node3D:
	if path.begins_with("res://"):
		var packed := load(path) as PackedScene
		return packed.instantiate() as Node3D if packed != null else null
	# Runtime GLB (e.g. a selfie avatar downloaded to user://).
	var doc := GLTFDocument.new()
	var gstate := GLTFState.new()
	if doc.append_from_file(path, gstate) != OK:
		return null
	return doc.generate_scene(gstate) as Node3D


static func build(model_path: String) -> Dictionary:
	var model := load_scene(model_path)
	if model == null:
		return {"error": "could not load %s" % model_path}
	return build_from_scene(model)


static func build_from_scene(model: Node3D) -> Dictionary:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		model.free()
		return {"error": "model has no skeleton"}
	var skeleton := skeletons[0] as Skeleton3D
	if Bones.is_canonical(skeleton):
		return {"root": model, "model": model, "skeleton": skeleton, "retargeted": false, "error": ""}
	var mapping := Bones.resolve(skeleton)
	var missing := Bones.missing(mapping)
	if not missing.is_empty():
		model.free()
		return {"error": "missing humanoid bones: %s" % ", ".join(missing)}
	# Hidden canonical puppet carries the animations; the avatar copies its pose.
	var root := Node3D.new()
	root.name = "RetargetedFighter"
	var puppet := (load(PUPPET) as PackedScene).instantiate() as Node3D
	puppet.name = "Puppet"
	root.add_child(puppet)
	for mesh in puppet.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).visible = false
	root.add_child(model)
	var puppet_skeleton := puppet.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var retarget = Retarget.new()
	skeleton.add_child(retarget)
	retarget.configure(puppet_skeleton, mapping, skeleton)
	return {"root": root, "model": model, "skeleton": puppet_skeleton, "animated_root": puppet, "retargeted": true, "error": ""}
