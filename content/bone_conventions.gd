extends RefCounted

## Maps the game's canonical skeleton (Quaternius UAL / Universal Base
## Characters, 65 bones) to other humanoid naming conventions, so any rigged
## avatar (Mixamo, Avaturn, MetaPerson, Godot SkeletonProfileHumanoid) can be
## driven by the shared animation library through runtime retargeting.

const PREFIXES := ["mixamorig:", "mixamorig_", "mixamorig1:", "Armature|", "CC_Base_", "DEF-"]

## canonical (UAL) -> list of accepted names in other conventions.
const MAP := {
	"pelvis": ["Hips", "hips", "Pelvis"],
	"spine_01": ["Spine", "spine"],
	"spine_02": ["Spine1", "Chest", "spine1"],
	"spine_03": ["Spine2", "UpperChest", "spine2"],
	"neck_01": ["Neck", "neck"],
	"Head": ["Head", "head"],
	"clavicle_l": ["LeftShoulder"],
	"upperarm_l": ["LeftArm", "LeftUpperArm"],
	"lowerarm_l": ["LeftForeArm", "LeftLowerArm"],
	"hand_l": ["LeftHand"],
	"clavicle_r": ["RightShoulder"],
	"upperarm_r": ["RightArm", "RightUpperArm"],
	"lowerarm_r": ["RightForeArm", "RightLowerArm"],
	"hand_r": ["RightHand"],
	"thigh_l": ["LeftUpLeg", "LeftUpperLeg"],
	"calf_l": ["LeftLeg", "LeftLowerLeg"],
	"foot_l": ["LeftFoot"],
	"ball_l": ["LeftToeBase", "LeftToes"],
	"thigh_r": ["RightUpLeg", "RightUpperLeg"],
	"calf_r": ["RightLeg", "RightLowerLeg"],
	"foot_r": ["RightFoot"],
	"ball_r": ["RightToeBase", "RightToes"],
	"thumb_01_l": ["LeftHandThumb1", "LeftThumbMetacarpal"], "thumb_02_l": ["LeftHandThumb2", "LeftThumbProximal"], "thumb_03_l": ["LeftHandThumb3", "LeftThumbDistal"],
	"index_01_l": ["LeftHandIndex1", "LeftIndexProximal"], "index_02_l": ["LeftHandIndex2", "LeftIndexIntermediate"], "index_03_l": ["LeftHandIndex3", "LeftIndexDistal"],
	"middle_01_l": ["LeftHandMiddle1", "LeftMiddleProximal"], "middle_02_l": ["LeftHandMiddle2", "LeftMiddleIntermediate"], "middle_03_l": ["LeftHandMiddle3", "LeftMiddleDistal"],
	"ring_01_l": ["LeftHandRing1", "LeftRingProximal"], "ring_02_l": ["LeftHandRing2", "LeftRingIntermediate"], "ring_03_l": ["LeftHandRing3", "LeftRingDistal"],
	"pinky_01_l": ["LeftHandPinky1", "LeftLittleProximal"], "pinky_02_l": ["LeftHandPinky2", "LeftLittleIntermediate"], "pinky_03_l": ["LeftHandPinky3", "LeftLittleDistal"],
	"thumb_01_r": ["RightHandThumb1", "RightThumbMetacarpal"], "thumb_02_r": ["RightHandThumb2", "RightThumbProximal"], "thumb_03_r": ["RightHandThumb3", "RightThumbDistal"],
	"index_01_r": ["RightHandIndex1", "RightIndexProximal"], "index_02_r": ["RightHandIndex2", "RightIndexIntermediate"], "index_03_r": ["RightHandIndex3", "RightIndexDistal"],
	"middle_01_r": ["RightHandMiddle1", "RightMiddleProximal"], "middle_02_r": ["RightHandMiddle2", "RightMiddleIntermediate"], "middle_03_r": ["RightHandMiddle3", "RightMiddleDistal"],
	"ring_01_r": ["RightHandRing1", "RightRingProximal"], "ring_02_r": ["RightHandRing2", "RightRingIntermediate"], "ring_03_r": ["RightHandRing3", "RightRingDistal"],
	"pinky_01_r": ["RightHandPinky1", "RightLittleProximal"], "pinky_02_r": ["RightHandPinky2", "RightLittleIntermediate"], "pinky_03_r": ["RightHandPinky3", "RightLittleDistal"],
}
## Bones the fighting animations need; a model missing any of these is rejected.
const REQUIRED := ["pelvis", "spine_01", "Head", "upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r", "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"]


static func clean(bone_name: String) -> String:
	for prefix in PREFIXES:
		if bone_name.begins_with(prefix):
			return bone_name.substr(prefix.length())
	return bone_name


## True when the skeleton already uses the canonical names (no retarget needed).
static func is_canonical(skeleton: Skeleton3D) -> bool:
	for bone in REQUIRED:
		if skeleton.find_bone(bone) < 0:
			return false
	return true


## canonical bone name -> bone index in `skeleton`, for every bone that maps.
static func resolve(skeleton: Skeleton3D) -> Dictionary:
	var by_clean := {}
	for i in range(skeleton.get_bone_count()):
		by_clean[clean(skeleton.get_bone_name(i))] = i
	var out := {}
	for canonical in MAP:
		if by_clean.has(canonical):
			out[canonical] = by_clean[canonical]
			continue
		for alias in MAP[canonical]:
			if by_clean.has(alias):
				out[canonical] = by_clean[alias]
				break
	return out


static func missing(mapping: Dictionary) -> Array:
	var out: Array = []
	for bone in REQUIRED:
		if not mapping.has(bone):
			out.append(bone)
	return out
