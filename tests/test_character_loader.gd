extends SceneTree

## Character pipeline: a canonical model is animated directly; a model whose
## bones use Mixamo names (as Avaturn / Mixamo avatars do) is retargeted from
## the hidden canonical puppet, and its hands and feet follow the puppet's.
## A model missing humanoid bones is rejected with a clear error.

const Loader = preload("res://content/character_loader.gd")
const Bones = preload("res://content/bone_conventions.gd")
const AnimLib = preload("res://present/anim_library.gd")
const MODEL := "res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf"

var _samples := {}


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _run() -> void:
	var direct := Loader.build(MODEL)
	if direct.error != "" or direct.retargeted:
		return _fail("the canonical model must load without retargeting")
	direct.root.free()
	# Fake a Mixamo-named avatar: same mesh and rig, bones renamed.
	var avatar := (load(MODEL) as PackedScene).instantiate() as Node3D
	var askel := avatar.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for canonical in Bones.MAP:
		var i := askel.find_bone(canonical)
		if i >= 0:
			askel.set_bone_name(i, "mixamorig:" + str(Bones.MAP[canonical][0]))
	if Bones.is_canonical(askel):
		return _fail("renaming must make the skeleton non-canonical")
	var built := Loader.build_from_scene(avatar)
	if built.error != "" or not built.retargeted:
		return _fail("a Mixamo-named avatar must be retargeted (%s)" % built.error)
	root.add_child(built.root)
	# Drive the puppet with a real clip and compare effector positions.
	var puppet: Node3D = built.animated_root
	var player := AnimationPlayer.new()
	puppet.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", AnimLib.library())
	player.play("Punch_Cross")
	player.seek(0.3, true)
	player.pause()
	var target := built.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var source := built.skeleton as Skeleton3D
	target.skeleton_updated.connect(func():
		for bone in ["hand_r", "hand_l", "foot_r", "foot_l", "Head"]:
			var t_idx := target.find_bone("mixamorig:" + str(Bones.MAP[bone][0]))
			_samples[bone] = [target.get_bone_global_pose(t_idx).origin, source.get_bone_global_pose(source.find_bone(bone)).origin]
	)
	for f in range(6):
		await process_frame
	if _samples.is_empty():
		return _fail("the retargeted skeleton never updated")
	for bone in _samples:
		var pair: Array = _samples[bone]
		var error_m: float = (pair[0] as Vector3).distance_to(pair[1])
		if error_m > 0.03:
			return _fail("%s is %.3f m away from the puppet after retargeting" % [bone, error_m])
	built.root.free()
	# A model without legs must be rejected.
	var broken := (load(MODEL) as PackedScene).instantiate() as Node3D
	var bskel := broken.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for i in range(bskel.get_bone_count()):
		bskel.set_bone_name(i, "bone_%d" % i)
	var rejected := Loader.build_from_scene(broken)
	if rejected.error == "":
		return _fail("a skeleton without humanoid bones must be rejected")
	print("PASS: character loader (direct, Mixamo-named retarget within 3 cm, rejection)")
	quit()
