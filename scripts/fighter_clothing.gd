class_name FighterClothing
extends RefCounted

const SUIT_BONES := [
	"pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r",
	"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r",
	"thigh_l", "thigh_r", "calf_l", "calf_r"
]
const SHOE_BONES := ["foot_l", "foot_r", "ball_l", "ball_r"]

static func attach(skeleton: Skeleton3D, body: MeshInstance3D, definition: Dictionary) -> Array[MeshInstance3D]:
	var pieces: Array[MeshInstance3D] = []
	var suit := _make_piece(skeleton, body, SUIT_BONES, "ContinuousOutfit", definition.palette.primary, 1.018)
	suit.set_meta("outfit", definition.outfit)
	pieces.append(suit)
	pieces.append(_make_piece(skeleton, body, SHOE_BONES, "IntegratedShoes", definition.palette.primary.darkened(0.48), 1.025))
	return pieces

static func _make_piece(skeleton: Skeleton3D, body: MeshInstance3D, allowed_names: Array, part_name: String, color: Color, expand: float) -> MeshInstance3D:
	var allowed := {}
	for bone_name in allowed_names:
		allowed[skeleton.find_bone(bone_name)] = true
	var output_mesh := ArrayMesh.new()
	for surface in body.mesh.get_surface_count():
		var source: Array = body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		var bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
		var selected: Array[int] = []
		for triangle in range(0, indices.size(), 3):
			var keep := true
			for corner in 3:
				var vertex_index := indices[triangle + corner]
				var dominant_slot := 0
				for influence in range(1, 4):
					if weights[vertex_index * 4 + influence] > weights[vertex_index * 4 + dominant_slot]:
						dominant_slot = influence
				if not allowed.has(bones[vertex_index * 4 + dominant_slot]):
					keep = false
					break
			if keep:
				selected.append(indices[triangle])
				selected.append(indices[triangle + 1])
				selected.append(indices[triangle + 2])
		var arrays := _copy_vertices(source, selected, expand)
		if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty(): continue
		output_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = output_mesh
	node.skin = body.skin
	node.skeleton = NodePath("..")
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	material.metallic = 0.04
	node.material_override = material
	skeleton.add_child(node)
	return node

static func _copy_vertices(source: Array, selected: Array[int], expand: float) -> Array:
	var output: Array = []
	output.resize(Mesh.ARRAY_MAX)
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_tangents := PackedFloat32Array()
	var out_colors := PackedColorArray()
	var out_uv := PackedVector2Array()
	var out_uv2 := PackedVector2Array()
	var out_bones := PackedInt32Array()
	var out_weights := PackedFloat32Array()
	var src_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	for index in selected:
		var vertex := src_vertices[index]
		vertex.x *= expand
		vertex.z *= expand
		out_vertices.append(vertex)
		if source[Mesh.ARRAY_NORMAL] != null: out_normals.append(source[Mesh.ARRAY_NORMAL][index])
		if source[Mesh.ARRAY_COLOR] != null: out_colors.append(source[Mesh.ARRAY_COLOR][index])
		if source[Mesh.ARRAY_TEX_UV] != null: out_uv.append(source[Mesh.ARRAY_TEX_UV][index])
		if source[Mesh.ARRAY_TEX_UV2] != null: out_uv2.append(source[Mesh.ARRAY_TEX_UV2][index])
		if source[Mesh.ARRAY_TANGENT] != null:
			for slot in 4: out_tangents.append(source[Mesh.ARRAY_TANGENT][index * 4 + slot])
		for slot in 4:
			out_bones.append(source[Mesh.ARRAY_BONES][index * 4 + slot])
			out_weights.append(source[Mesh.ARRAY_WEIGHTS][index * 4 + slot])
	output[Mesh.ARRAY_VERTEX] = out_vertices
	if not out_normals.is_empty(): output[Mesh.ARRAY_NORMAL] = out_normals
	if not out_tangents.is_empty(): output[Mesh.ARRAY_TANGENT] = out_tangents
	if not out_colors.is_empty(): output[Mesh.ARRAY_COLOR] = out_colors
	if not out_uv.is_empty(): output[Mesh.ARRAY_TEX_UV] = out_uv
	if not out_uv2.is_empty(): output[Mesh.ARRAY_TEX_UV2] = out_uv2
	output[Mesh.ARRAY_BONES] = out_bones
	output[Mesh.ARRAY_WEIGHTS] = out_weights
	return output
