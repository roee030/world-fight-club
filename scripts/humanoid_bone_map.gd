class_name HumanoidBoneMap
extends RefCounted

const REQUIRED := {
	"root": "root", "pelvis": "pelvis", "chest": "spine_03", "head": "Head",
	"upper_arm_l": "upperarm_l", "lower_arm_l": "lowerarm_l", "hand_l": "hand_l",
	"upper_arm_r": "upperarm_r", "lower_arm_r": "lowerarm_r", "hand_r": "hand_r",
	"thigh_l": "thigh_l", "calf_l": "calf_l", "foot_l": "foot_l",
	"thigh_r": "thigh_r", "calf_r": "calf_r", "foot_r": "foot_r",
}

static func resolve(skeleton: Skeleton3D) -> Dictionary:
	var bones := {}
	var missing: Array[String] = []
	for semantic in REQUIRED:
		var bone_name: String = REQUIRED[semantic]
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			missing.append(bone_name)
		else:
			bones[semantic] = {"name": bone_name, "index": index}
	return {"bones": bones, "missing": missing, "valid": missing.is_empty()}
