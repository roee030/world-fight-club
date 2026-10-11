extends RefCounted

## Shared animation library for every fighter on the humanoid skeleton
## (Quaternius UAL1 + UAL2, CC0, 65-bone; same paths "Armature/Skeleton3D:bone"
## as the Universal Base Characters and future retargeted avatars).
## Built once and cached. Also bakes the "impact time" of each strike clip
## (when the striking hand reaches furthest forward) so the presentation can
## time-warp the clip and show the impact pose exactly on the first active frame.

const SOURCES := ["res://assets/animations/quaternius/UAL1_Standard.glb", "res://assets/animations/quaternius/UAL2_Standard.glb"]
const LOOPING := ["Idle", "Walk", "Crouch_Idle", "Crouch_Fwd", "Jump", "Jog_Fwd", "Sprint", "Idle_Shield", "NinjaJump_Idle", "Idle_FoldArms", "Dance", "Yes"]
const STRIKES := {"Punch_Jab": ["hand_l", "hand_r"], "Punch_Cross": ["hand_l", "hand_r"], "Melee_Hook": ["hand_l", "hand_r"]}

static var _library: AnimationLibrary
static var _impact: Dictionary = {}


static func library() -> AnimationLibrary:
	if _library == null:
		_library = AnimationLibrary.new()
		for path in SOURCES:
			var scene: Node = (load(path) as PackedScene).instantiate()
			var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
			for clip in player.get_animation_list():
				if _library.has_animation(clip):
					continue
				var anim := player.get_animation(clip).duplicate(true) as Animation
				anim.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
				_library.add_animation(clip, anim)
			scene.free()
	return _library


## Seconds into `clip` where the strike is fully extended.
static func impact_time(clip: String, model_path: String) -> float:
	var key := clip
	if _impact.has(key):
		return float(_impact[key])
	var lib := library()
	if not lib.has_animation(clip):
		return 0.0
	var anim := lib.get_animation(clip)
	var best_t := anim.length * 0.4
	if STRIKES.has(clip):
		var model: Node3D = (load(model_path) as PackedScene).instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(model)
		var player := AnimationPlayer.new()
		model.add_child(player)
		player.root_node = NodePath("..")
		player.add_animation_library("", lib)
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var best_reach := -INF
		for k in range(41):
			var t := anim.length * k / 40.0
			player.play(clip)
			player.seek(t, true)
			for bone_name in STRIKES[clip]:
				var reach := skeleton.get_bone_global_pose(skeleton.find_bone(bone_name)).origin.z
				if reach > best_reach:
					best_reach = reach
					best_t = t
		model.free()
	_impact[key] = best_t
	return best_t
