extends SkeletonModifier3D

## Runtime retarget: copies the pose of a hidden canonical "puppet" skeleton
## (driven by the shared animation library) onto an avatar skeleton with a
## different naming convention and rest pose. Works in global rotation deltas
## from each skeleton's rest pose, so T-pose and A-pose rigs both work; the
## hips translation is scaled by the height ratio so feet stay planted.

var source: Skeleton3D
var target_skeleton: Skeleton3D
var mapping: Dictionary = {}     # canonical name -> target bone index
var _pairs: Array = []           # [source_idx, target_idx] in parent-first order
var _height_ratio := 1.0
var _source_rest_global: Array[Basis] = []
var _target_rest_global: Array[Basis] = []


func configure(puppet: Skeleton3D, target_mapping: Dictionary, target: Skeleton3D) -> void:
	source = puppet
	mapping = target_mapping
	target_skeleton = target
	_pairs.clear()
	for canonical in mapping:
		var s := source.find_bone(canonical)
		if s >= 0:
			_pairs.append([s, int(mapping[canonical])])
	# Parent-first order so each target bone's parent is final before it.
	_pairs.sort_custom(func(a, b): return _depth(target, int(a[1])) < _depth(target, int(b[1])))
	_source_rest_global.clear()
	_target_rest_global.clear()
	for pair in _pairs:
		_source_rest_global.append(source.get_bone_global_rest(int(pair[0])).basis.orthonormalized())
		_target_rest_global.append(target.get_bone_global_rest(int(pair[1])).basis.orthonormalized())
	var s_hips := source.find_bone("pelvis")
	if s_hips >= 0 and mapping.has("pelvis"):
		var src_h := source.get_bone_global_rest(s_hips).origin.y
		var dst_h := target.get_bone_global_rest(int(mapping.pelvis)).origin.y
		_height_ratio = dst_h / src_h if src_h > 0.001 else 1.0


static func _depth(skeleton: Skeleton3D, bone: int) -> int:
	var d := 0
	var p := skeleton.get_bone_parent(bone)
	while p >= 0:
		d += 1
		p = skeleton.get_bone_parent(p)
	return d


func _process_modification() -> void:
	var target := target_skeleton
	if target == null or source == null:
		return
	for k in range(_pairs.size()):
		var s := int(_pairs[k][0])
		var t := int(_pairs[k][1])
		# Global rotation change of the source bone relative to its rest pose...
		var src_global := source.get_bone_global_pose(s).basis.orthonormalized()
		var delta := src_global * _source_rest_global[k].inverse()
		# ...applied on top of the target bone's own rest orientation.
		var wanted := delta * _target_rest_global[k]
		var parent := target.get_bone_parent(t)
		var parent_global := target.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var local := (parent_global.inverse() * wanted).orthonormalized()
		target.set_bone_pose_rotation(t, local.get_rotation_quaternion())
		if source.get_bone_name(s) == "pelvis":
			var origin := source.get_bone_pose_position(s) * _height_ratio
			target.set_bone_pose_position(t, origin)
